package com.example.atahad;

import com.example.atahad.AI.OpenRouterClient;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import com.example.atahad.Service.ProofTime;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import tools.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.http.*;
import java.time.*;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

// The whole application runs with an isolated in-memory database, never the team's database.
@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT, properties={
    "spring.config.import=", "spring.datasource.url=jdbc:h2:mem:proof_http;MODE=MySQL;NON_KEYWORDS=USER,GROUP,VALUE,MONTH;DB_CLOSE_DELAY=-1",
    "spring.datasource.driver-class-name=org.h2.Driver", "spring.datasource.username=sa", "spring.datasource.password=",
    "spring.jpa.show-sql=false", "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
    "spring.jpa.hibernate.ddl-auto=create-drop", "spring.jpa.properties.jakarta.persistence.validation.mode=none",
    "automation.scheduler-enabled=false", "openrouter.api-key=", "ai.api-key=",
    "google.calendar.redirect-uri=http://localhost/test-calendar-callback"
})
class ProofHttpIntegrationTest {
    @Value("${local.server.port}") int port;
    @Autowired UserRepository users;
    @Autowired MemberRepository members;
    @Autowired HabitRepository habits;
    @Autowired CommitmentWeekRepository weeks;
    @Autowired ProofRepository proofs;
    @Autowired ProofCaptureRepository captures;
    @Autowired PasswordEncoder encoder;
    @Autowired ProofTime time;
    @Autowired PlatformTransactionManager manager;
    final HttpClient client=HttpClient.newHttpClient();
    final ObjectMapper json=new ObjectMapper();
    String auth;

    HttpResponse<String> call(String method,String path,String body,boolean login) throws Exception {
        var request=HttpRequest.newBuilder(URI.create("http://localhost:"+port+path)).header("Content-Type","application/json");
        if(login) request.header("Authorization",auth);
        return client.send(request.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(body)).build(),HttpResponse.BodyHandlers.ofString());
    }
    @Test void realLoginTimerOwnershipAndSingleCompletion() throws Exception {
        var tx=new TransactionTemplate(manager);
        LocalDateTime now=LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        ReflectionTestUtils.setField(time,"clock",Clock.fixed(now.atZone(ZoneId.of("Asia/Riyadh")).toInstant(),ZoneId.of("Asia/Riyadh")));
        String email=UUID.randomUUID()+"@example.test";
        Integer[] ids=tx.execute(status->{
            User user=new User();user.setName("Tester");user.setEmail(email);user.setPhone("+966501234567");user.setRole("MEMBER");user.setPassword(encoder.encode("test-password"));users.save(user);
            Member member=new Member();member.setUser(user);member.setLevel("BEGINNER");members.save(member);
            Habit habit=new Habit();habit.setTitle("Study");habit.setMember(member);habit.setStatus("ACTIVE");habit.setProofMethod("TIMER");habit.setTimesPerWeek(3);habit.setBaseAmount(new BigDecimal("5.00"));habits.save(habit);
            CommitmentWeek week=new CommitmentWeek();week.setCommitment(habit);week.setWeekNumber(1);week.setRequired(3);week.setWeekStart(now.minusDays(1));week.setWeekEnd(now.plusDays(1));weeks.save(week);
            return new Integer[]{member.getId(),week.getId()};
        });
        auth="Basic "+Base64.getEncoder().encodeToString((email+":test-password").getBytes(java.nio.charset.StandardCharsets.UTF_8));
        assertEquals(401,call("POST","/api/v1/proof-attempt/start/"+ids[1],"{}",false).statusCode());
        assertEquals(403,call("POST","/api/v1/quiz/create/999999/"+ids[1],"{}",true).statusCode());
        var start=call("POST","/api/v1/proof-attempt/start/"+ids[1],"{\"targetMinutes\":1}",true);
        assertEquals(200,start.statusCode(),start.body());
        int proofId=json.readTree(start.body()).get("id").asInt();
        var state=call("GET","/api/v1/proof-attempt/"+proofId,null,true);
        assertEquals(200,state.statusCode(),state.body());
        int timerId=json.readTree(state.body()).get("timer").get("id").asInt();
        ReflectionTestUtils.setField(time,"clock",Clock.fixed(now.plusMinutes(2).atZone(ZoneId.of("Asia/Riyadh")).toInstant(),ZoneId.of("Asia/Riyadh")));
        var tick=call("POST","/api/v1/proof-attempt/timer/"+timerId+"/state","{}",true);
        assertEquals(200,tick.statusCode(),tick.body());
        assertEquals("ACCEPTED",proofs.findProofById(proofId).getResult());
        assertEquals(1,weeks.findCommitmentWeekById(ids[1]).getCompleted());
        assertEquals(10,members.findMemberById(ids[0]).getPoints());
        var workspace=call("GET","/api/v1/proof-workspace/my",null,true);
        assertEquals(200,workspace.statusCode(),workspace.body());
        assertEquals(1,json.readTree(workspace.body()).get("proofs").size());
        assertEquals("ACCEPTED",json.readTree(workspace.body()).get("proofs").get(0).get("status").asText());
        assertEquals(200,call("POST","/api/v1/proof-attempt/timer/"+timerId+"/state","{}",true).statusCode());
        assertEquals(1,weeks.findCommitmentWeekById(ids[1]).getCompleted());
        assertEquals(10,members.findMemberById(ids[0]).getPoints());
    }
    @Test void workspaceAndAttachmentsUseTheLoggedInOwner() throws Exception {
        String email=UUID.randomUUID()+"@example.test";
        Integer memberId=new TransactionTemplate(manager).execute(status->{
            User user=new User();user.setName("Attachment tester");user.setEmail(email);user.setPhone("+966509999998");user.setRole("MEMBER");user.setPassword(encoder.encode("test-password"));users.save(user);
            Member member=new Member();member.setUser(user);member.setLevel("BEGINNER");members.save(member);
            return member.getId();
        });
        auth="Basic "+Base64.getEncoder().encodeToString((email+":test-password").getBytes(java.nio.charset.StandardCharsets.UTF_8));
        String image="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==";
        var ticket=call("POST","/api/v1/excuse/attachment",null,true);
        assertEquals(200,ticket.statusCode(),ticket.body());
        var payload=json.readTree(ticket.body());
        int captureId=payload.get("captureId").asInt();
        String body=json.writeValueAsString(Map.of("token",payload.get("token").asText(),"imageData",image));
        var uploaded=call("POST","/api/v1/excuse/attachment/"+captureId,body,true);
        assertEquals(200,uploaded.statusCode(),uploaded.body());
        assertEquals(memberId,captures.findById(captureId).orElseThrow().getMemberId());
        var own=call("GET","/api/v1/proof-workspace/attachment/"+captureId,null,true);
        assertEquals(200,own.statusCode(),own.body());
        assertEquals(image,json.readTree(own.body()).get("imageData").asText());
        ProofCapture foreign=new ProofCapture();foreign.setMemberId(-1);foreign.setKind("PHOTO");foreign.setImageData(image);captures.save(foreign);
        assertEquals(403,call("GET","/api/v1/proof-workspace/attachment/"+foreign.getId(),null,true).statusCode());
        assertEquals(401,call("GET","/api/v1/proof-workspace/attachment/"+captureId,null,false).statusCode());
        var workspace=call("GET","/api/v1/proof-workspace/my",null,true);
        assertEquals(200,workspace.statusCode(),workspace.body());
        assertEquals(0,json.readTree(workspace.body()).get("proofs").size());
    }

}
