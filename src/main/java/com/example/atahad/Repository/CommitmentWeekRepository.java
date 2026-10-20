package com.example.atahad.Repository;

import com.example.atahad.Entity.CommitmentWeek;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CommitmentWeekRepository extends JpaRepository<CommitmentWeek, Integer> {
}
