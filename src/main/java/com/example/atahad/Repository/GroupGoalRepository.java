package com.example.atahad.Repository;

import com.example.atahad.Entity.GroupGoal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GroupGoalRepository extends JpaRepository<GroupGoal, Integer> {
    GroupGoal findGroupGoalById(Integer id);

    GroupGoal findGroupGoalByGroupIdAndStatus(Integer groupId, String status);

    List<GroupGoal> findGroupGoalsByStatus(String status);

    List<GroupGoal> findGroupGoalsByGroupIdOrderByStartDateDesc(Integer groupId);
}
