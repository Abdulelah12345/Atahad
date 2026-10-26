package com.example.atahad.Repository;

import com.example.atahad.Entity.PointLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface ActivityMapRepository extends JpaRepository<PointLog,Integer> {

    List<PointLog> findByMember_IdAndReasonAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            Integer memberId, String reason, LocalDateTime start, LocalDateTime end);
}