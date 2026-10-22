package com.example.atahad.Repository;

import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.Penalty;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface PenaltyRepository extends JpaRepository<Penalty, Integer> {
    Penalty findPenaltyById(Integer id);

    List<Penalty> findPenaltiesByCommitmentWeek(CommitmentWeek commitmentWeek);

    List<Penalty> findPenaltiesByMemberAndStatus(Member member, String status);

    // group penalties that were not paid for a long time
    List<Penalty> findPenaltiesByStatusAndGroupSettlementIsNotNullAndCreatedAtBefore(String status, LocalDateTime before);

    List<Penalty> findPenaltiesByMemberIdOrderByCreatedAtDesc(Integer memberId);
}
