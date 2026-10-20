package com.example.atahad.Repository;

import com.example.atahad.Entity.Commitment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CommitmentRepository extends JpaRepository<Commitment, Integer> {
    Commitment findCommitmentById(Integer id);
}
