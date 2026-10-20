package com.example.atahad.Repository;

import com.example.atahad.Entity.Excuse;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ExcuseRepository extends JpaRepository<Excuse, Integer> {
    Excuse findExcuseById(Integer id);
}
