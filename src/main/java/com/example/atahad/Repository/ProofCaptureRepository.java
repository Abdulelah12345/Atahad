package com.example.atahad.Repository;
import com.example.atahad.Entity.ProofCapture;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
public interface ProofCaptureRepository extends JpaRepository<ProofCapture,Integer> {
    /* locked so one capture can't join two attempts */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c FROM ProofCapture c WHERE c.id = :id")
    ProofCapture findForUpdate(@Param("id") Integer id);
}
