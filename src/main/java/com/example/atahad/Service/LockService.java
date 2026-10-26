package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.DonationProofRepository;
import com.example.atahad.Repository.ExcuseRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.PenaltyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

// who can use the app:
// LOCKED: has a penalty not paid -> only "I donated" (donation proof) and "I have an excuse" (excuse, objection)
//         an excuse waiting for a decision (the AI or the admin) or a donation waiting for the admin opens the app for now,
//         a rejected excuse locks it again if something is still owed (he can object or send another excuse in the week)
// BANNED (3rd refusal to pay a group donation): nothing, except paying what he owes
// DEACTIVATED: nothing
@Service
@RequiredArgsConstructor
public class LockService {
    private final PenaltyRepository penaltyRepository;
    private final ExcuseRepository excuseRepository;
    private final DonationProofRepository donationProofRepository;
    private final MemberRepository memberRepository;

    public static final String LOCKED_MESSAGE = "Your app is locked: donate the penalty to Ehsan and press I donated, or send an excuse";

    // the lock is always calculated again from the data, never set by hand
    public void refresh(Member member){
        boolean hasPending = !penaltyRepository.findPenaltiesByMemberAndStatus(member, "PENDING").isEmpty();
        member.setIsLocked(hasPending && !hasOpenEscalation(member));
        memberRepository.save(member);
    }

    public boolean hasOpenEscalation(Member member){
        return !excuseRepository.findExcusesByCommitmentWeekCommitmentMemberIdAndStatus(member.getId(), "ESCALATED").isEmpty()
                || !excuseRepository.findExcusesByCommitmentWeekCommitmentMemberIdAndStatus(member.getId(), "PENDING").isEmpty()
                || !donationProofRepository.findDonationProofsByMemberIdAndStatus(member.getId(), "ESCALATED").isEmpty();
    }

    // for the actions of a normal member (add a proof, a habit, join a group ...)
    public void checkCanAct(Member member){
        String reason = blockReason(member, "POST", "");
        if(reason != null){
            throw new ApiException(reason);
        }
    }

    // null = allowed, used by the LockInterceptor for every request that has a member id in its path
    public String blockReason(Member member, String method, String path){
        if("DEACTIVATED".equals(member.getAccountStatus())){
            return "This account is deactivated";
        }
        if(Boolean.TRUE.equals(member.getAccountBanned())){
            boolean paying = path.startsWith("/api/v1/donation-proof")
                    || path.startsWith("/api/v1/commitment/lockStatus")
                    || path.startsWith("/api/v1/penalty/my");
            return paying ? null : "This account is banned because group donations were not paid, you can only pay what you owe";
        }
        if(Boolean.TRUE.equals(member.getIsLocked())){
            if("GET".equalsIgnoreCase(method)){
                return null; // he can still look at his data
            }
            boolean allowed = path.startsWith("/api/v1/donation-proof")
                    || path.startsWith("/api/v1/excuse")
                    || path.startsWith("/api/v1/objection");
            return allowed ? null : LOCKED_MESSAGE;
        }
        return null;
    }
}
