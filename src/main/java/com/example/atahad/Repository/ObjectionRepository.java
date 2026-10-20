package com.example.atahad.Repository;

import com.example.atahad.Entity.Objection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ObjectionRepository extends JpaRepository<Objection, Integer> {
    Objection findObjectionById(Integer id);
}
