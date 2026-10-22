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
    private final GoalTaskRepository goalTaskRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final ProofRepository proofRepository;
    private final ObjectionRepository objectionRepository;
    private final ExcuseDecisionService excuseDecisionService;

    public List<Excuse> getAllExcuses() {
        return excuseRepository.findAll();
    }

    public Excuse getExcuseById(Integer userId, Integer excuseId) {

        // معرف المستخدم المسجل يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }

        // جلب العذر ثم التحقق من صاحبه قبل إرجاعه.
        Excuse excuse = excuseRepository.findExcuseById(excuseId);
        if (excuse == null) {
            throw new ApiException("Excuse not found");
        }

        // الوصول لصاحب العذر من الأسبوع والتعهد يدعم الأهداف والعادات.
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

        // نتأكد أن معرف المستخدم المسجل هو نفسه صاحب التعهد المرتبط بالعذر.
        // يمنع هذا الشرط عرض أعذار مستخدم آخر بمجرد معرفة معرف العذر.
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

        // المرحلة الأولى: التحقق من المعرفات وبيانات الطلب.
        // معرف المستخدم المسجل يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        // معرف المهمة التي يقدم المستخدم العذر عنها.
        if (goalTaskId == null) {
            throw new ApiException("Goal task ID is required");
        }
        // معرف أسبوع الالتزام المرتبط بالعذر.
        if (commitmentWeekId == null) {
            throw new ApiException("Commitment week ID is required");
        }
        if (request == null) {
            throw new ApiException("Excuse data is required");
        }

        // المرحلة الثانية: جلب المهمة والهدف والتحقق من الملكية.
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

        // نتأكد أن المستخدم المسجل هو نفسه صاحب الجول.
        // يمنع هذا الشرط تقديم عذر لمهمة تخص مستخدما آخر.
        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // المرحلة الثالثة: التحقق من الأسبوع وانتماء المهمة إليه.
        CommitmentWeek week =
                commitmentWeekRepository.findCommitmentWeekById(commitmentWeekId);
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }

        // المهمة والأسبوع يجب أن يتبعا نفس الهدف.
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
        // تطابق الهدف وحده لا يكفي؛ يجب تطابق رقم الأسبوع أيضا.
        if (!taskWeekNumber.equals(weekNumber)) {
            throw new ApiException("Goal task does not belong to this week");
        }

        // المرحلة الرابعة: التحقق من حالة التعهد والأسبوع والمهمة.
        String goalStatus = goal.getStatus();

        if (goalStatus == null) {
            throw new ApiException("Goal status is missing");
        }

        // إضافة العذر وتعديله مسموحان فقط عندما يكون التعهد نشطا.
        boolean isActive = goalStatus.equals("ACTIVE");

        if (!isActive) {
            throw new ApiException("Goal must be active");
        }

        String weekStatus = week.getTrackStatus();
        if (weekStatus == null) {
            throw new ApiException("Week status is missing");
        }
        boolean isWeekSettled = weekStatus.equals("SETTLED");
        // لا نستقبل أعذارا جديدة بعد تسوية الأسبوع.
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

        // المرحلة الخامسة: التحقق من بيانات العذر.
        String type = request.getType();
        if (type == null) {
            throw new ApiException("Excuse type is required");
        }
        // نتحقق أن النوع أحد الأنواع المسموحة.
        boolean isValidType = type.matches("^(SICK|TRAVEL|EMERGENCY|OTHER)$");
        if (!isValidType) {
            throw new ApiException("Invalid excuse type");
        }

        String evidenceUrl = request.getEvidenceUrl();
        // عدم وجود دليل لا يمنع تسجيل الطلب.
        if (evidenceUrl != null) {
            if (evidenceUrl.length() > 500) {
                throw new ApiException("Evidence URL must be 500 characters max");
            }
        }

        LocalDate excuseDate = request.getExcuseDate();
        if (excuseDate == null) {
            throw new ApiException("Excuse date is required");
        }

        // المرحلة السادسة: التحقق من وقت التقديم وتاريخ اليوم المعذور.
        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }

        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        // التقديم مسموح أثناء فترة الأسبوع فقط.
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        // نهاية الأسبوع هي آخر موعد، بدون إضافة مهلة.
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Excuse submission time has ended");
        }

        // العذر يغطي يوما، لذلك نقارن التاريخ دون الساعة.
        LocalDate weekStartDate = weekStart.toLocalDate();
        LocalDate weekEndDate = weekEnd.toLocalDate();
        if (excuseDate.isBefore(weekStartDate)) {
            throw new ApiException("Excuse date is before this week");
        }
        if (excuseDate.isAfter(weekEndDate)) {
            throw new ApiException("Excuse date is after this week");
        }

        // حدود اليوم المعذور للبحث عن الإثباتات المرتبطة به.
        LocalDateTime dayStart = excuseDate.atStartOfDay();
        LocalDateTime nextDayStart = excuseDate.plusDays(1).atStartOfDay();

        // المرحلة السابعة: منع التكرار والتداخل لنفس المهمة واليوم.
        // وجود بروف مقبولة يعني أن تنفيذ هذا اليوم اكتمل.
        boolean hasAcceptedProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
        if (hasAcceptedProof) {
            throw new ApiException("This day already has an accepted proof");
        }

        // ننتظر معالجة البروف قبل السماح بعذر عن نفس اليوم.
        boolean hasPendingProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
        if (hasPendingProof) {
            throw new ApiException("A proof for this day is still pending");
        }

        // اليوم المعفى سابقا لا يستقبل عذرا آخر.
        boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, excuseDate, "ACCEPTED");
        if (hasAcceptedExcuse) {
            throw new ApiException("This day already has an accepted excuse");
        }

        // لا نستقبل عذرا جديدا قبل معالجة العذر السابق.
        boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, excuseDate, "PENDING");
        if (hasPendingExcuse) {
            throw new ApiException("An excuse for this day is still pending");
        }

        // العذر المحول للأدمن ما زال قيد المعالجة.
        boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, excuseDate, "ESCALATED");
        if (hasEscalatedExcuse) {
            throw new ApiException("An excuse for this day is awaiting admin review");
        }

        // الاعتراض المعلق على بروف يمنع تقديم العذر.
        boolean hasPendingProofObjection =
                objectionRepository.existsPendingProofObjection(
                        commitmentWeekId, goalTaskId, dayStart, nextDayStart);
        if (hasPendingProofObjection) {
            throw new ApiException("A proof objection for this day is still pending");
        }

        // الاعتراض المعلق على عذر سابق يمنع إعادة التقديم.
        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingExcuseObjection(
                        commitmentWeekId, goalTaskId, excuseDate);
        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        // المرحلة الثامنة: التحقق من وجود عدد مطلوب متبق للمهمة.
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

        // نقرأ العدادات فقط، ولا نعدلها عند تقديم العذر.
        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        // المرحلة التاسعة: إنشاء العذر بعد نجاح جميع التشييكات.
        Excuse excuse = new Excuse();
        // بيانات المستخدم.
        excuse.setType(type);
        excuse.setEvidenceUrl(evidenceUrl);
        excuse.setExcuseDate(excuseDate);
        // قيم يحددها النظام؛ التقييم لم يبدأ بعد.
        excuse.setStatus("PENDING");
        excuse.setProcessingStatus("WAITING");
        excuse.setAiAssessment(null);
        excuse.setDecidedAt(null);
        excuse.setForwardedToAdmin(false);
        excuse.setAdmin(null);
        // ربط العذر بالمهمة وأسبوع الالتزام.
        excuse.setGoalTask(task);
        excuse.setCommitmentWeek(week);

        // المرحلة العاشرة: حفظ العذر في قاعدة البيانات.
        excuseRepository.save(excuse);

        // قرار الذكاء: مقبول (مرة معذورة) أو مرفوض أو يتحول للأدمن.
        excuseDecisionService.decide(excuse);
    }

    public void updateGoalTaskExcuse(Integer userId,
                                     Integer excuseId,
                                     ExcuseRequest request) {

        // المرحلة الأولى: التحقق من المعرفات وبيانات الطلب.
        // معرف المستخدم المسجل يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        // معرف العذر الذي يريد المستخدم تعديله.
        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }
        if (request == null) {
            throw new ApiException("Excuse update data is required");
        }

        // جلب العذر الحالي؛ التعديل لا ينشئ سجلا جديدا.
        Excuse excuse = excuseRepository.findExcuseById(excuseId);
        if (excuse == null) {
            throw new ApiException("Excuse not found");
        }

        // المهمة تؤخذ من العذر المحفوظ ولا يمكن تغييرها في طلب التعديل.
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

        // نتأكد أن المستخدم المسجل هو نفسه صاحب الجول.
        // يمنع هذا الشرط تقديم عذر لمهمة تخص مستخدما آخر.
        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // التحقق أن العذر ما زال ينتظر التقييم.
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

        // نفحص وجود قيمة التحويل أولا، ثم نستخدمها مباشرة.
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

        // المرحلة الثالثة: التحقق من الأسبوع وانتماء المهمة إليه.
        CommitmentWeek week =
                excuse.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }

        // المهمة والأسبوع يجب أن يتبعا نفس الهدف.
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
        // تطابق الهدف وحده لا يكفي؛ يجب تطابق رقم الأسبوع أيضا.
        if (!taskWeekNumber.equals(weekNumber)) {
            throw new ApiException("Goal task does not belong to this week");
        }

        // المرحلة الرابعة: التحقق من حالة التعهد والأسبوع والمهمة.
        String goalStatus = goal.getStatus();

        if (goalStatus == null) {
            throw new ApiException("Goal status is missing");
        }

        // إضافة العذر وتعديله مسموحان فقط عندما يكون التعهد نشطا.
        boolean isActive = goalStatus.equals("ACTIVE");

        if (!isActive) {
            throw new ApiException("Goal must be active");
        }

        String weekStatus = week.getTrackStatus();
        if (weekStatus == null) {
            throw new ApiException("Week status is missing");
        }
        boolean isWeekSettled = weekStatus.equals("SETTLED");
        // لا نستقبل أعذارا جديدة بعد تسوية الأسبوع.
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

        // المرحلة الخامسة: التحقق من بيانات العذر.
        String type = request.getType();
        if (type == null) {
            throw new ApiException("Excuse type is required");
        }
        // نتحقق أن النوع أحد الأنواع المسموحة.
        boolean isValidType = type.matches("^(SICK|TRAVEL|EMERGENCY|OTHER)$");
        if (!isValidType) {
            throw new ApiException("Invalid excuse type");
        }

        String evidenceUrl = request.getEvidenceUrl();
        // عدم وجود دليل لا يمنع تسجيل الطلب.
        if (evidenceUrl != null) {
            if (evidenceUrl.length() > 500) {
                throw new ApiException("Evidence URL must be 500 characters max");
            }
        }

        LocalDate excuseDate = request.getExcuseDate();
        if (excuseDate == null) {
            throw new ApiException("Excuse date is required");
        }

        // تاريخ العذر القديم للمقارنة مع اليوم الجديد.
        LocalDate oldExcuseDate = excuse.getExcuseDate();
        if (oldExcuseDate == null) {
            throw new ApiException("Original excuse date is missing");
        }

        // المرحلة السادسة: التحقق من وقت التقديم وتاريخ اليوم المعذور.
        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }

        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        // التقديم مسموح أثناء فترة الأسبوع فقط.
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        // نهاية الأسبوع هي آخر موعد، بدون إضافة مهلة.
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Excuse update time has ended");
        }

        // العذر يغطي يوما، لذلك نقارن التاريخ دون الساعة.
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
            // حدود اليوم المعذور للبحث عن الإثباتات المرتبطة به.
            LocalDateTime dayStart = excuseDate.atStartOfDay();
            LocalDateTime nextDayStart = excuseDate.plusDays(1).atStartOfDay();
    
            // المرحلة السابعة: منع التكرار والتداخل لنفس المهمة واليوم.
            // وجود بروف مقبولة يعني أن تنفيذ هذا اليوم اكتمل.
            boolean hasAcceptedProof = proofRepository.existsTaskProof(
                    goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
            if (hasAcceptedProof) {
                throw new ApiException("This day already has an accepted proof");
            }
    
            // ننتظر معالجة البروف قبل السماح بعذر عن نفس اليوم.
            boolean hasPendingProof = proofRepository.existsTaskProof(
                    goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
            if (hasPendingProof) {
                throw new ApiException("A proof for this day is still pending");
            }
    
            // اليوم المعفى سابقا لا يستقبل عذرا آخر.
            boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, excuseDate, "ACCEPTED");
            if (hasAcceptedExcuse) {
                throw new ApiException("This day already has an accepted excuse");
            }
    
            // لا نستقبل عذرا جديدا قبل معالجة العذر السابق.
            boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, excuseDate, "PENDING");
            if (hasPendingExcuse) {
                throw new ApiException("An excuse for this day is still pending");
            }
    
            // العذر المحول للأدمن ما زال قيد المعالجة.
            boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, excuseDate, "ESCALATED");
            if (hasEscalatedExcuse) {
                throw new ApiException("An excuse for this day is awaiting admin review");
            }
    
            // الاعتراض المعلق على بروف يمنع تقديم العذر.
            boolean hasPendingProofObjection =
                    objectionRepository.existsPendingProofObjection(
                            commitmentWeekId, goalTaskId, dayStart, nextDayStart);
            if (hasPendingProofObjection) {
                throw new ApiException("A proof objection for this day is still pending");
            }
    
            // الاعتراض المعلق على عذر سابق يمنع إعادة التقديم.
            boolean hasPendingExcuseObjection =
                    objectionRepository.existsPendingExcuseObjection(
                            commitmentWeekId, goalTaskId, excuseDate);
            if (hasPendingExcuseObjection) {
                throw new ApiException("An excuse objection for this day is still pending");
            }
    
    
        }

        // المرحلة الثامنة: التحقق من وجود عدد مطلوب متبق للمهمة.
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

        // نقرأ العدادات فقط، ولا نعدلها عند تقديم العذر.
        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        // بعد جميع التشييكات نعدل بيانات المستخدم فقط.
        // إرسال دليل فارغ يزيل الرابط السابق؛ الطلب يعدل الحقول الثلاثة كاملة.
        excuse.setType(type);
        excuse.setEvidenceUrl(evidenceUrl);
        excuse.setExcuseDate(excuseDate);

        // حفظ نفس السجل دون تغيير الحالات أو العلاقات أو العداد أو المبلغ.
        excuseRepository.save(excuse);
    }

    public void deleteGoalTaskExcuse(Integer userId, Integer excuseId) {

        // المرحلة الأولى: التحقق من المعرفات.
        // معرف المستخدم يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        // معرف العذر المراد حذفه.
        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }

        // المرحلة الثانية: جلب العذر والمهمة والهدف.
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

        // المرحلة الثالثة: التحقق من ملكية المستخدم.
        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal owner not found");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        // نتأكد أن المستخدم المسجل هو نفسه صاحب الجول.
        // يمنع هذا الشرط حذف عذر لمهمة تخص مستخدما آخر.
        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // المرحلة الرابعة: الحذف مسموح قبل بدء المعالجة فقط.
        String processingStatus = excuse.getProcessingStatus();
        if (processingStatus == null) {
            throw new ApiException("Excuse processing status is missing");
        }

        boolean isWaiting = processingStatus.equals("WAITING");
        if (!isWaiting) {
            throw new ApiException("Only excuses waiting for analysis can be deleted");
        }

        // المرحلة الخامسة: التحقق من ارتباط المهمة بالأسبوع.
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

        // المرحلة السادسة: التحقق من حالة التعهد والأسبوع والمهمة.
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

        // التعهد المنتهي لا يسمح بحذف الأعذار المرتبطة به.
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

        // المرحلة السابعة: التحقق من مهلة الأسبوع.
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

        // المرحلة الأخيرة: الحذف بعد جميع التشييكات.
        // لا نغير العداد أو المبلغ لأن العذر لم تتم معالجته.
        excuseRepository.delete(excuse);
    }
}