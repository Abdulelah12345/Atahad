package com.example.atahad.Repository;

import com.example.atahad.Entity.Proof;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.time.LocalDateTime;


@Repository
public interface ProofRepository extends JpaRepository<Proof, Integer> {
    Proof findProofById(Integer id);

    /*
     تبحث عن بروف لنفس المهمة والأسبوع وفي نفس يوم النشاط وبالحالة المطلوبة.
     بداية اليوم داخلة في البحث وبداية اليوم التالي غير داخلة.
     ترجع true إذا وجد سجل مطابق، وإلا false، بدون تعديل البيانات.
    */
    @Query("""
        SELECT CASE WHEN COUNT(p) > 0 THEN true ELSE false END
        FROM Proof p
        WHERE p.goalTask.id = :goalTaskId
          AND p.commitmentWeek.id = :commitmentWeekId
          AND p.activityTime >= :dayStart
          AND p.activityTime < :nextDayStart
          AND p.result = :result
        """)
    boolean existsTaskProof(
            @Param("goalTaskId") Integer goalTaskId,
            @Param("commitmentWeekId") Integer commitmentWeekId,
            @Param("dayStart") LocalDateTime dayStart,
            @Param("nextDayStart") LocalDateTime nextDayStart,
            @Param("result") String result);
}
