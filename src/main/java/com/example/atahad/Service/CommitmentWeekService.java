package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Repository.CommitmentWeekRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

// weeks are created by the weekly automation, not by the user
@Service
@RequiredArgsConstructor
public class CommitmentWeekService {
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final CommitmentService commitmentService;

    // shared with the other services
    public CommitmentWeek getWeekById(Integer id){
        CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(id);
        if(week == null){
            throw new ApiException("Week not found");
        }
        return week;
    }

    public List<CommitmentWeek> getHistory(Integer memberId, Integer commitmentId){
        Commitment commitment = commitmentService.getCommitment(memberId, commitmentId);
        return commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(commitment);
    }

    public CommitmentWeek getCurrentWeek(Integer memberId, Integer commitmentId){
        Commitment commitment = commitmentService.getCommitment(memberId, commitmentId);
        CommitmentWeek week = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
        if(week == null || week.getWeekEnd().isBefore(LocalDateTime.now())){
            throw new ApiException("This commitment has no running week");
        }
        return week;
    }
}
