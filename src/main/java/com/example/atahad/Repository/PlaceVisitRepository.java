package com.example.atahad.Repository;

import com.example.atahad.Entity.PlaceVisit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PlaceVisitRepository extends JpaRepository<PlaceVisit, Integer> {
    PlaceVisit findPlaceVisitById(Integer id);

    PlaceVisit findFirstByMemberIdAndCommitmentIdAndStatus(Integer memberId, Integer commitmentId, String status);

    List<PlaceVisit> findPlaceVisitsByStatus(String status);

    List<PlaceVisit> findPlaceVisitsByMemberIdOrderByEnteredAtDesc(Integer memberId);
}
