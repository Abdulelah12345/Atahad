package com.example.atahad.Repository;

import com.example.atahad.Entity.ProofChallenge;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProofChallengeRepository extends JpaRepository<ProofChallenge, Integer> {
    ProofChallenge findProofChallengeById(Integer id);
}
