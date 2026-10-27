package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Proof;
import com.example.atahad.Repository.ProofRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import com.example.atahad.Dto.In.ProofRequest;
import com.example.atahad.Dto.In.ProofUpdateRequest;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.ExcuseRepository;
import com.example.atahad.Repository.GoalTaskRepository;
import com.example.atahad.Repository.ObjectionRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ProofService {

    private final ProofRepository proofRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final ExcuseRepository excuseRepository;
    private final ObjectionRepository objectionRepository;
    private final ProofDecisionService proofDecisionService;
    private final LockService lockService;

    public List<Proof> getAllProofs() {
        return proofRepository.findAll();
    }

    public Proof getProofById(Integer userId, Integer id) {
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        Proof proof = proofRepository.findProofById(id);
        if (proof == null) {
            throw new ApiException("Proof not found");
        }
        // only the owner of the goal or habit
        Integer ownerId = proof.getCommitmentWeek().getCommitment().getMember().getUser().getId();
        if (!ownerId.equals(userId)) {
            throw new org.springframework.security.access.AccessDeniedException(
                    "You can only view your own proof");
        }
        return proof;
    }

    public List<Proof> getAllProofsByUserId(Integer userId) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        return proofRepository.findAllProofsByUserId(userId);
    }

    public void addGoalTaskProof(Integer userId, Integer goalTaskId, Integer commitmentWeekId, ProofRequest request) {
        createGoalTaskProof(userId, goalTaskId, commitmentWeekId, request, true);
    }

    public Proof prepareGoalTaskProof(Integer userId, Integer goalTaskId, Integer commitmentWeekId, ProofRequest request) {
        return createGoalTaskProof(userId, goalTaskId, commitmentWeekId, request, false);
    }

    private Proof createGoalTaskProof(Integer userId, Integer goalTaskId, Integer commitmentWeekId, ProofRequest request, boolean analyze) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        if (goalTaskId == null) {
            throw new ApiException("Goal task ID is required");
        }
        if (commitmentWeekId == null) {
            throw new ApiException("Commitment week ID is required");
        }
        if (request == null) {
            throw new ApiException("Proof data is required");
        }

        GoalTask task = goalTaskRepository.findGoalTaskById(goalTaskId);
        if (task == null) {
            throw new ApiException("Goal task not found");
        }

        CommitmentWeek week =
                commitmentWeekRepository.findCommitmentWeekById(commitmentWeekId);
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        Goal goal = task.getGoal();
        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        // the owner check comes first
        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal must belong to a member");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // a locked app takes no proofs, donate or send an excuse first
        lockService.checkCanAct(member);

        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }
        if (!goal.getId().equals(commitment.getId())) {
            throw new ApiException("Goal task does not belong to this goal");
        }

        Integer taskWeekNumber = task.getWeekNumber();
        Integer weekNumber = week.getWeekNumber();
        if (taskWeekNumber == null) {
            throw new ApiException("Goal task week number is missing");
        }
        if (weekNumber == null) {
            throw new ApiException("Commitment week number is missing");
        }
        if (!taskWeekNumber.equals(weekNumber)) {
            throw new ApiException("Goal task does not belong to this week");
        }

        // a withdrawn commitment takes no proofs
        if ("DRAFT".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a draft goal");
        }
        if ("WITHDRAWN".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a withdrawn goal");
        }
        // nor a settled week or task
        if ("SETTLED".equals(week.getTrackStatus())) {
            throw new ApiException("This week is settled");
        }
        if ("SETTLED".equals(task.getTrackStatus())) {
            throw new ApiException("This goal task is settled");
        }

        // the task's own method, not one picked now
        String proofMethod = task.getProofMethod();
        if (proofMethod == null) {
            throw new ApiException("Goal task proof method is missing");
        }
        if (!proofMethod.equals(request.getType())) {
            throw new ApiException("Proof type does not match the task method");
        }

        String evidenceData = request.getEvidenceData();
        if (evidenceData == null) {
            throw new ApiException("Evidence data is required");
        }
        if (evidenceData.isBlank()) {
            throw new ApiException("Evidence data cannot be empty");
        }

        LocalDateTime activityTime = request.getActivityTime();
        if (activityTime == null) {
            throw new ApiException("Activity time is required");
        }

        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (activityTime.isAfter(now)) {
            throw new ApiException("Activity time cannot be in the future");
        }

        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }
        // sent during the week, no extra time
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Proof submission time has ended");
        }
        // and the activity happened in it
        if (activityTime.isBefore(weekStart)) {
            throw new ApiException("Activity time is before this week");
        }
        if (activityTime.isAfter(weekEnd)) {
            throw new ApiException("Activity time is after this week");
        }

        LocalDate activityDate = activityTime.toLocalDate();
        // [day start, next day start)
        LocalDateTime dayStart = activityDate.atStartOfDay();
        LocalDateTime nextDayStart = activityDate.plusDays(1).atStartOfDay();

        // one accepted proof per task and day
        boolean hasAcceptedProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
        if (hasAcceptedProof) {
            throw new ApiException("This day already has an accepted proof");
        }

        // wait for the one being checked
        boolean hasPendingProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
        if (hasPendingProof) {
            throw new ApiException("A proof for this day is still pending");
        }
        boolean hasEscalatedProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ESCALATED");
        if (hasEscalatedProof) {
            throw new ApiException("A proof for this day is awaiting admin review");
        }

        boolean hasPendingProofObjection =
                objectionRepository.existsPendingTaskProofObjection(
                        goalTaskId, commitmentWeekId, dayStart, nextDayStart);
        if (hasPendingProofObjection) {
            throw new ApiException("A proof objection for this day is still pending");
        }

        // an excused day needs no proof
        boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, activityDate, "ACCEPTED");
        if (hasAcceptedExcuse) {
            throw new ApiException("This day already has an accepted excuse");
        }

        boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, activityDate, "PENDING");
        if (hasPendingExcuse) {
            throw new ApiException("An excuse for this day is still pending");
        }

        boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, activityDate, "ESCALATED");
        if (hasEscalatedExcuse) {
            throw new ApiException("An excuse for this day is awaiting admin review");
        }

        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingTaskExcuseObjection(
                        goalTaskId, commitmentWeekId, activityDate);
        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        Integer requiredCount = task.getTimesPerWeek();
        Integer completedCount = task.getCompletedCount();
        Integer excusedCount = task.getExcusedCount();
        if (requiredCount == null) {
            throw new ApiException("Task required count is missing");
        }
        if (requiredCount <= 0) {
            throw new ApiException("Task required count is invalid");
        }
        if (completedCount == null) {
            throw new ApiException("Task completed count is missing");
        }
        if (excusedCount == null) {
            throw new ApiException("Task excused count is missing");
        }

        // left = required - done - excused (read only)
        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        Proof proof = new Proof();
        proof.setType(request.getType());
        proof.setActivityTime(activityTime);
        proof.setEvidenceData(evidenceData);
        proof.setSubmittedAt(now);
        proof.setResult("PENDING");
        proof.setProcessingStatus("WAITING");
        proof.setRejectionReason(null);
        proof.setGoalTask(task);
        proof.setCommitmentWeek(week);
        proofRepository.save(proof);

        // the AI decides: accepted (+1), rejected or to the admin
        if (analyze) { proofDecisionService.decide(proof); }
        return proof;
    }

    public void updateGoalTaskProof(Integer userId,
                                   Integer proofId,
                                   ProofUpdateRequest request) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        if (proofId == null) {
            throw new ApiException("Proof ID is required");
        }
        if (request == null) {
            throw new ApiException("Proof update data is required");
        }

        Proof proof = proofRepository.findProofById(proofId);
        if (proof == null) {
            throw new ApiException("Proof not found");
        }
        GoalTask task = proof.getGoalTask();
        if (task == null) {
            throw new ApiException("Goal task not found");
        }

        CommitmentWeek week =
                proof.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        Goal goal = task.getGoal();
        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        // the owner check comes first
        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal must belong to a member");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // not after the AI started
        if (!"WAITING".equals(proof.getProcessingStatus())) {
            throw new ApiException("Only proofs waiting for analysis can be updated");
        }
        // a decided proof keeps its evidence
        if (!"PENDING".equals(proof.getResult())) {
            throw new ApiException("Only pending proofs can be updated");
        }
        // so does one with an objection
        if (proof.getObjection() != null) {
            throw new ApiException("A proof with an objection cannot be updated");
        }

        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }
        if (!goal.getId().equals(commitment.getId())) {
            throw new ApiException("Goal task does not belong to this goal");
        }

        Integer taskWeekNumber = task.getWeekNumber();
        Integer weekNumber = week.getWeekNumber();
        if (taskWeekNumber == null) {
            throw new ApiException("Goal task week number is missing");
        }
        if (weekNumber == null) {
            throw new ApiException("Commitment week number is missing");
        }
        if (!taskWeekNumber.equals(weekNumber)) {
            throw new ApiException("Goal task does not belong to this week");
        }

        // a withdrawn commitment takes no proofs
        if ("DRAFT".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a draft goal");
        }
        if ("WITHDRAWN".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a withdrawn goal");
        }
        // nor a settled week or task
        if ("SETTLED".equals(week.getTrackStatus())) {
            throw new ApiException("This week is settled");
        }
        if ("SETTLED".equals(task.getTrackStatus())) {
            throw new ApiException("This goal task is settled");
        }

        // the task's own method, not one picked now
        String proofMethod = task.getProofMethod();
        if (proofMethod == null) {
            throw new ApiException("Goal task proof method is missing");
        }
        if (!proofMethod.equals(proof.getType())) {
            throw new ApiException("Proof type does not match the task method");
        }

        String evidenceData = request.getEvidenceData();
        if (evidenceData == null) {
            throw new ApiException("Evidence data is required");
        }
        if (evidenceData.isBlank()) {
            throw new ApiException("Evidence data cannot be empty");
        }

        LocalDateTime activityTime = request.getActivityTime();
        if (activityTime == null) {
            throw new ApiException("Activity time is required");
        }

        LocalDateTime oldActivityTime = proof.getActivityTime();
        if (oldActivityTime == null) {
            throw new ApiException("Original activity time is missing");
        }

        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (activityTime.isAfter(now)) {
            throw new ApiException("Activity time cannot be in the future");
        }

        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }
        // sent during the week, no extra time
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Proof submission time has ended");
        }
        // and the activity happened in it
        if (activityTime.isBefore(weekStart)) {
            throw new ApiException("Activity time is before this week");
        }
        if (activityTime.isAfter(weekEnd)) {
            throw new ApiException("Activity time is after this week");
        }

        // a new hour on the same day needs no overlap check
        LocalDate oldActivityDate = oldActivityTime.toLocalDate();
        LocalDate newActivityDate = activityTime.toLocalDate();

        /*
         إذا تغير اليوم نتحقق من توفر اليوم الجديد لنفس المهمة.
         إذا تغير الدليل أو الساعة فقط نتجاوز هذه الفحوصات.
        */
        if (!oldActivityDate.equals(newActivityDate)) {
            Integer goalTaskId = task.getId();
            Integer commitmentWeekId = week.getId();
            LocalDate activityDate = activityTime.toLocalDate();
            // [day start, next day start)
            LocalDateTime dayStart = activityDate.atStartOfDay();
            LocalDateTime nextDayStart = activityDate.plusDays(1).atStartOfDay();
    
            // one accepted proof per task and day
            boolean hasAcceptedProof = proofRepository.existsOtherTaskProof(
                    proofId, goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
            if (hasAcceptedProof) {
                throw new ApiException("This day already has an accepted proof");
            }
    
            // wait for the one being checked
            boolean hasPendingProof = proofRepository.existsOtherTaskProof(
                    proofId, goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
            if (hasPendingProof) {
                throw new ApiException("A proof for this day is still pending");
            }
    
            boolean hasPendingProofObjection =
                    objectionRepository.existsPendingTaskProofObjection(
                            goalTaskId, commitmentWeekId, dayStart, nextDayStart);
            if (hasPendingProofObjection) {
                throw new ApiException("A proof objection for this day is still pending");
            }
    
            // an excused day needs no proof
            boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, activityDate, "ACCEPTED");
            if (hasAcceptedExcuse) {
                throw new ApiException("This day already has an accepted excuse");
            }
    
            boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, activityDate, "PENDING");
            if (hasPendingExcuse) {
                throw new ApiException("An excuse for this day is still pending");
            }
    
            boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, activityDate, "ESCALATED");
            if (hasEscalatedExcuse) {
                throw new ApiException("An excuse for this day is awaiting admin review");
            }
    
            boolean hasPendingExcuseObjection =
                    objectionRepository.existsPendingTaskExcuseObjection(
                            goalTaskId, commitmentWeekId, activityDate);
            if (hasPendingExcuseObjection) {
                throw new ApiException("An excuse objection for this day is still pending");
            }

        }

        Integer requiredCount = task.getTimesPerWeek();
        Integer completedCount = task.getCompletedCount();
        Integer excusedCount = task.getExcusedCount();
        if (requiredCount == null) {
            throw new ApiException("Task required count is missing");
        }
        if (requiredCount <= 0) {
            throw new ApiException("Task required count is invalid");
        }
        if (completedCount == null) {
            throw new ApiException("Task completed count is missing");
        }
        if (excusedCount == null) {
            throw new ApiException("Task excused count is missing");
        }

        // left = required - done - excused (read only)
        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        if (proof.getAttemptDeadline() != null) { throw new ApiException("Use the proof attempt endpoints for this activity"); }

        proof.setActivityTime(activityTime);
        proof.setEvidenceData(evidenceData);

        proofRepository.save(proof);
    }

    public void deleteGoalTaskProof(Integer userId, Integer proofId) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (proofId == null) {
            throw new ApiException("Proof ID is required");
        }

        Proof proof = proofRepository.findProofById(proofId);

        if (proof == null) {
            throw new ApiException("Proof not found");
        }

        GoalTask task = proof.getGoalTask();

        if (task == null) {
            throw new ApiException("Goal task not found");
        }

        Goal goal = task.getGoal();

        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        Member member = goal.getMember();

        if (member == null) {
            throw new ApiException("Goal must belong to a member");
        }

        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        Integer goalOwnerUserId = member.getUser().getId();

        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        if (proof.getAttemptDeadline() != null) { throw new ApiException("Use the proof attempt endpoints for this activity"); }

        // delete only before the AI starts
        if (!"WAITING".equals(proof.getProcessingStatus())) {
            throw new ApiException("Only proofs waiting for analysis can be deleted");
        }

        if (!"PENDING".equals(proof.getResult())) {
            throw new ApiException("Only pending proofs can be deleted");
        }

        if (proof.getObjection() != null) {
            throw new ApiException("A proof with an objection cannot be deleted");
        }

        CommitmentWeek week = proof.getCommitmentWeek();

        if (week == null) {
            throw new ApiException("Proof commitment week not found");
        }

        Commitment commitment = week.getCommitment();

        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }

        if (!goal.getId().equals(commitment.getId())) {
            throw new ApiException("Goal task does not belong to this goal");
        }

        Integer taskWeekNumber = task.getWeekNumber();
        Integer weekNumber = week.getWeekNumber();

        if (taskWeekNumber == null) {
            throw new ApiException("Goal task week number is missing");
        }

        if (weekNumber == null) {
            throw new ApiException("Commitment week number is missing");
        }

        if (!taskWeekNumber.equals(weekNumber)) {
            throw new ApiException("Goal task does not belong to this week");
        }

        if ("DRAFT".equals(goal.getStatus())) {
            throw new ApiException("Cannot delete proof for a draft goal");
        }

        if ("WITHDRAWN".equals(goal.getStatus())) {
            throw new ApiException("Cannot delete proof for a withdrawn goal");
        }

        if ("SETTLED".equals(week.getTrackStatus())) {
            throw new ApiException("This week is settled");
        }

        if ("SETTLED".equals(task.getTrackStatus())) {
            throw new ApiException("This goal task is settled");
        }

        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();

        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }

        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }

        LocalDateTime now =
                LocalDateTime.now(ZoneId.of("Asia/Riyadh"));

        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }

        if (now.isAfter(weekEnd)) {
            throw new ApiException("Proof deletion time has ended");
        }

        // no counters to undo, it was never accepted
        proofRepository.delete(proof);
    }

}