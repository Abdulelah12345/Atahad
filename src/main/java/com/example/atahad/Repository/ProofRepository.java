package com.example.atahad.Repository;

import com.example.atahad.Entity.Proof;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProofRepository extends JpaRepository<Proof, Integer> {
    Proof findProofById(Integer id);
}
