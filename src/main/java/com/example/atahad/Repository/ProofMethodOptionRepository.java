package com.example.atahad.Repository;

import com.example.atahad.Entity.ProofMethodOption;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProofMethodOptionRepository extends JpaRepository<ProofMethodOption, Integer> {
    ProofMethodOption findProofMethodOptionById(Integer id);
    ProofMethodOption findProofMethodOptionByCode(String code);
    List<ProofMethodOption> findProofMethodOptionsByEnabledTrue();
}
