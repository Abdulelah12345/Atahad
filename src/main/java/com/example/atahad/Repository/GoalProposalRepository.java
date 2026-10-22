package com.example.atahad.Repository;

import com.example.atahad.Entity.GoalProposal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GoalProposalRepository extends JpaRepository<GoalProposal, Integer> {
    GoalProposal findGoalProposalById(Integer id);

    List<GoalProposal> findGoalProposalsByGroupIdAndStatus(Integer groupId, String status);
}
