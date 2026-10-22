package com.example.atahad.Repository;

import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.GroupGoal;
import com.example.atahad.Entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CommitmentRepository extends JpaRepository<Commitment, Integer> {
    Commitment findCommitmentById(Integer id);

    List<Commitment> findCommitmentsByMember(Member member);

    List<Commitment> findCommitmentsByStatus(String status);

    List<Commitment> findCommitmentsByMemberAndStatus(Member member, String status);

    List<Commitment> findCommitmentsByGroupGoal(GroupGoal groupGoal);
}
