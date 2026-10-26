package com.example.atahad.Service;

import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.*;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WalkingSettlementTest {
    @Mock CommitmentWeekRepository weeks;
    @Mock CommitmentRepository commitments;
    @Mock GoalTaskRepository tasks;
    @Mock PenaltyRepository penalties;
    @Mock GraceDayRepository grace;
    @Mock PointLogRepository points;
    @Mock MemberRepository members;
    @Mock LockService locks;
    @Mock WhatsAppService whatsapp;
    @Mock ProofRepository proofs;
    @InjectMocks CommitmentWeekService service;
    private Member member;
    private Habit habit;
    private CommitmentWeek week;
    @BeforeEach void seed() {
        member=new Member();member.setId(1);member.setLevel("BEGINNER");
        habit=new Habit();habit.setId(2);habit.setTitle("Walking");habit.setMember(member);habit.setProofMethod("STEPS");habit.setStatus("ACTIVE");habit.setTimesPerWeek(7);habit.setBaseAmount(BigDecimal.valueOf(5));
        week=new CommitmentWeek();week.setId(3);week.setCommitment(habit);week.setWeekStart(LocalDateTime.of(2026,10,18,0,0));week.setWeekEnd(LocalDateTime.of(2026,10,24,23,59,59));
        week.setRequired(7);week.setCompleted(6);week.setAmountPerDay(BigDecimal.valueOf(5));week.setWeekNumber(1);week.setStepsSettlementPending(true);
    }
    @Test void sundayStillAllowsSaturdaySyncWithoutPenaltyOrGraceConsumption() {
        service.evaluateWeek(week,LocalDate.of(2026,10,25));
        assertEquals("MUST_TODAY",week.getTrackStatus());
        verify(penalties,never()).save(any());verify(grace,never()).save(any());
    }
    @Test void mondayWithoutSyncCanSettleTheMissingDay() {
        service.evaluateWeek(week,LocalDate.of(2026,10,26));
        assertEquals("LOST_DAY",week.getTrackStatus());verify(penalties).save(any());
    }
    @Test void screenshotAwaitingReviewDoesNotProducePenaltyAfterGrace() {
        when(proofs.countPendingStepReviews(eq(3),any())).thenReturn(1);
        service.evaluateWeek(week,LocalDate.of(2026,10,27));
        verify(penalties,never()).save(any());verify(grace,never()).save(any());
    }
    @Test void normalPhotoHabitKeepsExistingSundayDeadline() {
        habit.setProofMethod("PHOTO");service.evaluateWeek(week,LocalDate.of(2026,10,25));
        assertEquals("LOST_DAY",week.getTrackStatus());verify(penalties).save(any());
    }
    @Test void sundayStartsNextWeekWithoutClosingStepWeekOrUpdatingLevel() {
        when(commitments.findCommitmentsByStatus("ACTIVE")).thenReturn(List.of(habit));
        when(weeks.findTopByCommitmentOrderByWeekNumberDesc(habit)).thenReturn(week);
        when(weeks.findCommitmentWeeksByCommitmentMember(member)).thenReturn(List.of(week));
        service.runDaily(LocalDate.of(2026,10,25));
        verify(penalties,never()).save(any());verify(members,never()).save(any());
        assertTrue(week.getStepsSettlementPending());
        verify(weeks,atLeastOnce()).save(argThat(w->w.getWeekNumber()==2 && w.getWeekStart().toLocalDate().equals(LocalDate.of(2026,10,25))));
    }
    @Test void mondayFinalizesCompletedStepWeekAndUpdatesCombinedLevelOnce() {
        week.setCompleted(7);
        when(weeks.findByStepsSettlementPendingTrueAndWeekEndBefore(any())).thenReturn(List.of(week));
        when(weeks.findCommitmentWeeksByCommitmentMember(member)).thenReturn(List.of(week));
        service.runDaily(LocalDate.of(2026,10,26));
        assertFalse(week.getStepsSettlementPending());assertTrue(week.getIsFullWeek());
        assertEquals(1,member.getConsecutiveWeeks());assertEquals(30,member.getPoints());
        verify(penalties,never()).save(any());
    }
    @Test void unresolvedScreenshotDefersWeeklySettlementAndLevel() {
        when(weeks.findByStepsSettlementPendingTrueAndWeekEndBefore(any())).thenReturn(List.of(week));
        when(proofs.countPendingStepReviews(eq(3),any())).thenReturn(1);
        service.runDaily(LocalDate.of(2026,10,26));
        assertTrue(week.getStepsSettlementPending());verify(members,never()).save(any());verify(penalties,never()).save(any());
    }

    @Test void anotherStepHabitAwaitingReviewDefersTheWholeMembersLevelUpdate() {
        CommitmentWeek other=new CommitmentWeek();other.setId(4);other.setCommitment(habit);other.setWeekEnd(week.getWeekEnd());
        other.setStepsSettlementPending(true);
        when(weeks.findByStepsSettlementPendingTrueAndWeekEndBefore(any())).thenReturn(List.of(week,other));
        when(proofs.countPendingStepReviews(anyInt(),any())).thenAnswer(call->Integer.valueOf(4).equals(call.getArgument(0))?1:0);
        service.runDaily(LocalDate.of(2026,10,26));
        assertTrue(week.getStepsSettlementPending());assertTrue(other.getStepsSettlementPending());
        verify(members,never()).save(any());verify(points,never()).save(any());
    }
    @Test void aFailedNormalHabitIsIncludedInTheCombinedDelayedLevelUpdate() {
        week.setCompleted(7);member.setLevel("COMMITTED");member.setConsecutiveWeeks(4);
        CommitmentWeek normal=new CommitmentWeek();normal.setWeekEnd(week.getWeekEnd());normal.setIsFullWeek(false);
        when(weeks.findByStepsSettlementPendingTrueAndWeekEndBefore(any())).thenReturn(List.of(week));
        when(weeks.findCommitmentWeeksByCommitmentMember(member)).thenReturn(List.of(week,normal));
        service.runDaily(LocalDate.of(2026,10,26));
        assertTrue(week.getIsFullWeek());assertEquals("BEGINNER",member.getLevel());assertEquals(0,member.getConsecutiveWeeks());
    }
}
