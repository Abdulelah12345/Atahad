package com.example.atahad.Repository;

import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Commitment;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CommitmentWeekRepository extends JpaRepository<CommitmentWeek, Integer> {
    CommitmentWeek findCommitmentWeekById(Integer id);
    List<CommitmentWeek> findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(Commitment commitment);
    CommitmentWeek findTopByCommitmentOrderByWeekNumberDesc(Commitment commitment);
}
