package com.example.atahad.Repository;

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
}
