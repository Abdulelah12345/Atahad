package com.example.atahad.Repository;

import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.Member;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface GoalRepository extends JpaRepository<Goal, Integer> {
    Goal findGoalById(Integer id);
    List<Goal> findGoalsByMember(Member member);
}
