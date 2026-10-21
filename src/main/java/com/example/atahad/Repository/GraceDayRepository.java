package com.example.atahad.Repository;

import com.example.atahad.Entity.GraceDay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GraceDayRepository extends JpaRepository<GraceDay, Integer> {
    GraceDay findGraceDayById(Integer id);
    List<GraceDay> findGraceDaysByMemberId(Integer memberId);

    List<GraceDay> findGraceDaysByAdminId(Integer adminId);
}
