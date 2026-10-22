package com.example.atahad.Repository;

import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Entity.Goal;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface GoalTaskRepository extends JpaRepository<GoalTask, Integer> {
    GoalTask findGoalTaskById(Integer id);
    List<GoalTask> findGoalTasksByGoalOrderByWeekNumber(Goal goal);
    List<GoalTask> findGoalTasksByGoalAndWeekNumber(Goal goal, Integer weekNumber);
}
