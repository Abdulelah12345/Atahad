package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.CommitmentRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CommitmentService {
    private final CommitmentRepository commitmentRepository;
    private final MemberRepository memberRepository;

    // habits and goals together
    public List<Commitment> getMyCommitments(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return commitmentRepository.findCommitmentsByMember(member);
    }

    public Commitment getCommitment(Integer memberId, Integer id){
        Commitment commitment = commitmentRepository.findCommitmentById(id);
        if(commitment == null){
            throw new ApiException("Commitment not found");
        }
        if(!commitment.getMember().getId().equals(memberId)){
            throw new ApiException("You can only see your own commitment");
        }
        return commitment;
    }

    // the withdrawal is right away, the money left this week goes to donation
    public void withdraw(Integer memberId, Integer id){
        Commitment commitment = getCommitment(memberId, id);
        if(commitment.getStatus().equals("WITHDRAWN") || commitment.getStatus().equals("ENDED")){
            throw new ApiException("Commitment is already finished");
        }
        // TODO: ask the payment service to capture the holds left in the current week
        commitment.setStatus("WITHDRAWN");
        commitmentRepository.save(commitment);
    }
}
