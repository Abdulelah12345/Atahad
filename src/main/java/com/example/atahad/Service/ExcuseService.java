package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Excuse;
import com.example.atahad.Repository.ExcuseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import com.example.atahad.Dto.In.ExcuseRequest;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Repository.GoalTaskRepository;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.ProofRepository;
import com.example.atahad.Repository.ObjectionRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ExcuseService {

    private final ExcuseRepository excuseRepository;
    private final ProofAttachmentService proofAttachmentService;
    private final GoalTaskRepository goalTaskRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final ProofRepository proofRepository;
    private final ObjectionRepository objectionRepository;
    private final ExcuseDecisionService excuseDecisionService;

    public List<Excuse> getAllExcuses() {
        return excuseRepository.findAll();
    }

    public Excuse getExcuseById(Integer userId, Integer excuseId) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }

        Excuse excuse = excuseRepository.findExcuseById(excuseId);
        if (excuse == null) {
            throw new ApiException("Excuse not found");
        }

        // the owner through the week, works for goals and habits
        CommitmentWeek week = excuse.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Excuse commitment week not found");
        }

        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Commitment not found");
        }

        Member member = commitment.getMember();
        if (member == null) {
            throw new ApiException("Excuse owner not found");
        }

        if (member.getUser() == null) {
            throw new ApiException("Excuse owner user not found");
        }

        // only the owner can see it
        Integer ownerUserId = member.getUser().getId();
        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This excuse does not belong to you");
        }

        return excuse;
    }

    public void addGoalTaskExcuse(Integer userId,
                                  Integer goalTaskId,
                                  Integer commitmentWeekId,
                                  ExcuseRequest request) {

        // 1. ids and request
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
            throw new ApiException("Excuse data is required");
        }

        // 2. the task, its goal and the owner
        GoalTask task = goalTaskRepository.findGoalTaskById(goalTaskId);
        if (task == null) {
            throw new ApiException("Goal task not found");
        }

        Goal goal = task.getGoal();
        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal owner not found");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // 3. the task belongs to this week
        CommitmentWeek week =
                commitmentWeekRepository.findCommitmentWeekById(commitmentWeekId);
        if (week == null) {
            throw new ApiException("Commitment week not found");
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
        // same goal is not enough, the week number too
        if (!taskWeekNumber.equals(weekNumber)) {
            throw new ApiException("Goal task does not belong to this week");
        }

        // 4. the commitment, the week and the task are still open
        String goalStatus = goal.getStatus();

        if (goalStatus == null) {
            throw new ApiException("Goal status is missing");
        }

        boolean isActive = goalStatus.equals("ACTIVE");

        if (!isActive) {
            throw new ApiException("Goal must be active");
        }

        String weekStatus = week.getTrackStatus();
        if (weekStatus == null) {
            throw new ApiException("Week status is missing");
        }
        boolean isWeekSettled = weekStatus.equals("SETTLED");
        if (isWeekSettled) {
            throw new ApiException("This week is settled");
        }

        String taskStatus = task.getTrackStatus();
        if (taskStatus == null) {
            throw new ApiException("Goal task status is missing");
        }
        boolean isTaskSettled = taskStatus.equals("SETTLED");
        if (isTaskSettled) {
            throw new ApiException("This goal task is settled");
        }

        // 5. the excuse data
        String type = request.getType();
        if (type == null) {
            throw new ApiException("Excuse type is required");
        }
        boolean isValidType = type.matches("^(SICK|TRAVEL|EMERGENCY|OTHER)$");
        if (!isValidType) {
            throw new ApiException("Invalid excuse type");
        }

        String evidenceUrl = request.getEvidenceUrl();
        // the document is required and must be his
        if (evidenceUrl != null) {
            if (evidenceUrl.length() > 500) {
                throw new ApiException("Evidence URL must be 500 characters max");
            }
        }

        LocalDate excuseDate = request.getExcuseDate();
        if (excuseDate == null) {
            throw new ApiException("Excuse date is required");
        }

        // 6. sent during the week, for a day of the week
        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }

        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        // the week end is the deadline, no extra time
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Excuse submission time has ended");
        }

        // an excuse covers a day, compare dates only
        LocalDate weekStartDate = weekStart.toLocalDate();
        LocalDate weekEndDate = weekEnd.toLocalDate();
        if (excuseDate.isBefore(weekStartDate)) {
            throw new ApiException("Excuse date is before this week");
        }
        if (excuseDate.isAfter(weekEndDate)) {
            throw new ApiException("Excuse date is after this week");
        }

        LocalDateTime dayStart = excuseDate.atStartOfDay();
        LocalDateTime nextDayStart = excuseDate.plusDays(1).atStartOfDay();

        // 7. nothing else for this task and day
        boolean hasAcceptedProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
        if (hasAcceptedProof) {
            throw new ApiException("This day already has an accepted proof");
        }

        boolean hasPendingProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
        if (hasPendingProof) {
            throw new ApiException("A proof for this day is still pending");
        }

        boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, excuseDate, "ACCEPTED");
        if (hasAcceptedExcuse) {
            throw new ApiException("This day already has an accepted excuse");
        }

        boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, excuseDate, "PENDING");
        if (hasPendingExcuse) {
            throw new ApiException("An excuse for this day is still pending");
        }

        boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, excuseDate, "ESCALATED");
        if (hasEscalatedExcuse) {
            throw new ApiException("An excuse for this day is awaiting admin review");
        }

        boolean hasPendingProofObjection =
                objectionRepository.existsPendingProofObjection(
                        commitmentWeekId, goalTaskId, dayStart, nextDayStart);
        if (hasPendingProofObjection) {
            throw new ApiException("A proof objection for this day is still pending");
        }

        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingExcuseObjection(
                        commitmentWeekId, goalTaskId, excuseDate);
        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        // 8. there is still a time left to excuse
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

        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        // 9. save it
        Excuse excuse = new Excuse();
        excuse.setType(type);
        proofAttachmentService.requireExcuseDocument(userId, evidenceUrl);
        excuse.setEvidenceUrl(evidenceUrl);
        excuse.setExcuseDate(excuseDate);
        excuse.setStatus("PENDING");
        excuse.setProcessingStatus("WAITING");
        excuse.setAiAssessment(null);
        excuse.setDecidedAt(null);
        excuse.setForwardedToAdmin(false);
        excuse.setAdmin(null);
        excuse.setGoalTask(task);
        excuse.setCommitmentWeek(week);

        excuseRepository.save(excuse);

        // the AI decides: accepted (an excused time), rejected or to the admin
        excuseDecisionService.decide(excuse);
    }

    public void updateGoalTaskExcuse(Integer userId,
                                     Integer excuseId,
                                     ExcuseRequest request) {

        // 1. ids and request
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }
        if (request == null) {
            throw new ApiException("Excuse update data is required");
        }

        Excuse excuse = excuseRepository.findExcuseById(excuseId);
        if (excuse == null) {
            throw new ApiException("Excuse not found");
        }

        // the task can't change in an edit
        GoalTask task = excuse.getGoalTask();
        if (task == null) {
            throw new ApiException("This excuse is not linked to a goal task");
        }

        Goal goal = task.getGoal();
        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal owner not found");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // only while it waits
        String processingStatus = excuse.getProcessingStatus();
        if (processingStatus == null) {
            throw new ApiException("Excuse processing status is missing");
        }
        boolean isWaiting = processingStatus.equals("WAITING");
        if (!isWaiting) {
            throw new ApiException("Only excuses waiting for analysis can be updated");
        }

        String status = excuse.getStatus();
        if (status == null) {
            throw new ApiException("Excuse status is missing");
        }
        boolean isPending = status.equals("PENDING");
        if (!isPending) {
            throw new ApiException("Only pending excuses can be updated");
        }

        Boolean forwardedToAdmin = excuse.getForwardedToAdmin();
        if (forwardedToAdmin != null) {
            if (forwardedToAdmin) {
                throw new ApiException("This excuse has been forwarded to admin");
            }
        }
        if (excuse.getAdmin() != null) {
            throw new ApiException("This excuse is assigned to an admin");
        }
        if (excuse.getAiAssessment() != null) {
            throw new ApiException("This excuse has already been assessed");
        }
        if (excuse.getDecidedAt() != null) {
            throw new ApiException("This excuse already has a decision");
        }
        if (excuse.getObjection() != null) {
            throw new ApiException("An excuse with an objection cannot be updated");
        }

        // 3. the task belongs to this week
        CommitmentWeek week =
                excuse.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Commitment week not found");
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
        // same goal is not enough, the week number too
        if (!taskWeekNumber.equals(weekNumber)) {
            throw new ApiException("Goal task does not belong to this week");
        }

        // 4. the commitment, the week and the task are still open
        String goalStatus = goal.getStatus();

        if (goalStatus == null) {
            throw new ApiException("Goal status is missing");
        }

        boolean isActive = goalStatus.equals("ACTIVE");

        if (!isActive) {
            throw new ApiException("Goal must be active");
        }

        String weekStatus = week.getTrackStatus();
        if (weekStatus == null) {
            throw new ApiException("Week status is missing");
        }
        boolean isWeekSettled = weekStatus.equals("SETTLED");
        if (isWeekSettled) {
            throw new ApiException("This week is settled");
        }

        String taskStatus = task.getTrackStatus();
        if (taskStatus == null) {
            throw new ApiException("Goal task status is missing");
        }
        boolean isTaskSettled = taskStatus.equals("SETTLED");
        if (isTaskSettled) {
            throw new ApiException("This goal task is settled");
        }

        // 5. the excuse data
        String type = request.getType();
        if (type == null) {
            throw new ApiException("Excuse type is required");
        }
        boolean isValidType = type.matches("^(SICK|TRAVEL|EMERGENCY|OTHER)$");
        if (!isValidType) {
            throw new ApiException("Invalid excuse type");
        }

        String evidenceUrl = request.getEvidenceUrl();
        // the document is required and must be his
        if (evidenceUrl != null) {
            if (evidenceUrl.length() > 500) {
                throw new ApiException("Evidence URL must be 500 characters max");
            }
        }

        LocalDate excuseDate = request.getExcuseDate();
        if (excuseDate == null) {
            throw new ApiException("Excuse date is required");
        }

        LocalDate oldExcuseDate = excuse.getExcuseDate();
        if (oldExcuseDate == null) {
            throw new ApiException("Original excuse date is missing");
        }

        // 6. sent during the week, for a day of the week
        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }

        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        // the week end is the deadline, no extra time
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Excuse update time has ended");
        }

        // an excuse covers a day, compare dates only
        LocalDate weekStartDate = weekStart.toLocalDate();
        LocalDate weekEndDate = weekEnd.toLocalDate();
        if (excuseDate.isBefore(weekStartDate)) {
            throw new ApiException("Excuse date is before this week");
        }
        if (excuseDate.isAfter(weekEndDate)) {
            throw new ApiException("Excuse date is after this week");
        }

        /*
         نفحص التداخل فقط إذا تغير يوم العذر.
         العذر الحالي يبقى بتاريخ اليوم القديم أثناء هذه الفحوصات،
         ولا نسند التاريخ الجديد إلا بعد انتهائها كي لا يطابق السجل نفسه.
        */
        if (!oldExcuseDate.equals(excuseDate)) {
            Integer goalTaskId = task.getId();
            Integer commitmentWeekId = week.getId();
            LocalDateTime dayStart = excuseDate.atStartOfDay();
            LocalDateTime nextDayStart = excuseDate.plusDays(1).atStartOfDay();
    
            // 7. nothing else for this task and day
            boolean hasAcceptedProof = proofRepository.existsTaskProof(
                    goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
            if (hasAcceptedProof) {
                throw new ApiException("This day already has an accepted proof");
            }
    
            boolean hasPendingProof = proofRepository.existsTaskProof(
                    goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
            if (hasPendingProof) {
                throw new ApiException("A proof for this day is still pending");
            }
    
            boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, excuseDate, "ACCEPTED");
            if (hasAcceptedExcuse) {
                throw new ApiException("This day already has an accepted excuse");
            }
    
            boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, excuseDate, "PENDING");
            if (hasPendingExcuse) {
                throw new ApiException("An excuse for this day is still pending");
            }
    
            boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, excuseDate, "ESCALATED");
            if (hasEscalatedExcuse) {
                throw new ApiException("An excuse for this day is awaiting admin review");
            }
    
            boolean hasPendingProofObjection =
                    objectionRepository.existsPendingProofObjection(
                            commitmentWeekId, goalTaskId, dayStart, nextDayStart);
            if (hasPendingProofObjection) {
                throw new ApiException("A proof objection for this day is still pending");
            }
    
            boolean hasPendingExcuseObjection =
                    objectionRepository.existsPendingExcuseObjection(
                            commitmentWeekId, goalTaskId, excuseDate);
            if (hasPendingExcuseObjection) {
                throw new ApiException("An excuse objection for this day is still pending");
            }

        }

        // 8. there is still a time left to excuse
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

        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        // an edit needs the document too
        excuse.setType(type);
        proofAttachmentService.requireExcuseDocument(userId, evidenceUrl);
        excuse.setEvidenceUrl(evidenceUrl);
        excuse.setExcuseDate(excuseDate);

        excuseRepository.save(excuse);
    }

    public void deleteGoalTaskExcuse(Integer userId, Integer excuseId) {

        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }

        Excuse excuse = excuseRepository.findExcuseById(excuseId);
        if (excuse == null) {
            throw new ApiException("Excuse not found");
        }

        GoalTask task = excuse.getGoalTask();
        if (task == null) {
            throw new ApiException("This excuse is not linked to a goal task");
        }

        Goal goal = task.getGoal();
        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal owner not found");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // delete only before the AI starts
        String processingStatus = excuse.getProcessingStatus();
        if (processingStatus == null) {
            throw new ApiException("Excuse processing status is missing");
        }

        boolean isWaiting = processingStatus.equals("WAITING");
        if (!isWaiting) {
            throw new ApiException("Only excuses waiting for analysis can be deleted");
        }

        CommitmentWeek week = excuse.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Excuse commitment week not found");
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

        String goalStatus = goal.getStatus();
        if (goalStatus == null) {
            throw new ApiException("Goal status is missing");
        }

        boolean isDraft = goalStatus.equals("DRAFT");
        if (isDraft) {
            throw new ApiException("Cannot delete excuse for a draft goal");
        }

        boolean isWithdrawn = goalStatus.equals("WITHDRAWN");
        if (isWithdrawn) {
            throw new ApiException("Cannot delete excuse for a withdrawn goal");
        }

        boolean isEnded = goalStatus.equals("ENDED");
        if (isEnded) {
            throw new ApiException("Cannot delete excuse for an ended goal");
        }

        String weekStatus = week.getTrackStatus();
        if (weekStatus == null) {
            throw new ApiException("Week status is missing");
        }

        boolean isWeekSettled = weekStatus.equals("SETTLED");
        if (isWeekSettled) {
            throw new ApiException("This week is settled");
        }

        String taskStatus = task.getTrackStatus();
        if (taskStatus == null) {
            throw new ApiException("Goal task status is missing");
        }

        boolean isTaskSettled = taskStatus.equals("SETTLED");
        if (isTaskSettled) {
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

        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Excuse deletion time has ended");
        }

        // no counters to undo, it was never decided
        excuseRepository.delete(excuse);
    }
}
