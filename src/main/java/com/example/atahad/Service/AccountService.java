package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Admin;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.GroupMember;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.AdminRepository;
import com.example.atahad.Repository.CommitmentRepository;
import com.example.atahad.Repository.GroupMemberRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.PenaltyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

// deactivating the account and the admin unban
@Service
@RequiredArgsConstructor
public class AccountService {
    private final MemberRepository memberRepository;
    private final AdminRepository adminRepository;
    private final PenaltyRepository penaltyRepository;
    private final CommitmentRepository commitmentRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final GroupMemberService groupMemberService;

    // everything stops: he leaves every group and every commitment ends, the donations he owes must be paid first
    @Transactional
    public void deactivate(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        if("DEACTIVATED".equals(member.getAccountStatus())){
            throw new ApiException("This account is already deactivated");
        }
        if(!penaltyRepository.findPenaltiesByMemberAndStatus(member, "PENDING").isEmpty()){
            throw new ApiException("Pay the donations you owe first, then you can deactivate the account");
        }
        member.setDeactivationRequestedAt(LocalDateTime.now());

        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByMemberIdAndStatus(memberId, "ACTIVE")){
            groupMemberService.leaveBecauseDeactivated(groupMember);
        }
        for(Commitment commitment : commitmentRepository.findCommitmentsByMemberAndStatus(member, "ACTIVE")){
            commitment.setStatus("WITHDRAWN");
            commitmentRepository.save(commitment);
        }

        member.setAccountStatus("DEACTIVATED");
        member.setDeactivatedAt(LocalDateTime.now());
        member.setIsLocked(false);
        memberRepository.save(member);
    }

    // admin: gives the account back after a ban (the group ban stays)
    public void unban(Integer adminId, Integer memberId){
        Admin admin = adminRepository.findAdminById(adminId);
        if(admin == null){
            throw new ApiException("Admin not found");
        }
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        if(!Boolean.TRUE.equals(member.getAccountBanned())){
            throw new ApiException("This account is not banned");
        }
        member.setAccountBanned(false);
        memberRepository.save(member);
    }
}
