package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class ProofWorkspaceService {
    private final AuthenticatedUserService authenticatedUserService;
    private final ProofRepository proofRepository;
    private final PlaceVisitRepository placeVisitRepository;
    private final ExcuseRepository excuseRepository;
    private final ObjectionRepository objectionRepository;

    // نأخذ المستخدم من جلسة الدخول ونبحث عن سجلاته فقط، دون إظهار سجلات بقية الأعضاء.
    @Transactional(readOnly = true)
    public Map<String, Object> getMyWorkspace(Integer userId) {
        authenticatedUserService.checkMember(userId);
        List<Map<String, Object>> proofs = new ArrayList<>();
        List<Map<String, Object>> excuses = new ArrayList<>();
        List<Map<String, Object>> objections = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));

        for (Proof proof : proofRepository.findAllProofsByUserId(userId)) {
            Map<String, Object> item = activity(proof.getCommitmentWeek(), proof.getGoalTask());
            item.put("id", proof.getId());
            item.put("type", proof.getType());
            item.put("status", proof.getResult());
            item.put("processingStatus", proof.getProcessingStatus());
            item.put("activityTime", proof.getActivityTime());
            item.put("createdAt", proof.getSubmittedAt());
            item.put("decidedAt", proof.getDecidedAt());
            item.put("reason", proof.getRejectionReason());
            item.put("managed", proof.getAttemptDeadline() != null);
            item.put("canObject", canObject(proof.getResult(), proof.getDecidedAt(), proof.getObjection(), now));
            boolean canEdit = proof.getAttemptDeadline() == null && proof.getGoalTask() != null
                    && "WAITING".equals(proof.getProcessingStatus()) && "PENDING".equals(proof.getResult());
            item.put("canEdit", canEdit);
            item.put("canDelete", canEdit);
            proofs.add(item);
        }
        for (Excuse excuse : excuseRepository.findByCommitmentWeekCommitmentMemberIdOrderByIdDesc(userId)) {
            Map<String, Object> item = activity(excuse.getCommitmentWeek(), excuse.getGoalTask());
            item.put("id", excuse.getId());
            item.put("type", excuse.getType());
            item.put("status", excuse.getStatus());
            item.put("processingStatus", excuse.getProcessingStatus());
            item.put("activityTime", excuse.getExcuseDate());
            item.put("reason", excuse.getAiAssessment());
            item.put("decidedAt", excuse.getDecidedAt());
            item.put("evidenceUrl", excuse.getEvidenceUrl());
            item.put("canObject", canObject(excuse.getStatus(), excuse.getDecidedAt(), excuse.getObjection(), now));
            boolean waiting = "WAITING".equals(excuse.getProcessingStatus()) && "PENDING".equals(excuse.getStatus());
            boolean forwarded = excuse.getForwardedToAdmin() != null && excuse.getForwardedToAdmin();
            boolean editable = waiting && !forwarded && excuse.getGoalTask() != null;
            item.put("canEdit", editable);
            item.put("canDelete", editable);
            excuses.add(item);
        }
        for (Objection objection : objectionRepository.findByMemberIdOrderByIdDesc(userId)) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", objection.getId());
            item.put("status", objection.getStatus());
            item.put("reason", objection.getReason());
            item.put("aiReason", objection.getAiReason());
            item.put("createdAt", objection.getCreatedAt());
            item.put("reviewStartedAt", objection.getReviewStartedAt());
            boolean editable = "PENDING".equals(objection.getStatus()) && objection.getReviewStartedAt() == null;
            item.put("canEdit", editable);
            item.put("canDelete", editable);
            if (objection.getProof() != null) {
                Proof proof = objection.getProof();
                item.put("kind", "PROOF");
                item.put("title", title(proof.getCommitmentWeek(), proof.getGoalTask()));
            } else if (objection.getExcuse() != null) {
                Excuse excuse = objection.getExcuse();
                item.put("kind", "EXCUSE");
                item.put("title", title(excuse.getCommitmentWeek(), excuse.getGoalTask()));
            } else {
                item.put("kind", "DONATION");
                item.put("title", "إثبات التبرع");
            }
            objections.add(item);
        }
        List<Map<String, Object>> visits = new ArrayList<>();
        for (PlaceVisit visit : placeVisitRepository.findPlaceVisitsByMemberIdOrderByEnteredAtDesc(userId)) {
            Map<String, Object> item = activity(visit.getCommitmentWeek(), visit.getGoalTask());
            item.put("id", visit.getId()); item.put("status", visit.getStatus());
            item.put("enteredAt", visit.getEnteredAt()); item.put("exitedAt", visit.getExitedAt());
            item.put("minutes", visit.getMinutes()); item.put("proofId", visit.getProofId()); item.put("note", visit.getNote());
            visits.add(item);
        }
        return Map.of("proofs", proofs, "excuses", excuses, "objections", objections, "visits", visits);
    }

    private boolean canObject(String status, LocalDateTime decidedAt, Objection objection, LocalDateTime now) {
        if (!"REJECTED".equals(status) || decidedAt == null || objection != null) { return false; }
        return !now.isAfter(decidedAt.plusHours(48));
    }

    private Map<String, Object> activity(CommitmentWeek week, GoalTask task) {
        if (week == null) { throw new ApiException("Activity week is missing"); }
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("title", title(week, task));
        item.put("weekId", week.getId());
        item.put("goalTaskId", task == null ? null : task.getId());
        item.put("commitmentId", week.getCommitment().getId());
        item.put("weekStart", week.getWeekStart());
        item.put("weekEnd", week.getWeekEnd());
        return item;
    }

    private String title(CommitmentWeek week, GoalTask task) {
        if (task != null) { return task.getTitle(); }
        return week.getCommitment().getTitle();
    }
}
