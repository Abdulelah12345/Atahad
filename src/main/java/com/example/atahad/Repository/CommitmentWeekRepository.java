package com.example.atahad.Repository;

import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface CommitmentWeekRepository extends JpaRepository<CommitmentWeek, Integer> {
    CommitmentWeek findCommitmentWeekById(Integer id);

    List<CommitmentWeek> findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(Commitment commitment);

    CommitmentWeek findTopByCommitmentOrderByWeekNumberDesc(Commitment commitment);

    Integer countCommitmentWeeksByCommitmentMemberAndIsFullWeekTrue(Member member);

    List<CommitmentWeek> findCommitmentWeeksByCommitmentMember(Member member);
    List<CommitmentWeek> findCommitmentWeeksByWeekStartGreaterThanEqualAndWeekStartLessThan(LocalDateTime start, LocalDateTime end);
}
