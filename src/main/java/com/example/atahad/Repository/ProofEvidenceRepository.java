package com.example.atahad.Repository;
import com.example.atahad.Entity.ProofEvidence;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface ProofEvidenceRepository extends JpaRepository<ProofEvidence,Integer> {
    List<ProofEvidence> findByProofIdOrderById(Integer proofId);
    /* locked read, so we never use an old result after waiting */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("SELECT e FROM ProofEvidence e WHERE e.proof.id = :id ORDER BY e.id")
    List<ProofEvidence> findForDecision(@org.springframework.data.repository.query.Param("id") Integer id);
    ProofEvidence findFirstByProofIdAndType(Integer proofId,String type);
}
