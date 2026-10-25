package com.example.atahad.Service;

import com.example.atahad.Entity.*;
import com.example.atahad.Api.ApiException;
import jakarta.persistence.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@SpringJUnitConfig(ProofFeatureIntegrationTest.Config.class)
class ProofConcurrencyIntegrationTest {
    @PersistenceContext EntityManager em;
    @Autowired PlatformTransactionManager manager;
    @Autowired ProofOutcomeService outcome;
    @Autowired CommitmentWeekService counters;
    @Test void simultaneousAcceptancesForOneDayCreditOnlyOneProof() throws Exception {
        reset(counters);
        var tx=new TransactionTemplate(manager);
        Integer[] ids=tx.execute(status->{
            User user=new User();user.setName("Race");user.setEmail(UUID.randomUUID()+"@example.test");user.setPhone("+966501234567");user.setPassword("test-hash");user.setRole("MEMBER");em.persist(user);
            Member member=new Member();member.setUser(user);em.persist(member);
            Habit habit=new Habit();habit.setTitle("Concurrent activity");habit.setMember(member);habit.setStatus("ACTIVE");habit.setProofMethod("PHOTO");habit.setTimesPerWeek(3);em.persist(habit);
            CommitmentWeek week=new CommitmentWeek();week.setCommitment(habit);week.setWeekNumber(1);week.setRequired(3);week.setWeekStart(LocalDateTime.of(2026,10,18,0,0));week.setWeekEnd(LocalDateTime.of(2026,10,24,23,59));em.persist(week);
            Integer[] result=new Integer[3];result[0]=week.getId();
            for(int i=1;i<=2;i++) {
                Proof proof=new Proof();proof.setType("PHOTO");proof.setEvidenceData("test");proof.setResult("PENDING");proof.setProcessingStatus("WAITING");proof.setActivityTime(LocalDateTime.of(2026,10,24,10,0));proof.setCommitmentWeek(week);em.persist(proof);result[i]=proof.getId();
            }
            return result;
        });
        var ready=new CountDownLatch(2);var go=new CountDownLatch(1);var pool=Executors.newFixedThreadPool(2);
        try {
            List<Future<Boolean>> replies=new ArrayList<>();
            for(int i=1;i<=2;i++) {
                int id=ids[i];
                replies.add(pool.submit(()->{
                    try {
                        return new TransactionTemplate(manager).execute(status->{
                            Proof proof=em.find(Proof.class,id);ready.countDown();
                            try { if(!go.await(10,TimeUnit.SECONDS))throw new IllegalStateException("Barrier timeout"); }
                            catch(InterruptedException ex) { Thread.currentThread().interrupt();throw new IllegalStateException(ex); }
                            outcome.primary(proof,"ACCEPTED","verified");return true;
                        });
                    } catch(ApiException duplicate) { assertTrue(duplicate.getMessage().contains("already has an accepted"));return false; }
                }));
            }
            assertTrue(ready.await(10,TimeUnit.SECONDS));go.countDown();
            int accepted=0;for(var reply:replies)if(reply.get(30,TimeUnit.SECONDS))accepted++;
            assertEquals(1,accepted);verify(counters,times(1)).recordCompletion(ids[0],null);
        } finally { go.countDown();pool.shutdownNow(); }
    }
}
