package com.example.atahad.Repository;

import com.example.atahad.Entity.LuckyChallenge;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;

@Repository
public interface LuckyChallengeRepository extends JpaRepository<LuckyChallenge, Integer> {

    LuckyChallenge findLuckyChallengeById(Integer id);

    LuckyChallenge findLuckyChallengeByMemberIdAndChallengeDate(Integer memberId, LocalDate challengeDate);
}