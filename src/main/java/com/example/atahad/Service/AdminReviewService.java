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
    private final AuthenticatedUserService authenticatedUserService;
    private final ProofAttachmentService proofAttachmentService;
    private final AdminRepository adminRepository;
    private final PenaltyRepository penaltyRepository;
    private final ProofRepository proofRepository;
    private final ProofEvidenceRepository proofEvidenceRepository;
    private final ProofCaptureRepository proofCaptureRepository;
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
                    proofDetails(proof), proofImages(proof), proof.getRejectionReason(), proof.getSubmittedAt()));
        }
        for(Excuse excuse : excuseDecisionService.getEscalated()){
            Member member = excuse.getCommitmentWeek().getCommitment().getMember();
            list.add(new ReviewItemResponse("EXCUSE", excuse.getId(), member.getId(), name(member), title(excuse.getCommitmentWeek(), excuse.getGoalTask()),
                    excuse.getType() + " on " + excuse.getExcuseDate(), excuse.getEvidenceUrl() == null ? List.of() : List.of(proofAttachmentService.resolve(member.getId(), excuse.getEvidenceUrl())),
                    excuse.getAiAssessment(), excuse.getDecidedAt()));
        }
        for(Objection objection : objectionDecisionService.getWaitingForAdmin()){
            Member member = objection.getMember();
            // يظهر للأدمن النشاط وصوره الأصلية مع سبب الاعتراض، حتى يستطيع مراجعة القرار.
            String about;
            List<String> images = new ArrayList<>();
            if (objection.getProof() != null) {
                Proof proof = objection.getProof();
                about = title(proof.getCommitmentWeek(), proof.getGoalTask());
                images.addAll(proofImages(proof));
            } else if (objection.getExcuse() != null) {
                Excuse excuse = objection.getExcuse();
                about = title(excuse.getCommitmentWeek(), excuse.getGoalTask());
                if (excuse.getEvidenceUrl() != null) {
                    images.add(proofAttachmentService.resolve(member.getId(), excuse.getEvidenceUrl()));
                }
            } else {
                DonationProof proof = objection.getDonationProof();
                about = "إثبات التبرع";
                if (proof.getBankMessageImageUrl() != null) {
                    images.add(proofAttachmentService.resolve(member.getId(), proof.getBankMessageImageUrl()));
                }
                if (proof.getEhsanMessageImageUrl() != null) {
                    images.add(proofAttachmentService.resolve(member.getId(), proof.getEhsanMessageImageUrl()));
                }
            }
            list.add(new ReviewItemResponse("OBJECTION", objection.getId(), member.getId(), name(member), about,
                    objection.getReason(), images, objection.getAiReason(), objection.getCreatedAt()));
        }
        for(DonationProof proof : donationProofService.getEscalated()){
            Member member = proof.getMember();
            List<String> evidence = new ArrayList<>();
            if(proof.getBankMessageImageUrl() != null){
                evidence.add(proofAttachmentService.resolve(member.getId(), proof.getBankMessageImageUrl()));
                evidence.add(proofAttachmentService.resolve(member.getId(), proof.getEhsanMessageImageUrl()));
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
                proofDecisionService.reviewDecision(proof, accept, note);
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

    // نعرض للأدمن نتيجة كل دليل والصور المرتبطة به، ليتمكن من مراجعة المحاولة كاملة.
    private String proofDetails(Proof proof) {
        StringBuilder details = new StringBuilder(proof.getType() + " at " + proof.getActivityTime());
        if("STEPS".equals(proof.getType())) { details.append("\n").append(proof.getEvidenceData()); }
        for (ProofEvidence item : proofEvidenceRepository.findByProofIdOrderById(proof.getId())) {
            details.append("\n").append(item.getType()).append(": ").append(item.getResult());
            if (item.getReason() != null) { details.append(" - ").append(item.getReason()); }
        }
        return details.toString();
    }
    private List<String> proofImages(Proof proof) {
        List<String> images = new ArrayList<>();
        if (proof.getEvidenceData() != null && !"STEPS".equals(proof.getType())) { images.add(proof.getEvidenceData()); }
        for (ProofEvidence item : proofEvidenceRepository.findByProofIdOrderById(proof.getId())) {
            if("STEP_SCREENSHOT".equals(item.getType()) && item.getData()!=null) { images.add(item.getData()); }
            for (Integer captureId : new Integer[]{item.getBeforeCaptureId(), item.getAfterCaptureId()}) {
                if (captureId != null) {
                    ProofCapture capture = proofCaptureRepository.findById(captureId).orElse(null);
                    if (capture != null && capture.getImageData() != null) { images.add(capture.getImageData()); }
                }
            }
        }
        return images;
    }
    @Transactional(readOnly = true)
    public List<java.util.Map<String, Object>> getPenaltyWorkspace(Integer adminId) {
        getAdmin(adminId);
        List<java.util.Map<String, Object>> result = new ArrayList<>();
        for (Penalty penalty : penaltyRepository.findAll()) {
            java.util.Map<String, Object> item = new java.util.LinkedHashMap<>();
            item.put("id", penalty.getId()); item.put("amount", penalty.getAmount());
            item.put("status", penalty.getStatus()); item.put("createdAt", penalty.getCreatedAt());
            item.put("memberName", name(penalty.getMember()));
            item.put("title", penalty.getCommitmentWeek() == null ? "التزام جماعي" : title(penalty.getCommitmentWeek(), penalty.getGoalTask()));
            result.add(item);
        }
        return result;
    }

    // بداية مراجعة الاعتراض تقفل تعديل السبب وحذفه عند العضو، دون إصدار قرار بالنيابة عن الأدمن.
    @Transactional
    public void startObjectionReview(Integer adminId, Integer objectionId) {
        getAdmin(adminId);
        Objection objection = objectionRepository.findObjectionById(objectionId);
        if (objection == null) { throw new ApiException("Objection not found"); }
        if (!"PENDING".equals(objection.getStatus())) { throw new ApiException("Only pending objections can be reviewed"); }
        if (objection.getReviewStartedAt() == null) {
            objection.setReviewStartedAt(LocalDateTime.now(java.time.ZoneId.of("Asia/Riyadh")));
            objectionRepository.save(objection);
        }
    }

    private Admin getAdmin(Integer adminId){
        authenticatedUserService.checkAdmin(adminId);
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
