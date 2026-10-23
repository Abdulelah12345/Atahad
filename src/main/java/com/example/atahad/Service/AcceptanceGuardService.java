package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Excuse;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Entity.Proof;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AcceptanceGuardService {
    private final EntityManager entityManager;

    /*
     قد يصل قبول إثبات وقبول عذر لنفس اليوم قبل أن ينتهي أي منهما من الحفظ.
     نحجز سجل الأسبوع حتى نهاية المعاملة، فينتظر القبول الثاني انتهاء الأول.
     ثم نقرأ أحدث البيانات ونتأكد أن اليوم لم يحتسب بطلب آخر.
     القفل لا يخص حساب المستخدم، ويؤخذ بعد رد الذكاء الاصطناعي فقط.
     يجب أن يكون فحص القبول وحفظ القرار وتحديث العداد داخل المعاملة نفسها.
    */
    @Transactional(propagation = Propagation.MANDATORY)
    public void lockAndCheck(Integer weekId, Integer goalTaskId, LocalDate day,
                             Integer proofId, Integer excuseId) {
        CommitmentWeek week = entityManager.find(
                CommitmentWeek.class, weekId, LockModeType.PESSIMISTIC_WRITE);

        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        // قد يكون الأسبوع محملًا قبل انتظار القفل؛ نحدثه حتى لا نستخدم عدادًا قديمًا.
        entityManager.refresh(week, LockModeType.PESSIMISTIC_WRITE);

        if (goalTaskId != null) {
            GoalTask task = entityManager.find(GoalTask.class, goalTaskId);
            if (task == null) {
                throw new ApiException("Goal task not found");
            }
            entityManager.refresh(task, LockModeType.PESSIMISTIC_WRITE);
        }

        // نحدث الطلب الحالي أيضًا، حتى لا تحتسب إعادة قبول الطلب نفسه مرتين.
        if (proofId != null) {
            Proof proof = entityManager.find(Proof.class, proofId);
            if (proof == null) {
                throw new ApiException("Proof not found");
            }
            entityManager.refresh(proof, LockModeType.PESSIMISTIC_WRITE);
        }
        if (excuseId != null) {
            Excuse excuse = entityManager.find(Excuse.class, excuseId);
            if (excuse == null) {
                throw new ApiException("Excuse not found");
            }
            entityManager.refresh(excuse, LockModeType.PESSIMISTIC_WRITE);
        }

        LocalDateTime dayStart = day.atStartOfDay();
        LocalDateTime nextDayStart = day.plusDays(1).atStartOfDay();

        /*
         نبحث عن إثبات آخر مقبول لنفس الأسبوع والمهمة واليوم ونستثني الطلب الحالي.
         المهمة الفارغة تخص العادة فقط، والربط الخارجي يحافظ على سجلاتها.
         القراءة بالقفل ترى آخر قبول محفوظ، حتى مع عزل MySQL الافتراضي.
        */
        List<Proof> acceptedProofs = entityManager.createQuery("""
                SELECT p FROM Proof p LEFT JOIN p.goalTask t
                WHERE p.commitmentWeek.id = :weekId
                  AND ((:goalTaskId IS NULL AND t IS NULL) OR t.id = :goalTaskId)
                  AND p.activityTime >= :dayStart
                  AND p.activityTime < :nextDayStart
                  AND p.result = 'ACCEPTED'
                  AND (:proofId IS NULL OR p.id <> :proofId)
                """, Proof.class)
                .setParameter("weekId", weekId)
                .setParameter("goalTaskId", goalTaskId)
                .setParameter("dayStart", dayStart)
                .setParameter("nextDayStart", nextDayStart)
                .setParameter("proofId", proofId)
                .setLockMode(LockModeType.PESSIMISTIC_WRITE)
                .setMaxResults(1)
                .getResultList();

        if (!acceptedProofs.isEmpty()) {
            throw new ApiException("This day already has an accepted proof");
        }

        /*
         نبحث عن عذر آخر مقبول لنفس الأسبوع والمهمة وتاريخ النشاط.
         نستثني العذر الحالي حتى لا يمنع نفسه، ونستخدم قراءة بالقفل لأحدث البيانات.
        */
        List<Excuse> acceptedExcuses = entityManager.createQuery("""
                SELECT e FROM Excuse e LEFT JOIN e.goalTask t
                WHERE e.commitmentWeek.id = :weekId
                  AND ((:goalTaskId IS NULL AND t IS NULL) OR t.id = :goalTaskId)
                  AND e.excuseDate = :day
                  AND e.status = 'ACCEPTED'
                  AND (:excuseId IS NULL OR e.id <> :excuseId)
                """, Excuse.class)
                .setParameter("weekId", weekId)
                .setParameter("goalTaskId", goalTaskId)
                .setParameter("day", day)
                .setParameter("excuseId", excuseId)
                .setLockMode(LockModeType.PESSIMISTIC_WRITE)
                .setMaxResults(1)
                .getResultList();

        if (!acceptedExcuses.isEmpty()) {
            throw new ApiException("This day already has an accepted excuse");
        }
    }
}
