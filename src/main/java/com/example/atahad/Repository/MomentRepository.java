package com.example.atahad.Repository;

import com.example.atahad.Entity.Moment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MomentRepository extends JpaRepository<Moment, Integer> {
    Moment findMomentById(Integer id);

    List<Moment> findMomentsByMemberIdOrderByCreatedAtDesc(Integer memberId);

    List<Moment> findMomentsByGroupIdAndVisibilityOrderByCreatedAtDesc(Integer groupId, String visibility);
}
