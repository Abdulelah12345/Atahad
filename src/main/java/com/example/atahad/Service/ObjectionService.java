package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Objection;
import com.example.atahad.Repository.ObjectionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import com.example.atahad.Dto.In.ObjectionRequest;
import com.example.atahad.Entity.Proof;
import com.example.atahad.Entity.Excuse;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Repository.ProofRepository;
import com.example.atahad.Repository.ExcuseRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ObjectionService {

    private final ObjectionRepository objectionRepository;
    private final ProofRepository proofRepository;
    private final ExcuseRepository excuseRepository;
    private final ObjectionDecisionService objectionDecisionService;

    public List<Objection> getAllObjections() {
        return objectionRepository.findAll();
    }

    public Objection getObjectionById(Integer userId, Integer objectionId) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (objectionId == null) {
            throw new ApiException("Objection ID is required");
        }

        Objection objection =
                objectionRepository.findObjectionById(objectionId);

        if (objection == null) {
            throw new ApiException("Objection not found");
        }

        Member member = objection.getMember();

        if (member == null) {
            throw new ApiException("Objection owner not found");
        }

        if (member.getUser() == null) {
            throw new ApiException("Objection owner user not found");
        }

        // only its owner
        Integer ownerUserId = member.getUser().getId();

        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This objection does not belong to you");
        }

        return objection;
    }

    public void addProofObjection(Integer userId, Integer proofId,
                                      ObjectionRequest request) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        if (proofId == null) {
            throw new ApiException("Proof ID is required");
        }
        if (request == null) {
            throw new ApiException("Objection data is required");
        }

        String reason = request.getReason();
        if (reason == null) {
            throw new ApiException("Reason is required");
        }
        if (reason.isBlank()) {
            throw new ApiException("Reason cannot be empty");
        }
        if (reason.length() > 1000) {
            throw new ApiException("Reason must be 1000 characters max");
        }

        Proof proof = proofRepository.findProofById(proofId);
        if (proof == null) {
            throw new ApiException("Proof not found");
        }

        // the owner through the week, works for goals and habits
        CommitmentWeek week = proof.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }
        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Commitment not found");
        }
        Member member = commitment.getMember();
        if (member == null) {
            throw new ApiException("Commitment owner not found");
        }
        if (member.getUser() == null) {
            throw new ApiException("Commitment owner user not found");
        }

        Integer ownerUserId = member.getUser().getId();
        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This proof does not belong to you");
        }

        // only after the AI decided
        if (!"FINISHED".equals(proof.getProcessingStatus())) {
            throw new ApiException("Proof analysis has not finished");
        }
        String status = proof.getResult();

        if (status == null) {
            throw new ApiException("Decision status is missing");
        }
        boolean hasDecision = status.equals("REJECTED");
        if (!hasDecision) {
            throw new ApiException("Only rejected decisions can be objected to");
        }

        // 48 hours from the decision, not from sending
        LocalDateTime decidedAt = proof.getDecidedAt();
        if (decidedAt == null) {
            throw new ApiException("Decision time is missing");
        }
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (decidedAt.isAfter(now)) {
            throw new ApiException("Decision time is invalid");
        }
        LocalDateTime objectionDeadline = decidedAt.plusHours(48);
        if (now.isAfter(objectionDeadline)) {
            throw new ApiException("The 48-hour objection period has ended");
        }

        // one objection per decision
        if (proof.getObjection() != null) {
            throw new ApiException("An objection already exists for this proof");
        }

        // task null = a habit
        GoalTask task = proof.getGoalTask();
        Integer goalTaskId = null;
        if (task != null) {
            if (task.getGoal() == null) {
                throw new ApiException("Goal task must belong to a goal");
            }
            if (!task.getGoal().getId().equals(commitment.getId())) {
                throw new ApiException("Goal task does not belong to this commitment");
            }
            if (task.getWeekNumber() == null || week.getWeekNumber() == null) {
                throw new ApiException("Week number is missing");
            }
            if (!task.getWeekNumber().equals(week.getWeekNumber())) {
                throw new ApiException("Goal task does not belong to this week");
            }
            goalTaskId = task.getId();
        }

        LocalDateTime activityTime = proof.getActivityTime();
        if (activityTime == null) {
            throw new ApiException("Proof activity time is missing");
        }
        LocalDate activityDate = activityTime.toLocalDate();
        LocalDateTime dayStart = activityDate.atStartOfDay();
        LocalDateTime nextDayStart = activityDate.plusDays(1).atStartOfDay();
        Integer weekId = week.getId();

        // not while another proof of that day is waiting or accepted
        boolean hasBlockingProof = objectionRepository.existsBlockingProof(
                weekId, goalTaskId, dayStart, nextDayStart);
        if (hasBlockingProof) {
            throw new ApiException("This day already has a pending or accepted proof");
        }

        // or an excuse of that day
        boolean hasBlockingExcuse = objectionRepository.existsBlockingExcuse(
                weekId, goalTaskId, activityDate);
        if (hasBlockingExcuse) {
            throw new ApiException("This day already has an active or accepted excuse");
        }

        // or another open objection
        boolean hasPendingProofObjection =
                objectionRepository.existsPendingProofObjection(
                        weekId,
                        goalTaskId,
                        dayStart,
                        nextDayStart
                );

        if (hasPendingProofObjection) {
            throw new ApiException("A proof objection for this day is still pending");
        }

        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingExcuseObjection(
                        weekId,
                        goalTaskId,
                        activityDate
                );

        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        String aiReason = proof.getRejectionReason();

        Objection objection = new Objection();
        objection.setReason(reason);
        objection.setAiReason(aiReason);
        objection.setCreatedAt(now);
        objection.setStatus("PENDING");
        objection.setMember(member);
        objection.setProof(proof);
        objection.setExcuse(null);
        objection.setDonationProof(null);
        objection.setAdmin(null);

        objectionRepository.save(objection);

        // the AI decides, unsure = stays PENDING for the admin
        objectionDecisionService.decide(objection);
    }

    public void addExcuseObjection(Integer userId, Integer excuseId,
                                      ObjectionRequest request) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }
        if (request == null) {
            throw new ApiException("Objection data is required");
        }

        String reason = request.getReason();
        if (reason == null) {
            throw new ApiException("Reason is required");
        }
        if (reason.isBlank()) {
            throw new ApiException("Reason cannot be empty");
        }
        if (reason.length() > 1000) {
            throw new ApiException("Reason must be 1000 characters max");
        }

        Excuse excuse = excuseRepository.findExcuseById(excuseId);
        if (excuse == null) {
            throw new ApiException("Excuse not found");
        }

        // the owner through the week, works for goals and habits
        CommitmentWeek week = excuse.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }
        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Commitment not found");
        }
        Member member = commitment.getMember();
        if (member == null) {
            throw new ApiException("Commitment owner not found");
        }
        if (member.getUser() == null) {
            throw new ApiException("Commitment owner user not found");
        }

        Integer ownerUserId = member.getUser().getId();
        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This excuse does not belong to you");
        }

        // not on an admin's decision
        if (excuse.getAdmin() != null) {
            throw new ApiException("This excuse was reviewed by an admin");
        }
        if (Boolean.TRUE.equals(excuse.getForwardedToAdmin())) {
            throw new ApiException("This excuse is assigned to admin review");
        }
        String status = excuse.getStatus();

        if (status == null) {
            throw new ApiException("Decision status is missing");
        }
        boolean hasDecision = status.equals("REJECTED");
        if (!hasDecision) {
            throw new ApiException("Only rejected decisions can be objected to");
        }

        // 48 hours from the decision, not from sending
        LocalDateTime decidedAt = excuse.getDecidedAt();
        if (decidedAt == null) {
            throw new ApiException("Decision time is missing");
        }
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (decidedAt.isAfter(now)) {
            throw new ApiException("Decision time is invalid");
        }
        LocalDateTime objectionDeadline = decidedAt.plusHours(48);
        if (now.isAfter(objectionDeadline)) {
            throw new ApiException("The 48-hour objection period has ended");
        }

        // one objection per decision
        if (excuse.getObjection() != null) {
            throw new ApiException("An objection already exists for this excuse");
        }

        // task null = a habit
        GoalTask task = excuse.getGoalTask();
        Integer goalTaskId = null;
        if (task != null) {
            if (task.getGoal() == null) {
                throw new ApiException("Goal task must belong to a goal");
            }
            if (!task.getGoal().getId().equals(commitment.getId())) {
                throw new ApiException("Goal task does not belong to this commitment");
            }
            if (task.getWeekNumber() == null || week.getWeekNumber() == null) {
                throw new ApiException("Week number is missing");
            }
            if (!task.getWeekNumber().equals(week.getWeekNumber())) {
                throw new ApiException("Goal task does not belong to this week");
            }
            goalTaskId = task.getId();
        }

        LocalDate activityDate = excuse.getExcuseDate();
        if (activityDate == null) {
            throw new ApiException("Excuse date is missing");
        }
        LocalDateTime dayStart = activityDate.atStartOfDay();
        LocalDateTime nextDayStart = activityDate.plusDays(1).atStartOfDay();
        Integer weekId = week.getId();

        // not while another proof of that day is waiting or accepted
        boolean hasBlockingProof = objectionRepository.existsBlockingProof(
                weekId, goalTaskId, dayStart, nextDayStart);
        if (hasBlockingProof) {
            throw new ApiException("This day already has a pending or accepted proof");
        }

        // or an excuse of that day
        boolean hasBlockingExcuse = objectionRepository.existsBlockingExcuse(
                weekId, goalTaskId, activityDate);
        if (hasBlockingExcuse) {
            throw new ApiException("This day already has an active or accepted excuse");
        }

        // or another open objection
        boolean hasPendingProofObjection =
                objectionRepository.existsPendingProofObjection(
                        weekId,
                        goalTaskId,
                        dayStart,
                        nextDayStart
                );

        if (hasPendingProofObjection) {
            throw new ApiException("A proof objection for this day is still pending");
        }

        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingExcuseObjection(
                        weekId,
                        goalTaskId,
                        activityDate
                );

        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        String aiReason = excuse.getAiAssessment();

        Objection objection = new Objection();
        objection.setReason(reason);
        objection.setAiReason(aiReason);
        objection.setCreatedAt(now);
        objection.setStatus("PENDING");
        objection.setMember(member);
        objection.setExcuse(excuse);
        objection.setProof(null);
        objection.setDonationProof(null);
        objection.setAdmin(null);

        objectionRepository.save(objection);

        // the AI decides, unsure = stays PENDING for the admin
        objectionDecisionService.decide(objection);
    }

    // the owner edits the reason while it waits and the admin did not start
    public void updateObjection(Integer userId,
                                Integer objectionId,
                                ObjectionRequest request) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (objectionId == null) {
            throw new ApiException("Objection ID is required");
        }

        if (request == null) {
            throw new ApiException("Objection update data is required");
        }

        Objection objection =
                objectionRepository.findObjectionById(objectionId);

        if (objection == null) {
            throw new ApiException("Objection not found");
        }

        Member member = objection.getMember();

        if (member == null) {
            throw new ApiException("Objection owner not found");
        }

        if (member.getUser() == null) {
            throw new ApiException("Objection owner user not found");
        }

        Integer ownerUserId = member.getUser().getId();

        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This objection does not belong to you");
        }

        if (!"PENDING".equals(objection.getStatus())) {
            throw new ApiException("Only pending objections can be updated");
        }

        // the admin started = locked, even if still PENDING
        if (objection.getReviewStartedAt() != null) {
            throw new ApiException("This objection is already under review");
        }

        String reason = request.getReason();

        if (reason == null) {
            throw new ApiException("Reason is required");
        }

        if (reason.isBlank()) {
            throw new ApiException("Reason cannot be empty");
        }

        if (reason.length() > 1000) {
            throw new ApiException("Reason must be 1000 characters max");
        }

        // the 48 hours are for sending only
        objection.setReason(reason);

        objectionRepository.save(objection);
    }

    // the owner deletes it before the admin starts
    public void deleteObjection(Integer userId, Integer objectionId) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (objectionId == null) {
            throw new ApiException("Objection ID is required");
        }

        Objection objection =
                objectionRepository.findObjectionById(objectionId);

        if (objection == null) {
            throw new ApiException("Objection not found");
        }

        Member member = objection.getMember();

        if (member == null) {
            throw new ApiException("Objection owner not found");
        }

        if (member.getUser() == null) {
            throw new ApiException("Objection owner user not found");
        }

        // only its owner
        Integer ownerUserId = member.getUser().getId();

        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This objection does not belong to you");
        }

        String status = objection.getStatus();

        if (status == null) {
            throw new ApiException("Objection status is missing");
        }

        boolean isPending = status.equals("PENDING");

        if (!isPending) {
            throw new ApiException("Only pending objections can be deleted");
        }

        if (objection.getReviewStartedAt() != null) {
            throw new ApiException("An objection under review cannot be deleted");
        }

        /*
         لا نعيد فحص مهلة 48 ساعة عند الحذف.
         إعادة التقديم تخضع لمهلة القرار الأصلي في ميثود الإضافة.
         نحذف الاعتراض فقط، دون حذف البروف أو العذر أو تغيير القرار والعداد والمبلغ.
        */
        objectionRepository.delete(objection);
    }

}