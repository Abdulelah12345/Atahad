package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.ReviewItemResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

// what the AI sent to the admin: ESCALATED proofs, excuses, donation proofs, and PENDING objections
@Service
@RequiredArgsConstructor
public class AdminReviewService {
    private final AdminRepository adminRepository;
    private final ProofRepository proofRepository;
    private final ExcuseRepository excuseRepository;
    private final ObjectionRepository objectionRepository;
    private final ProofDecisionService proofDecisionService;
    private final ExcuseDecisionService excuseDecisionService;
    private final ObjectionDecisionService objectionDecisionService;
    private final DonationProofService donationProofService;

    // oldest first, so nobody waits too long
    public List<ReviewItemResponse> getQueue(Integer adminId){
        getAdmin(adminId);
        List<ReviewItemResponse> list = new ArrayList<>();
        for(Proof proof : proofDecisionService.getEscalated()){
            Member member = proof.getCommitmentWeek().getCommitment().getMember();
            list.add(new ReviewItemResponse("PROOF", proof.getId(), member.getId(), name(member), title(proof.getCommitmentWeek(), proof.getGoalTask()),
                    proof.getType() + " at " + proof.getActivityTime(), List.of(proof.getEvidenceData()), proof.getRejectionReason(), proof.getSubmittedAt()));
        }
        for(Excuse excuse : excuseDecisionService.getEscalated()){
            Member member = excuse.getCommitmentWeek().getCommitment().getMember();
            list.add(new ReviewItemResponse("EXCUSE", excuse.getId(), member.getId(), name(member), title(excuse.getCommitmentWeek(), excuse.getGoalTask()),
                    excuse.getType() + " on " + excuse.getExcuseDate(), excuse.getEvidenceUrl() == null ? List.of() : List.of(excuse.getEvidenceUrl()),
                    excuse.getAiAssessment(), excuse.getDecidedAt()));
        }
        for(Objection objection : objectionDecisionService.getWaitingForAdmin()){
            Member member = objection.getMember();
            String about = objection.getProof() != null ? "Objection on proof " + objection.getProof().getId()
                    : objection.getExcuse() != null ? "Objection on excuse " + objection.getExcuse().getId()
                    : "Objection on donation proof " + objection.getDonationProof().getId();
            list.add(new ReviewItemResponse("OBJECTION", objection.getId(), member.getId(), name(member), about,
                    objection.getReason(), List.of(), objection.getAiReason(), objection.getCreatedAt()));
        }
        for(DonationProof proof : donationProofService.getEscalated()){
            Member member = proof.getMember();
            List<String> evidence = new ArrayList<>();
            if(proof.getBankMessageImageUrl() != null){
                evidence.add(proof.getBankMessageImageUrl());
                evidence.add(proof.getEhsanMessageImageUrl());
            }
            list.add(new ReviewItemResponse("DONATION", proof.getId(), member.getId(), name(member),
                    proof.getAmount() + " SAR to " + proof.getRecipient(),
                    proof.getMethod() + ", " + proof.getBankName() + ", ref " + proof.getTransactionReference() + ", at " + proof.getTransactionTime()
                            + (proof.getDkimDomain() == null ? "" : ", signed by " + proof.getDkimDomain()),
                    evidence, proof.getAiResult(), proof.getCreatedAt()));
        }
        list.sort(Comparator.comparing(item -> item.getCreatedAt() == null ? LocalDateTime.MIN : item.getCreatedAt()));
        return list;
    }

    // kind: PROOF, EXCUSE, OBJECTION or DONATION. Rejecting a donation screenshot = it was fake
    @Transactional
    public void decide(Integer adminId, String kind, Integer id, boolean accept, String note){
        Admin admin = getAdmin(adminId);
        switch(kind == null ? "" : kind.toUpperCase()){
            case "PROOF" -> {
                Proof proof = proofRepository.findProofById(id);
                if(proof == null || !"ESCALATED".equals(proof.getResult())){
                    throw new ApiException("Proof not found in the admin list");
                }
                proofDecisionService.applyDecision(proof, accept ? "ACCEPTED" : "REJECTED", note);
            }
            case "EXCUSE" -> {
                Excuse excuse = excuseRepository.findExcuseById(id);
                if(excuse == null || !"ESCALATED".equals(excuse.getStatus())){
                    throw new ApiException("Excuse not found in the admin list");
                }
                excuseDecisionService.applyDecision(excuse, accept ? "ACCEPTED" : "REJECTED", note, admin);
            }
            case "OBJECTION" -> {
                Objection objection = objectionRepository.findObjectionById(id);
                if(objection == null){
                    throw new ApiException("Objection not found");
                }
                objectionDecisionService.apply(objection, accept, admin);
            }
            case "DONATION" -> donationProofService.review(admin, donationProofService.getProof(id), accept, note);
            default -> throw new ApiException("Kind must be PROOF, EXCUSE, OBJECTION or DONATION");
        }
        admin.setReviewedCount((admin.getReviewedCount() == null ? 0 : admin.getReviewedCount()) + 1);
        adminRepository.save(admin);
    }

    private Admin getAdmin(Integer adminId){
        Admin admin = adminRepository.findAdminById(adminId);
        if(admin == null){
            throw new ApiException("Admin not found");
        }
        return admin;
    }

    private String name(Member member){
        return member.getUser() == null ? "Member " + member.getId() : member.getUser().getName();
    }

    private String title(CommitmentWeek week, GoalTask task){
        String title = week.getCommitment().getTitle();
        return task == null ? title : title + " - " + task.getTitle();
    }
}
