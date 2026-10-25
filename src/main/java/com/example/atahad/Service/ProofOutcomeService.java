package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityManager;
import java.time.*;
import java.util.List;

@Service @RequiredArgsConstructor
public class ProofOutcomeService {
    private final ProofEvidenceRepository evidenceRepository;
    private final ProofRepository proofRepository;
    private final AcceptanceGuardService acceptanceGuardService;
    private final CommitmentWeekService commitmentWeekService;
    private final EntityManager entityManager;

    @Transactional
    public void primary(Proof proof, String decision, String reason) {
        record(proof, proof.getType(), decision, reason);
    }

    @Transactional
    public void record(Proof proof, String type, String decision, String reason) {
        if (!List.of("PENDING","ACCEPTED","REJECTED","ESCALATED").contains(decision)) {
            throw new ApiException("Invalid evidence decision");
        }
        String submittedData = proof.getEvidenceData();
        Integer submittedCapture = proof.getPrimaryCaptureId();
        if (!entityManager.contains(proof)) { proof=entityManager.find(Proof.class,proof.getId()); }
        // نسلسل تحديث أدلة المحاولة نفسها قبل تجميع القرار النهائي.
        entityManager.lock(proof.getCommitmentWeek(), jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        entityManager.lock(proof, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        entityManager.refresh(proof, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        ProofEvidence evidence = null;
        for (ProofEvidence item : evidenceRepository.findForDecision(proof.getId())) {
            entityManager.refresh(item, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
            if (item.getType().equals(type)) { evidence = item; }
        }
        if (evidence == null) {
            evidence = new ProofEvidence(); evidence.setProof(proof); evidence.setType(type); evidence.setCreatedAt(now());
        }
        // نجاح الدليل لا يسحب بسبب إعادة طلب أو فشل دليل إضافي لاحق.
        if (evidence.getResult().equals("ACCEPTED")) { return; }
        if (type.equals(proof.getType())) {
            proof.setEvidenceData(submittedData);
            proof.setPrimaryCaptureId(submittedCapture);
            evidence.setData(submittedData);
        }
        evidence.setResult(decision);
        evidence.setReason(reason == null ? null : reason.substring(0, Math.min(1000,reason.length())));
        if (!decision.equals("PENDING")) { evidence.setDecidedAt(now()); }
        evidenceRepository.saveAndFlush(evidence);
        recompute(proof);
    }

    @Transactional
    public void recompute(Proof proof) {
        entityManager.lock(proof.getCommitmentWeek(), jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        entityManager.lock(proof, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        entityManager.refresh(proof, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        List<ProofEvidence> evidence = evidenceRepository.findForDecision(proof.getId());
        for (ProofEvidence item : evidence) { entityManager.refresh(item, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE); }
        boolean accepted = false;
        boolean pending = false;
        boolean escalated = false;
        for (ProofEvidence item : evidence) {
            if (item.getResult().equals("ACCEPTED")) { accepted = true; }
            if (item.getResult().equals("PENDING")) { pending = true; }
            if (item.getResult().equals("ESCALATED")) { escalated = true; }
        }
        if (proof.getResult().equals("ACCEPTED")) { return; }
        String result = "REJECTED";
        if (escalated) { result = "ESCALATED"; }
        if (pending) { result = "PENDING"; }
        if (accepted) { result = "ACCEPTED"; }
        if (result.equals("ACCEPTED")) {
            Integer taskId = proof.getGoalTask() == null ? null : proof.getGoalTask().getId();
            acceptanceGuardService.lockAndCheck(proof.getCommitmentWeek().getId(), taskId,
                    proof.getActivityTime().toLocalDate(), proof.getId(), null);
            // القفل يحدث نسخة البروف؛ نعيد الفحص قبل زيادة العداد.
            if (proof.getResult().equals("ACCEPTED")) { return; }
            proof.setResult("ACCEPTED"); proof.setProcessingStatus("FINISHED"); proof.setDecidedAt(now()); proof.setRejectionReason(null);
            proofRepository.saveAndFlush(proof);
            commitmentWeekService.recordCompletion(proof.getCommitmentWeek().getId(),taskId);
            return;
        }
        proof.setResult(result);
        proof.setProcessingStatus(pending ? "WAITING" : "FINISHED");
        if (!pending) { proof.setDecidedAt(now()); }
        if (result.equals("REJECTED") || result.equals("ESCALATED")) {
            proof.setRejectionReason("راجع نتائج الأدلة المرفقة بهذه المحاولة");
        }
        proofRepository.save(proof);
    }

    @Transactional
    public void review(Proof proof, boolean accepted, String reason) {
        List<ProofEvidence> evidence = evidenceRepository.findByProofIdOrderById(proof.getId());
        if (evidence.isEmpty()) { primary(proof, accepted ? "ACCEPTED" : "REJECTED", reason); return; }
        for (ProofEvidence item : evidence) {
            if (item.getResult().equals("ESCALATED")) {
                item.setResult(accepted ? "ACCEPTED" : "REJECTED"); item.setReason(reason); item.setDecidedAt(now()); evidenceRepository.save(item);
            }
        }
        evidenceRepository.flush(); recompute(proof);
    }
    private LocalDateTime now() { return LocalDateTime.now(ZoneId.of("Asia/Riyadh")); }
}
