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

    public Proof getProofById(Integer id) {
        Proof proof = proofRepository.findProofById(id);
        if (proof == null) {
            throw new ApiException("Proof not found");
        }
        return proof;
    }

    public List<Proof> getAllProofsByUserId(Integer userId) {

        // معرف المستخدم من جلسة الدخول، وليس معرفا يختاره في الرابط.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        // الكويري تقيد النتائج ببروفات المستخدم نفسه.
        return proofRepository.findAllProofsByUserId(userId);
    }



    public void addGoalTaskProof(Integer userId,
                                Integer goalTaskId,
                                Integer commitmentWeekId,
                                ProofRequest request) {

        // معرف المستخدم يأتي من جلسة الدخول، وليس من بيانات يختارها المستخدم.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        // لا يمكن تحديد المهمة بدون معرفها.
        if (goalTaskId == null) {
            throw new ApiException("Goal task ID is required");
        }
        // نحتاج معرف الأسبوع لربط الإثبات بالفترة الصحيحة.
        if (commitmentWeekId == null) {
            throw new ApiException("Commitment week ID is required");
        }
        // الطلب يحتوي نوع الإثبات ووقت النشاط وبيانات الدليل.
        if (request == null) {
            throw new ApiException("Proof data is required");
        }

        // المهمة المحفوظة التي نريد تقديم إثبات لها.
        GoalTask task = goalTaskRepository.findGoalTaskById(goalTaskId);
        if (task == null) {
            throw new ApiException("Goal task not found");
        }

        // أسبوع الالتزام الذي سيحتسب له الإثبات.
        CommitmentWeek week =
                commitmentWeekRepository.findCommitmentWeekById(commitmentWeekId);
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        // الهدف المرتبط بالمهمة، وهو كائن Goal الموجود في التصميم.
        Goal goal = task.getGoal();
        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        // نتأكد أن معرف المستخدم المسجل هو نفسه معرف المستخدم صاحب الجول.
        // نضع شرط الملكية مبكرا حتى لا يضيف أو يعدل المستخدم بروفا لأهداف غيره.
        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal must belong to a member");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        // معرف المستخدم الذي يملك الهدف، من العلاقة المحفوظة في قاعدة البيانات.
        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // التطبيق المقفل ما يقبل إثباتات، لازم يتبرع أو يرسل عذر أول.
        lockService.checkCanAct(member);

        // التعهد المرتبط بالأسبوع، ويجب أن يكون نفس هدف المهمة.
        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }
        if (!goal.getId().equals(commitment.getId())) {
            throw new ApiException("Goal task does not belong to this goal");
        }

        // رقم أسبوع المهمة ورقم أسبوع الالتزام للمقارنة بينهما.
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

        // المسودة والمنسحب لا يستقبلان إثباتات جديدة.
        if ("DRAFT".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a draft goal");
        }
        if ("WITHDRAWN".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a withdrawn goal");
        }
        // لا نقبل إضافة إثبات بعد تسوية الأسبوع أو المهمة.
        if ("SETTLED".equals(week.getTrackStatus())) {
            throw new ApiException("This week is settled");
        }
        if ("SETTLED".equals(task.getTrackStatus())) {
            throw new ApiException("This goal task is settled");
        }

        // طريقة الإثبات المحفوظة للمهمة، وليست اختيارا جديدا وقت الرفع.
        String proofMethod = task.getProofMethod();
        if (proofMethod == null) {
            throw new ApiException("Goal task proof method is missing");
        }
        if (!proofMethod.equals(request.getType())) {
            throw new ApiException("Proof type does not match the task method");
        }

        // بيانات الدليل النصية؛ تحليل محتواها حسب النوع يضاف في مرحلة التحليل.
        String evidenceData = request.getEvidenceData();
        if (evidenceData == null) {
            throw new ApiException("Evidence data is required");
        }
        if (evidenceData.isBlank()) {
            throw new ApiException("Evidence data cannot be empty");
        }

        // وقت تنفيذ النشاط الذي أدخله المستخدم.
        LocalDateTime activityTime = request.getActivityTime();
        if (activityTime == null) {
            throw new ApiException("Activity time is required");
        }

        // وقت استقبال الطلب الحالي بتوقيت السعودية.
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (activityTime.isAfter(now)) {
            throw new ApiException("Activity time cannot be in the future");
        }

        // حدود الأسبوع؛ تعتمد على تحديث التواريخ إلى LocalDateTime.
        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }
        // الطلب نفسه يجب أن يصل أثناء الأسبوع بدون مهلة إضافية.
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Proof submission time has ended");
        }
        // النشاط أيضا يجب أن ينتمي لفترة الأسبوع نفسه.
        if (activityTime.isBefore(weekStart)) {
            throw new ApiException("Activity time is before this week");
        }
        if (activityTime.isAfter(weekEnd)) {
            throw new ApiException("Activity time is after this week");
        }

        // تاريخ النشاط بدون ساعة لتحديد اليوم المقصود.
        LocalDate activityDate = activityTime.toLocalDate();
        // نبحث من بداية هذا اليوم شاملة إلى بداية اليوم التالي غير شاملة.
        LocalDateTime dayStart = activityDate.atStartOfDay();
        LocalDateTime nextDayStart = activityDate.plusDays(1).atStartOfDay();

        // وجود بروف مقبولة يمنع احتساب نفس المهمة واليوم مرتين.
        boolean hasAcceptedProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
        if (hasAcceptedProof) {
            throw new ApiException("This day already has an accepted proof");
        }

        // وجود بروف قيد المعالجة يمنع رفع بديل قبل صدور القرار.
        boolean hasPendingProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
        if (hasPendingProof) {
            throw new ApiException("A proof for this day is still pending");
        }
        // بروف ينتظر قرار الأدمن لنفس اليوم.
        boolean hasEscalatedProof = proofRepository.existsTaskProof(
                goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ESCALATED");
        if (hasEscalatedProof) {
            throw new ApiException("A proof for this day is awaiting admin review");
        }

        // ننتظر الأدمن إذا كان اعتراض على بروف هذا اليوم معلقا.
        boolean hasPendingProofObjection =
                objectionRepository.existsPendingTaskProofObjection(
                        goalTaskId, commitmentWeekId, dayStart, nextDayStart);
        if (hasPendingProofObjection) {
            throw new ApiException("A proof objection for this day is still pending");
        }

        // الإعفاء المقبول يمنع تقديم إثبات لنفس المهمة واليوم.
        boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, activityDate, "ACCEPTED");
        if (hasAcceptedExcuse) {
            throw new ApiException("This day already has an accepted excuse");
        }

        // ننتظر معالجة العذر قبل استقبال إثبات لنفس اليوم.
        boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, activityDate, "PENDING");
        if (hasPendingExcuse) {
            throw new ApiException("An excuse for this day is still pending");
        }

        // العذر المحول للأدمن ما زال قيد المعالجة.
        boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                goalTaskId, commitmentWeekId, activityDate, "ESCALATED");
        if (hasEscalatedExcuse) {
            throw new ApiException("An excuse for this day is awaiting admin review");
        }

        // الاعتراض على العذر يمنع الإثبات حتى يحسمه الأدمن.
        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingTaskExcuseObjection(
                        goalTaskId, commitmentWeekId, activityDate);
        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        // عدد المرات المطلوبة والمنجزة والمعفاة حسب عدادات المهمة.
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

        // المتبقي بعد طرح الإنجاز ثم الإعفاءات، بدون تعديل أي عداد.
        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        // بعد جميع التشييكات ننشئ سجل البروف الجديد.
        Proof proof = new Proof();
        proof.setType(request.getType());
        proof.setActivityTime(activityTime);
        proof.setEvidenceData(evidenceData);
        // وقت الإرسال والنتيجة وسبب الرفض يحددها النظام.
        proof.setSubmittedAt(now);
        proof.setResult("PENDING");
        proof.setProcessingStatus("WAITING");
        proof.setRejectionReason(null);
        // ربط البروف بالمهمة والأسبوع الصحيحين.
        proof.setGoalTask(task);
        proof.setCommitmentWeek(week);
        proofRepository.save(proof);

        // قرار الذكاء: مقبول (يزيد العداد) أو مرفوض أو يتحول للأدمن.
        proofDecisionService.decide(proof);
    }

    public void updateGoalTaskProof(Integer userId,
                                   Integer proofId,
                                   ProofUpdateRequest request) {

        // معرف المستخدم يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        // نحتاج معرف البروف المراد تعديلها.
        if (proofId == null) {
            throw new ApiException("Proof ID is required");
        }
        // بيانات التعديل فقط؛ ليست بيانات إنشاء بروف جديدة.
        if (request == null) {
            throw new ApiException("Proof update data is required");
        }

        // جلب سجل البروف الموجود، وليس إنشاء سجل جديد.
        Proof proof = proofRepository.findProofById(proofId);
        if (proof == null) {
            throw new ApiException("Proof not found");
        }
        // المهمة المحفوظة التي نريد تقديم إثبات لها.
        GoalTask task = proof.getGoalTask();
        if (task == null) {
            throw new ApiException("Goal task not found");
        }

        // أسبوع الالتزام الذي سيحتسب له الإثبات.
        CommitmentWeek week =
                proof.getCommitmentWeek();
        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        // الهدف المرتبط بالمهمة، وهو كائن Goal الموجود في التصميم.
        Goal goal = task.getGoal();
        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        // نتأكد أن معرف المستخدم المسجل هو نفسه معرف المستخدم صاحب الجول.
        // نضع شرط الملكية مبكرا حتى لا يضيف أو يعدل المستخدم بروفا لأهداف غيره.
        Member member = goal.getMember();
        if (member == null) {
            throw new ApiException("Goal must belong to a member");
        }
        if (member.getUser() == null) {
            throw new ApiException("Goal owner user not found");
        }

        // معرف المستخدم الذي يملك الهدف، من العلاقة المحفوظة في قاعدة البيانات.
        Integer goalOwnerUserId = member.getUser().getId();
        if (!userId.equals(goalOwnerUserId)) {
            throw new ApiException("This goal does not belong to you");
        }

        // لا نعدل بعد بدء التحليل.
        if (!"WAITING".equals(proof.getProcessingStatus())) {
            throw new ApiException("Only proofs waiting for analysis can be updated");
        }
        // القبول والرفض قرارات نهائية لا نغير دليلها بهذه الميثود.
        if (!"PENDING".equals(proof.getResult())) {
            throw new ApiException("Only pending proofs can be updated");
        }
        // لا نغير الدليل المرتبط باعتراض.
        if (proof.getObjection() != null) {
            throw new ApiException("A proof with an objection cannot be updated");
        }


        // التعهد المرتبط بالأسبوع، ويجب أن يكون نفس هدف المهمة.
        Commitment commitment = week.getCommitment();
        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }
        if (!goal.getId().equals(commitment.getId())) {
            throw new ApiException("Goal task does not belong to this goal");
        }

        // رقم أسبوع المهمة ورقم أسبوع الالتزام للمقارنة بينهما.
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

        // المسودة والمنسحب لا يستقبلان إثباتات جديدة.
        if ("DRAFT".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a draft goal");
        }
        if ("WITHDRAWN".equals(goal.getStatus())) {
            throw new ApiException("Cannot submit proof for a withdrawn goal");
        }
        // لا نقبل إضافة إثبات بعد تسوية الأسبوع أو المهمة.
        if ("SETTLED".equals(week.getTrackStatus())) {
            throw new ApiException("This week is settled");
        }
        if ("SETTLED".equals(task.getTrackStatus())) {
            throw new ApiException("This goal task is settled");
        }

        // طريقة الإثبات المحفوظة للمهمة، وليست اختيارا جديدا وقت الرفع.
        String proofMethod = task.getProofMethod();
        if (proofMethod == null) {
            throw new ApiException("Goal task proof method is missing");
        }
        if (!proofMethod.equals(proof.getType())) {
            throw new ApiException("Proof type does not match the task method");
        }

        // بيانات الدليل النصية؛ تحليل محتواها حسب النوع يضاف في مرحلة التحليل.
        String evidenceData = request.getEvidenceData();
        if (evidenceData == null) {
            throw new ApiException("Evidence data is required");
        }
        if (evidenceData.isBlank()) {
            throw new ApiException("Evidence data cannot be empty");
        }

        // وقت تنفيذ النشاط الذي أدخله المستخدم.
        LocalDateTime activityTime = request.getActivityTime();
        if (activityTime == null) {
            throw new ApiException("Activity time is required");
        }

        // وقت النشاط القديم ضروري لمعرفة هل تغير اليوم.
        LocalDateTime oldActivityTime = proof.getActivityTime();
        if (oldActivityTime == null) {
            throw new ApiException("Original activity time is missing");
        }

        // وقت التعديل الحالي بتوقيت السعودية.
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if (activityTime.isAfter(now)) {
            throw new ApiException("Activity time cannot be in the future");
        }

        // حدود الأسبوع؛ تعتمد على تحديث التواريخ إلى LocalDateTime.
        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();
        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }
        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }
        // الطلب نفسه يجب أن يصل أثناء الأسبوع بدون مهلة إضافية.
        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }
        if (now.isAfter(weekEnd)) {
            throw new ApiException("Proof submission time has ended");
        }
        // النشاط أيضا يجب أن ينتمي لفترة الأسبوع نفسه.
        if (activityTime.isBefore(weekStart)) {
            throw new ApiException("Activity time is before this week");
        }
        if (activityTime.isAfter(weekEnd)) {
            throw new ApiException("Activity time is after this week");
        }

        // نقارن التاريخ فقط؛ تغيير الساعة داخل نفس اليوم لا يحتاج فحص التداخل.
        LocalDate oldActivityDate = oldActivityTime.toLocalDate();
        LocalDate newActivityDate = activityTime.toLocalDate();

        /*
         إذا تغير اليوم نتحقق من توفر اليوم الجديد لنفس المهمة.
         إذا تغير الدليل أو الساعة فقط نتجاوز هذه الفحوصات.
        */
        if (!oldActivityDate.equals(newActivityDate)) {
            // نأخذ المعرفات من العلاقات المحفوظة ولا نسمح بتغييرها في الطلب.
            Integer goalTaskId = task.getId();
            Integer commitmentWeekId = week.getId();
            // تاريخ النشاط بدون ساعة لتحديد اليوم المقصود.
            LocalDate activityDate = activityTime.toLocalDate();
            // نبحث من بداية هذا اليوم شاملة إلى بداية اليوم التالي غير شاملة.
            LocalDateTime dayStart = activityDate.atStartOfDay();
            LocalDateTime nextDayStart = activityDate.plusDays(1).atStartOfDay();
    
            // وجود بروف مقبولة يمنع احتساب نفس المهمة واليوم مرتين.
            boolean hasAcceptedProof = proofRepository.existsOtherTaskProof(
                    proofId, goalTaskId, commitmentWeekId, dayStart, nextDayStart, "ACCEPTED");
            if (hasAcceptedProof) {
                throw new ApiException("This day already has an accepted proof");
            }
    
            // وجود بروف قيد المعالجة يمنع رفع بديل قبل صدور القرار.
            boolean hasPendingProof = proofRepository.existsOtherTaskProof(
                    proofId, goalTaskId, commitmentWeekId, dayStart, nextDayStart, "PENDING");
            if (hasPendingProof) {
                throw new ApiException("A proof for this day is still pending");
            }
    
            // ننتظر الأدمن إذا كان اعتراض على بروف هذا اليوم معلقا.
            boolean hasPendingProofObjection =
                    objectionRepository.existsPendingTaskProofObjection(
                            goalTaskId, commitmentWeekId, dayStart, nextDayStart);
            if (hasPendingProofObjection) {
                throw new ApiException("A proof objection for this day is still pending");
            }
    
            // الإعفاء المقبول يمنع تقديم إثبات لنفس المهمة واليوم.
            boolean hasAcceptedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, activityDate, "ACCEPTED");
            if (hasAcceptedExcuse) {
                throw new ApiException("This day already has an accepted excuse");
            }
    
            // ننتظر معالجة العذر قبل استقبال إثبات لنفس اليوم.
            boolean hasPendingExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, activityDate, "PENDING");
            if (hasPendingExcuse) {
                throw new ApiException("An excuse for this day is still pending");
            }
    
            // العذر المحول للأدمن ما زال قيد المعالجة.
            boolean hasEscalatedExcuse = excuseRepository.existsTaskExcuse(
                    goalTaskId, commitmentWeekId, activityDate, "ESCALATED");
            if (hasEscalatedExcuse) {
                throw new ApiException("An excuse for this day is awaiting admin review");
            }
    
            // الاعتراض على العذر يمنع الإثبات حتى يحسمه الأدمن.
            boolean hasPendingExcuseObjection =
                    objectionRepository.existsPendingTaskExcuseObjection(
                            goalTaskId, commitmentWeekId, activityDate);
            if (hasPendingExcuseObjection) {
                throw new ApiException("An excuse objection for this day is still pending");
            }
    
    
        }

        // عدد المرات المطلوبة والمنجزة والمعفاة حسب عدادات المهمة.
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

        // المتبقي بعد طرح الإنجاز ثم الإعفاءات، بدون تعديل أي عداد.
        int remainingCount = requiredCount - completedCount;
        remainingCount = remainingCount - excusedCount;
        if (remainingCount <= 0) {
            throw new ApiException("Task required count has already been fulfilled");
        }

        // بعد جميع التشييكات نعدل بيانات الدليل ووقت النشاط فقط.
        proof.setActivityTime(activityTime);
        proof.setEvidenceData(evidenceData);

        // حفظ نفس السجل؛ لا نغير وقت الإرسال أو النوع أو الحالات أو العلاقات.
        proofRepository.save(proof);
    }

    public void deleteGoalTaskProof(Integer userId, Integer proofId) {

        // معرف المستخدم المسجل يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        // معرف البروف التي يريد المستخدم حذفها.
        if (proofId == null) {
            throw new ApiException("Proof ID is required");
        }

        // جلب البروف المحفوظة.
        Proof proof = proofRepository.findProofById(proofId);

        if (proof == null) {
            throw new ApiException("Proof not found");
        }

        // المهمة المرتبطة بالبروف.
        GoalTask task = proof.getGoalTask();

        if (task == null) {
            throw new ApiException("Goal task not found");
        }

        // الهدف الذي تنتمي إليه المهمة.
        Goal goal = task.getGoal();

        if (goal == null) {
            throw new ApiException("Goal task must belong to a goal");
        }

        // نتأكد أن معرف المستخدم المسجل يطابق المستخدم صاحب الجول.
        // هذا يمنع المستخدم من حذف إثباتات تابعة لأهداف أشخاص آخرين.
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

        // نسمح بالحذف فقط قبل بدء تحليل البروف.
        if (!"WAITING".equals(proof.getProcessingStatus())) {
            throw new ApiException("Only proofs waiting for analysis can be deleted");
        }

        // لا نحذف بروف صدر قرار بقبولها أو رفضها.
        if (!"PENDING".equals(proof.getResult())) {
            throw new ApiException("Only pending proofs can be deleted");
        }

        // نحافظ على الدليل المرتبط باعتراض.
        if (proof.getObjection() != null) {
            throw new ApiException("A proof with an objection cannot be deleted");
        }

        // أسبوع الالتزام المرتبط بالبروف.
        CommitmentWeek week = proof.getCommitmentWeek();

        if (week == null) {
            throw new ApiException("Proof commitment week not found");
        }

        // التعهد المرتبط بالأسبوع.
        Commitment commitment = week.getCommitment();

        if (commitment == null) {
            throw new ApiException("Week must belong to a commitment");
        }

        // التأكد من أن المهمة والأسبوع يتبعان نفس الهدف.
        if (!goal.getId().equals(commitment.getId())) {
            throw new ApiException("Goal task does not belong to this goal");
        }

        // التأكد من تطابق أسبوع المهمة مع أسبوع البروف.
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

        // المسودة والمنسحب لا يسمحان بهذه العملية.
        if ("DRAFT".equals(goal.getStatus())) {
            throw new ApiException("Cannot delete proof for a draft goal");
        }

        if ("WITHDRAWN".equals(goal.getStatus())) {
            throw new ApiException("Cannot delete proof for a withdrawn goal");
        }

        // لا نحذف إثباتا بعد تسوية الأسبوع أو المهمة.
        if ("SETTLED".equals(week.getTrackStatus())) {
            throw new ApiException("This week is settled");
        }

        if ("SETTLED".equals(task.getTrackStatus())) {
            throw new ApiException("This goal task is settled");
        }

        // حدود الأسبوع لتحديد صلاحية وقت الحذف.
        LocalDateTime weekStart = week.getWeekStart();
        LocalDateTime weekEnd = week.getWeekEnd();

        if (weekStart == null) {
            throw new ApiException("Week start is missing");
        }

        if (weekEnd == null) {
            throw new ApiException("Week end is missing");
        }

        // الوقت الحالي بتوقيت السعودية.
        LocalDateTime now =
                LocalDateTime.now(ZoneId.of("Asia/Riyadh"));

        if (now.isBefore(weekStart)) {
            throw new ApiException("This week has not started");
        }

        if (now.isAfter(weekEnd)) {
            throw new ApiException("Proof deletion time has ended");
        }

        // بعد نجاح جميع التشييكات نحذف البروف من قاعدة البيانات.
        // لا نعدل العداد أو المبلغ لأنها لم تقبل بعد.
        proofRepository.delete(proof);
    }


}