package com.example.atahad.Repository;

import com.example.atahad.Entity.GraceDay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface GraceDayRepository extends JpaRepository<GraceDay, Integer> {
}
