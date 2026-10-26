package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.*;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import jakarta.persistence.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.*;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@SpringJUnitConfig(WalkingStepsIntegrationTest.Config.class) @Transactional
class WalkingStepsIntegrationTest {
    @Configuration @org.springframework.transaction.annotation.EnableTransactionManagement
    @org.springframework.data.jpa.repository.config.EnableJpaRepositories("com.example.atahad.Repository")
    @Import({WalkingStepsService.class,AcceptanceGuardService.class,ProofOutcomeService.class,ProofTime.class})
    static class Config {
        @Bean javax.sql.DataSource dataSource() {
            return new org.springframework.jdbc.datasource.DriverManagerDataSource("jdbc:h2:mem:walking_steps;MODE=MySQL;NON_KEYWORDS=USER,GROUP,VALUE,MONTH;DB_CLOSE_DELAY=-1","sa","");
        }
        @Bean org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean entityManagerFactory(javax.sql.DataSource ds) {
            var f=new org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean();f.setDataSource(ds);f.setPackagesToScan("com.example.atahad.Entity");
            f.setJpaVendorAdapter(new org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter());
            f.setJpaPropertyMap(Map.of("hibernate.hbm2ddl.auto","create-drop","jakarta.persistence.validation.mode","none"));return f;
        }
        @Bean org.springframework.transaction.PlatformTransactionManager transactionManager(EntityManagerFactory f) { return new org.springframework.orm.jpa.JpaTransactionManager(f); }
        @Bean EntityManager entityManager(EntityManagerFactory f) { return org.springframework.orm.jpa.SharedEntityManagerCreator.createSharedEntityManager(f); }
        @Bean CommitmentWeekService commitmentWeekService() { return mock(CommitmentWeekService.class); }
    }
    @PersistenceContext EntityManager em;
    @Autowired WalkingStepsService walking;
    @Autowired ProofTime time;
    @Autowired CommitmentWeekService counters;
    @Autowired ProofRepository proofs;
    @Autowired ProofOutcomeService outcome;
    @Autowired StepConnectionRepository connections;
    @Autowired DailyStepsRepository steps;
    private Member member;
    private Habit habit;
    private CommitmentWeek week;
    private static final LocalDate DAY=LocalDate.of(2026,10,24);
    void at(String date) {
        var zone=ZoneId.of("Asia/Riyadh");
        ReflectionTestUtils.setField(time,"clock",Clock.fixed(LocalDateTime.parse(date).atZone(zone).toInstant(),zone));
    }
    @BeforeEach void seed() {
        reset(counters);when(counters.remainingTimes(any())).thenReturn(7);
        at("2026-10-24T10:00:00");
        User u=new User();u.setName("Walking tester");u.setEmail(UUID.randomUUID()+"@example.test");u.setPhone("+966501234567");u.setPassword("test-hash");u.setRole("MEMBER");em.persist(u);
        member=new Member();member.setUser(u);em.persist(member);
        habit=new Habit();habit.setTitle("المشي");habit.setMember(member);habit.setProofMethod("STEPS");habit.setTargetSteps(5000);habit.setStepEvidenceMode("HEALTH_DATA");habit.setStatus("ACTIVE");habit.setTimesPerWeek(7);em.persist(habit);
        week=new CommitmentWeek();week.setCommitment(habit);week.setWeekNumber(1);week.setRequired(7);week.setWeekStart(DAY.minusDays(6).atStartOfDay());week.setWeekEnd(DAY.atTime(23,59,59));em.persist(week);em.flush();
        ready();
    }
    StepConnectionRequest check(String status) {
        var r=new StepConnectionRequest();r.setSource("HEALTH_CONNECT");r.setDeviceId("test-phone");r.setStatus(status);
        r.setReadDay(time.now().toLocalDate());r.setStepsRead(0);return r;
    }
    void ready() { walking.check(member.getId(),check("READY")); }
    StepSyncRequest reading(int total,String observed) {
        var r=new StepSyncRequest();r.setDay(DAY);r.setSource("HEALTH_CONNECT");r.setDeviceId("test-phone");
        r.setZoneId("Asia/Riyadh");r.setTotal(total);r.setObservedAt(LocalDateTime.parse(observed));return r;
    }
    Map<String,Object> sync(int total,String observed) { return walking.sync(member.getId(),week.getId(),reading(total,observed)); }
    @Test void zeroIsAValidReadAndDoesNotCompleteTheDay() {
        assertEquals("READY",walking.connection(member.getId()).get("status"));
        var result=sync(0,"2026-10-24T09:00:00");
        assertEquals(0,result.get("totalSteps"));assertEquals("IN_PROGRESS",result.get("status"));
        verify(counters,never()).recordCompletion(anyInt(),any());
    }
    @Test void dailyTotalReplacesInsteadOfAddingAndCompletionIsIdempotent() {
        sync(3000,"2026-10-24T09:00:00");
        var result=sync(5000,"2026-10-24T09:30:00");
        assertEquals("ACCEPTED",result.get("status"));assertEquals(5000,result.get("totalSteps"));
        sync(5000,"2026-10-24T09:30:00");sync(6000,"2026-10-24T09:45:00");
        assertEquals(1,proofs.findProofsByCommitmentWeekId(week.getId()).size());
        verify(counters,times(1)).recordCompletion(week.getId(),null);
    }
    @Test void olderReadCannotOverwriteNewerAndCorrectionsDoNotRevokeAcceptedDay() {
        sync(5000,"2026-10-24T09:30:00");sync(100,"2026-10-24T09:00:00");
        assertEquals(5000,steps.findByMemberIdAndDay(member.getId(),DAY).getTotal());
        var result=sync(4500,"2026-10-24T09:45:00");
        assertEquals(4500,result.get("totalSteps"));assertEquals("ACCEPTED",result.get("status"));
        verify(counters,times(1)).recordCompletion(week.getId(),null);
    }
    @Test void sameTimestampWithDifferentTotalIsRejected() {
        sync(3000,"2026-10-24T09:00:00");
        assertThrows(ApiException.class,()->sync(5000,"2026-10-24T09:00:00"));
    }
    @Test void saturdayTotalCanArriveOnSundayButNotMonday() {
        at("2026-10-25T12:00:00");ready();
        assertEquals("ACCEPTED",sync(6000,"2026-10-25T11:59:00").get("status"));
        at("2026-10-26T00:00:00");ready();
        assertThrows(ApiException.class,()->sync(6500,"2026-10-26T00:00:00"));
    }
    @Test void futureDayOldObservationAndWrongZoneAreRejected() {
        var future=reading(5000,"2026-10-24T09:00:00");future.setDay(DAY.plusDays(1));
        assertThrows(ApiException.class,()->walking.sync(member.getId(),week.getId(),future));
        assertThrows(ApiException.class,()->sync(5000,"2026-10-24T11:00:00"));
        var wrong=reading(5000,"2026-10-24T09:00:00");wrong.setZoneId("UTC");
        assertThrows(ApiException.class,()->walking.sync(member.getId(),week.getId(),wrong));
        assertThrows(ApiException.class,()->sync(5000,"2026-10-22T09:00:00"));
    }
    @Test void crossMemberWeekAndProgressAreDenied() {
        User other=new User();other.setName("Other");other.setEmail(UUID.randomUUID()+"@example.test");other.setPassword("test-hash");other.setPhone("+966501234567");other.setRole("MEMBER");em.persist(other);
        Member otherMember=new Member();otherMember.setUser(other);em.persist(otherMember);em.flush();
        assertThrows(org.springframework.security.access.AccessDeniedException.class,()->walking.sync(otherMember.getId(),week.getId(),reading(5000,"2026-10-24T09:00:00")));
        assertThrows(org.springframework.security.access.AccessDeniedException.class,()->walking.progress(member.getId()+1,week.getId(),DAY));
    }
    @Test void changingSourceDuringTheSameDayDoesNotDoubleCount() {
        sync(3000,"2026-10-24T09:00:00");
        var connection=check("READY");connection.setSource("HEALTH_KIT");walking.check(member.getId(),connection);
        var r=reading(5000,"2026-10-24T09:30:00");r.setSource("HEALTH_KIT");
        assertThrows(ApiException.class,()->walking.sync(member.getId(),week.getId(),r));
    }
    @Test void unavailableOrRevokedConnectionCannotSync() {
        walking.check(member.getId(),check("NEEDS_PERMISSION"));
        assertThrows(ApiException.class,()->sync(5000,"2026-10-24T09:00:00"));
    }
    @Test void readyRequiresReadTodayButScreenshotModeCanActivateWithoutConnection() {
        var r=check("READY");r.setStepsRead(null);
        assertThrows(ApiException.class,()->walking.check(member.getId(),r));
        connections.deleteById(member.getId());connections.flush();
        assertThrows(ApiException.class,()->walking.checkActivation(member.getId(),habit));
        habit.setStepEvidenceMode("SCREENSHOT");assertDoesNotThrow(()->walking.checkActivation(member.getId(),habit));
    }
    @Test void oldPreflightRequiresRecheck() {
        at("2026-10-25T10:00:01");
        assertEquals("CHECK_REQUIRED",walking.connection(member.getId()).get("status"));
        assertThrows(ApiException.class,()->walking.checkActivation(member.getId(),habit));
    }
    StepScreenshotRequest screenshot() throws Exception {
        var output=new java.io.ByteArrayOutputStream();
        ImageIOHelper.write(output);
        var r=new StepScreenshotRequest();r.setDay(DAY);r.setImageData("data:image/png;base64,"+Base64.getEncoder().encodeToString(output.toByteArray()));return r;
    }
    static class ImageIOHelper {
        static void write(java.io.ByteArrayOutputStream output) throws Exception {
            javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(2,2,java.awt.image.BufferedImage.TYPE_INT_RGB),"png",output);
        }
    }
    @Test void screenshotAwaitsReviewAndAdminAcceptanceCountsOnce() throws Exception {
        sync(3000,"2026-10-24T09:00:00");
        var r=walking.screenshot(member.getId(),week.getId(),screenshot());
        assertEquals("ESCALATED",r.get("status"));verify(counters,never()).recordCompletion(anyInt(),any());
        Proof p=proofs.findProofById((Integer)r.get("proofId"));
        outcome.review(p,true,"Date and total checked");outcome.review(p,true,"retry");
        verify(counters,times(1)).recordCompletion(week.getId(),null);
    }
    @Test void screenshotRejectionIsFinalAndImageIsNotExposedInProofData() throws Exception {
        var r=walking.screenshot(member.getId(),week.getId(),screenshot());
        Proof p=proofs.findProofById((Integer)r.get("proofId"));
        assertFalse(p.getEvidenceData().contains("base64"));outcome.review(p,false,"Date missing");
        assertEquals("REJECTED",p.getResult());
        assertEquals(true,walking.progress(member.getId(),week.getId(),DAY).get("screenshotSubmitted"));
    }
    @Test void invalidImageIsRejectedBeforeCreatingProof() {
        var r=new StepScreenshotRequest();r.setDay(DAY);r.setImageData("data:image/png;base64,YWJj");
        assertThrows(ApiException.class,()->walking.screenshot(member.getId(),week.getId(),r));
        assertTrue(proofs.findProofsByCommitmentWeekId(week.getId()).isEmpty());
    }
    @Test void acceptedExcusePreventsAnotherCompletionForSameDay() {
        Excuse excuse=new Excuse();excuse.setType("OTHER");excuse.setCommitmentWeek(week);excuse.setExcuseDate(DAY);excuse.setStatus("ACCEPTED");excuse.setProcessingStatus("FINISHED");em.persist(excuse);em.flush();
        sync(6000,"2026-10-24T09:00:00");verify(counters,never()).recordCompletion(anyInt(),any());
        assertTrue(proofs.findProofsByCommitmentWeekId(week.getId()).isEmpty());
    }
    @Test void stepsTargetsCannotBeMissingAndGoalsAreNotEnabledAccidentally() {
        assertDoesNotThrow(()->CommitmentService.checkTargets(habit));habit.setTargetSteps(null);
        assertThrows(ApiException.class,()->CommitmentService.checkTargets(habit));
        Goal goal=new Goal();goal.setProofMethod("STEPS");goal.setTargetSteps(5000);goal.setStepEvidenceMode("SCREENSHOT");
        assertThrows(ApiException.class,()->CommitmentService.checkTargets(goal));
    }

    @Test void simultaneousSyncRetriesCreateOnlyOneDayAndOneCompletion() throws Exception {
        org.springframework.test.context.transaction.TestTransaction.flagForCommit();
        org.springframework.test.context.transaction.TestTransaction.end();
        var pool=java.util.concurrent.Executors.newFixedThreadPool(2);
        var go=new java.util.concurrent.CountDownLatch(1);
        try {
            var replies=new ArrayList<java.util.concurrent.Future<Map<String,Object>>>();
            for(int i=0;i<2;i++) { replies.add(pool.submit(()->{
                assertTrue(go.await(10,java.util.concurrent.TimeUnit.SECONDS));return sync(5000,"2026-10-24T09:00:00");
            })); }
            go.countDown();
            for(var result:replies) { assertEquals("ACCEPTED",result.get(30,java.util.concurrent.TimeUnit.SECONDS).get("status")); }
            verify(counters,times(1)).recordCompletion(week.getId(),null);
        } finally { go.countDown();pool.shutdownNow(); }
    }

    @Test void deletingMemberRemovesPrivateWalkingData() {
        User other=new User();other.setName("Removed");other.setEmail(UUID.randomUUID()+"@example.test");other.setPassword("test-hash");other.setPhone("+966501234567");other.setRole("MEMBER");em.persist(other);
        Member m=new Member();m.setUser(other);em.persist(m);em.flush();Integer id=m.getId();
        walking.check(id,check("READY"));
        DailySteps d=new DailySteps();d.setMember(m);d.setDay(DAY);d.setTotal(123);d.setSource("HEALTH_CONNECT");d.setDeviceId("test-phone");d.setZoneId("Asia/Riyadh");steps.saveAndFlush(d);
        em.remove(m);em.flush();em.clear();
        assertTrue(connections.findById(id).isEmpty());assertNull(steps.findByMemberIdAndDay(id,DAY));
    }
}
