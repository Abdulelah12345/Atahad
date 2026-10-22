package com.example.atahad.Repository;

import com.example.atahad.Entity.GroupMatch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GroupMatchRepository extends JpaRepository<GroupMatch, Integer> {
    GroupMatch findGroupMatchById(Integer id);

    List<GroupMatch> findGroupMatchesByStatus(String status);

    List<GroupMatch> findGroupMatchesByChallengerIdOrOpponentIdOrderByIdDesc(Integer challengerId, Integer opponentId);
}
