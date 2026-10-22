package com.example.atahad.Repository;

import com.example.atahad.Entity.PointLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PointLogRepository extends JpaRepository<PointLog, Integer> {
    PointLog findPointLogById(Integer id);

    List<PointLog> findPointLogsByMemberIdOrderByCreatedAtDesc(Integer memberId);

    List<PointLog> findPointLogsByGroupIdOrderByCreatedAtDesc(Integer groupId);
}
