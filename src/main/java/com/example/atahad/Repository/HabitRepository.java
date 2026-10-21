package com.example.atahad.Repository;

import com.example.atahad.Entity.Habit;
import com.example.atahad.Entity.Member;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface HabitRepository extends JpaRepository<Habit, Integer> {
    Habit findHabitById(Integer id);
    List<Habit> findHabitsByMember(Member member);
}
