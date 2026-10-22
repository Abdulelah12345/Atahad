package com.example.atahad.Repository;

import com.example.atahad.Entity.DonationProof;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DonationProofRepository extends JpaRepository<DonationProof, Integer> {
    DonationProof findDonationProofById(Integer id);

    DonationProof findDonationProofByTransactionReference(String transactionReference);

    List<DonationProof> findDonationProofsByMemberIdOrderByCreatedAtDesc(Integer memberId);

    List<DonationProof> findDonationProofsByMemberIdAndStatus(Integer memberId, String status);

    List<DonationProof> findDonationProofsByStatus(String status);
}
