package com.example.atahad.Repository;

import java.util.List;

import com.example.atahad.Entity.Objection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Repository
public interface ObjectionRepository extends JpaRepository<Objection, Integer> {
    Objection findObjectionById(Integer id);
    // the member's own objections only
    List<Objection> findByMemberIdOrderByIdDesc(Integer memberId);

    /*
     تصل من الاعتراض إلى البروف المرتبطة به، وتبحث عن اعتراض PENDING
     لنفس المهمة والأسبوع ويوم النشاط، على أي محاولة إثبات سابقة.
     وجوده يمنع رفع بديل حتى يحسم الأدمن الاعتراض.
     الربط يستبعد الاعتراضات التي ليست مرتبطة ببروف.
    */
    @Query("""
        SELECT CASE WHEN COUNT(o) > 0 THEN true ELSE false END
        FROM Objection o
        JOIN o.proof p
        WHERE p.goalTask.id = :goalTaskId
          AND p.commitmentWeek.id = :commitmentWeekId
          AND p.activityTime >= :dayStart
          AND p.activityTime < :nextDayStart
          AND o.status = 'PENDING'
        """)
    boolean existsPendingTaskProofObjection(
            @Param("goalTaskId") Integer goalTaskId,
            @Param("commitmentWeekId") Integer commitmentWeekId,
            @Param("dayStart") LocalDateTime dayStart,
            @Param("nextDayStart") LocalDateTime nextDayStart);

    /*
     تصل من الاعتراض إلى العذر المرتبط به وتبحث عن اعتراض PENDING
     لنفس المهمة والأسبوع وتاريخ النشاط.
     وجوده يمنع تقديم البروف حتى يحسم الأدمن الاعتراض على العذر.
     ترجع قيمة منطقية فقط بدون تعديل أي سجل.
    */
    @Query("""
        SELECT CASE WHEN COUNT(o) > 0 THEN true ELSE false END
        FROM Objection o
        JOIN o.excuse e
        WHERE e.goalTask.id = :goalTaskId
          AND e.commitmentWeek.id = :commitmentWeekId
          AND e.excuseDate = :activityDate
          AND o.status = 'PENDING'
        """)
    boolean existsPendingTaskExcuseObjection(
            @Param("goalTaskId") Integer goalTaskId,
            @Param("commitmentWeekId") Integer commitmentWeekId,
            @Param("activityDate") LocalDate activityDate);

    /*
     تفحص وجود بروف مقبولة أو معلقة لنفس الأسبوع والمهمة واليوم.
     عند غياب معرف المهمة تبحث في بروفات العادة فقط، دون بروفات مهام الهدف.
     نستخدم LEFT JOIN حتى تبقى سجلات العادة ذات المهمة الفارغة ضمن البحث.
    */
    @Query("""
        SELECT CASE WHEN COUNT(p) > 0 THEN true ELSE false END
        FROM Proof p LEFT JOIN p.goalTask t
        WHERE p.commitmentWeek.id = :weekId
          AND ((:goalTaskId IS NULL AND t IS NULL) OR t.id = :goalTaskId)
          AND p.activityTime >= :dayStart
          AND p.activityTime < :nextDayStart
          AND p.result IN ('PENDING', 'ACCEPTED')
        """)
    boolean existsBlockingProof(
            @Param("weekId") Integer weekId,
            @Param("goalTaskId") Integer goalTaskId,
            @Param("dayStart") LocalDateTime dayStart,
            @Param("nextDayStart") LocalDateTime nextDayStart);

    /*
     تفحص أعذار نفس الأسبوع والمهمة واليوم التي ما زالت تعالج أو تم قبولها.
     العذر المرفوض لا يمنع الاعتراض؛ المعرف الفارغ للمهمة يخص العادة فقط.
    */
    @Query("""
        SELECT CASE WHEN COUNT(e) > 0 THEN true ELSE false END
        FROM Excuse e LEFT JOIN e.goalTask t
        WHERE e.commitmentWeek.id = :weekId
          AND ((:goalTaskId IS NULL AND t IS NULL) OR t.id = :goalTaskId)
          AND e.excuseDate = :activityDate
          AND e.status IN ('PENDING', 'ESCALATED', 'ACCEPTED')
        """)
    boolean existsBlockingExcuse(
            @Param("weekId") Integer weekId,
            @Param("goalTaskId") Integer goalTaskId,
            @Param("activityDate") LocalDate activityDate);

    /*
     تبحث عن اعتراض قيد الانتظار على بروف لنفس الأسبوع والمهمة ويوم النشاط.
     إذا كان معرف المهمة فارغا، تبحث عن اعتراضات إثبات العادة فقط.
    */
    @Query("""
        SELECT CASE WHEN COUNT(o) > 0 THEN true ELSE false END
        FROM Objection o
        JOIN o.proof p
        JOIN p.commitmentWeek w
        LEFT JOIN p.goalTask t
        WHERE o.status = 'PENDING'
          AND w.id = :weekId
          AND (
            (:goalTaskId IS NULL AND t IS NULL)
            OR t.id = :goalTaskId
          )
          AND p.activityTime >= :dayStart
          AND p.activityTime < :nextDayStart
        """)
    boolean existsPendingProofObjection(
            @Param("weekId") Integer weekId,
            @Param("goalTaskId") Integer goalTaskId,
            @Param("dayStart") LocalDateTime dayStart,
            @Param("nextDayStart") LocalDateTime nextDayStart);

    /*
     تبحث عن اعتراض قيد الانتظار على عذر لنفس الأسبوع والمهمة والتاريخ.
     إذا كان معرف المهمة فارغا، تبحث عن اعتراضات عذر العادة فقط.
    */
    @Query("""
        SELECT CASE WHEN COUNT(o) > 0 THEN true ELSE false END
        FROM Objection o
        JOIN o.excuse e
        JOIN e.commitmentWeek w
        LEFT JOIN e.goalTask t
        WHERE o.status = 'PENDING'
          AND w.id = :weekId
          AND (
            (:goalTaskId IS NULL AND t IS NULL)
            OR t.id = :goalTaskId
          )
          AND e.excuseDate = :activityDate
        """)
    boolean existsPendingExcuseObjection(
            @Param("weekId") Integer weekId,
            @Param("goalTaskId") Integer goalTaskId,
            @Param("activityDate") LocalDate activityDate);

    List<Objection> findObjectionsByStatus(String status);

    Objection findObjectionByDonationProofId(Integer donationProofId);
}
