package com.example.atahad.Repository;

import com.example.atahad.Entity.Excuse;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;
import java.time.LocalDateTime;


@Repository
public interface ExcuseRepository extends JpaRepository<Excuse, Integer> {
    Excuse findExcuseById(Integer id);
    // سجل أعذار العضو المسجل فقط، للأهداف والعادات.
    List<Excuse> findByCommitmentWeekCommitmentMemberIdOrderByIdDesc(Integer memberId);


    /*
     تبحث عن عذر مرتبط بنفس المهمة والأسبوع وتاريخ النشاط والحالة المرسلة.
     نستخدمها لفحص العذر المقبول أو قيد المعالجة أو المحول للأدمن.
     تاريخ العذر بدون ساعة، لذلك نقارنه مباشرة بتاريخ النشاط.
     ترجع وجود السجل فقط ولا تعدل العذر أو العدادات.
    */
    @Query("""
        SELECT CASE WHEN COUNT(e) > 0 THEN true ELSE false END
        FROM Excuse e
        WHERE e.goalTask.id = :goalTaskId
          AND e.commitmentWeek.id = :commitmentWeekId
          AND e.excuseDate = :activityDate
          AND e.status = :status
        """)
    boolean existsTaskExcuse(
            @Param("goalTaskId") Integer goalTaskId,
            @Param("commitmentWeekId") Integer commitmentWeekId,
            @Param("activityDate") LocalDate activityDate,
            @Param("status") String status);

    List<Excuse> findExcusesByStatus(String status);

    List<Excuse> findExcusesByCommitmentWeekCommitmentMemberIdAndStatus(Integer memberId, String status);

    List<Excuse> findExcusesByCommitmentWeekId(Integer commitmentWeekId);
}
