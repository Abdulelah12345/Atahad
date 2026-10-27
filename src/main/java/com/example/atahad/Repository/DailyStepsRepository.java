package com.example.atahad.Repository;
import com.example.atahad.Entity.DailySteps;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
public interface DailyStepsRepository extends JpaRepository<DailySteps,Integer> {
    DailySteps findByMemberIdAndDay(Integer memberId, LocalDate day);
}
