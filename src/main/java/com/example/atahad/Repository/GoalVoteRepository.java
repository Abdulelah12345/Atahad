package com.example.atahad.Repository;

import com.example.atahad.Entity.GoalVote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GoalVoteRepository extends JpaRepository<GoalVote, Integer> {
    GoalVote findGoalVoteById(Integer id);

    List<GoalVote> findGoalVotesByGoalProposalId(Integer goalProposalId);

    List<GoalVote> findGoalVotesByGroupMemberIdAndGoalProposalStatus(Integer groupMemberId, String status);
}
