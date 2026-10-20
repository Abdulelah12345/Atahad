package com.example.atahad.Repository;

import com.example.atahad.Entity.DonationBatch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface DonationBatchRepository extends JpaRepository<DonationBatch, Integer> {
}
