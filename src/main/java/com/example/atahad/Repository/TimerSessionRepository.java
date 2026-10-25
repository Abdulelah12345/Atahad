package com.example.atahad.Repository;
import com.example.atahad.Entity.TimerSession;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.List;
public interface TimerSessionRepository extends JpaRepository<TimerSession,Integer> {
    TimerSession findByProofId(Integer proofId);
    List<TimerSession> findByStatusIn(List<String> statuses);
    /* تسلسل عمليات بدء وإيقاف نفس الجلسة يمنع احتساب الوقت مرتين من جهازين. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT t FROM TimerSession t WHERE t.id = :id")
    TimerSession findForUpdate(@Param("id") Integer id);
}
