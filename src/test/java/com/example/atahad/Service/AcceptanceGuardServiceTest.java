package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import jakarta.persistence.TypedQuery;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AcceptanceGuardServiceTest {
    private final EntityManager entityManager = mock(EntityManager.class);
    private final AcceptanceGuardService guard = new AcceptanceGuardService(entityManager);
    private final CommitmentWeek week = new CommitmentWeek();
    private final LocalDate day = LocalDate.of(2026, 10, 24);
    private TypedQuery<Proof> proofQuery;
    private TypedQuery<Excuse> excuseQuery;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void prepare() {
        proofQuery = mock(TypedQuery.class, RETURNS_SELF);
        excuseQuery = mock(TypedQuery.class, RETURNS_SELF);
        when(entityManager.find(CommitmentWeek.class, 1, LockModeType.PESSIMISTIC_WRITE)).thenReturn(week);
        when(entityManager.createQuery(anyString(), eq(Proof.class))).thenReturn(proofQuery);
        when(entityManager.createQuery(anyString(), eq(Excuse.class))).thenReturn(excuseQuery);
        when(proofQuery.getResultList()).thenReturn(List.of());
        when(excuseQuery.getResultList()).thenReturn(List.of());
    }

    @Test
    void locksAndRefreshesWeekBeforeCheckingHabitDay() {
        guard.lockAndCheck(1, null, day, null, null);
        var order = inOrder(entityManager, proofQuery, excuseQuery);
        order.verify(entityManager).find(CommitmentWeek.class, 1, LockModeType.PESSIMISTIC_WRITE);
        order.verify(entityManager).refresh(week, LockModeType.PESSIMISTIC_WRITE);
        order.verify(entityManager).createQuery(anyString(), eq(Proof.class));
        order.verify(proofQuery).getResultList();
        order.verify(entityManager).createQuery(anyString(), eq(Excuse.class));
        order.verify(excuseQuery).getResultList();
        verify(proofQuery).setParameter("goalTaskId", null);
        verify(proofQuery).setParameter("dayStart", day.atStartOfDay());
        verify(proofQuery).setParameter("nextDayStart", day.plusDays(1).atStartOfDay());
        verify(proofQuery).setLockMode(LockModeType.PESSIMISTIC_WRITE);
        verify(excuseQuery).setLockMode(LockModeType.PESSIMISTIC_WRITE);
    }

    @Test
    void blocksAcceptanceWhenAnotherProofAlreadyCounted() {
        when(proofQuery.getResultList()).thenReturn(List.of(new Proof()));
        ApiException error = assertThrows(ApiException.class,
                () -> guard.lockAndCheck(1, null, day, null, null));
        assertEquals("This day already has an accepted proof", error.getMessage());
    }

    @Test
    void blocksAcceptanceWhenAnExcuseAlreadyCounted() {
        when(excuseQuery.getResultList()).thenReturn(List.of(new Excuse()));
        ApiException error = assertThrows(ApiException.class,
                () -> guard.lockAndCheck(1, null, day, null, null));
        assertEquals("This day already has an accepted excuse", error.getMessage());
    }

    @Test
    void refreshesTaskAndCurrentProofAndExcludesItFromDuplicateSearch() {
        GoalTask task = new GoalTask();
        Proof proof = new Proof();
        when(entityManager.find(GoalTask.class, 2)).thenReturn(task);
        when(entityManager.find(Proof.class, 3)).thenReturn(proof);
        guard.lockAndCheck(1, 2, day, 3, null);
        verify(entityManager).refresh(task, LockModeType.PESSIMISTIC_WRITE);
        verify(entityManager).lock(proof, LockModeType.PESSIMISTIC_WRITE);
        verify(proofQuery).setParameter("proofId", 3);
        verify(proofQuery).setParameter("goalTaskId", 2);
    }
}
