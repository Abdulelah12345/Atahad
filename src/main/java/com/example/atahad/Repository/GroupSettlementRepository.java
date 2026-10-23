package com.example.atahad.Repository;

import com.example.atahad.Entity.GroupSettlement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface GroupSettlementRepository extends JpaRepository<GroupSettlement, Integer> {
    GroupSettlement findGroupSettlementById(Integer id);

    GroupSettlement findGroupSettlementByGroupGoalIdAndWeekStart(Integer groupGoalId, LocalDate weekStart);

    List<GroupSettlement> findGroupSettlementsByGroupGoalGroupIdOrderByCreatedAtDesc(Integer groupId);

    List<GroupSettlement> findGroupSettlementsByGroupGoalGroupIdAndWeekStartBetween(Integer groupId, LocalDate from, LocalDate to);
}
