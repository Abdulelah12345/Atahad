package com.example.atahad.Repository;

import com.example.atahad.Entity.MonthlyWrapped;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MonthlyWrappedRepository extends JpaRepository<MonthlyWrapped, Integer> {
    MonthlyWrapped findMonthlyWrappedById(Integer id);

    MonthlyWrapped findMonthlyWrappedByMemberIdAndMonth(Integer memberId, String month);

    List<MonthlyWrapped> findMonthlyWrappedsByMemberIdOrderByMonthDesc(Integer memberId);
}
