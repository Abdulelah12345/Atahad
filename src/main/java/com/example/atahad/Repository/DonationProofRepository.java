package com.example.atahad.Repository;

import com.example.atahad.Entity.DonationProof;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface DonationProofRepository extends JpaRepository<DonationProof, Integer> {
    DonationProof findDonationProofById(Integer id);
}
