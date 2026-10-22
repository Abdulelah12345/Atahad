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

    public List<Objection> getAllObjections() {
        return objectionRepository.findAll();
    }

    public Objection getObjectionById(Integer userId, Integer objectionId) {

        // معرف المستخدم المسجل يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        if (objectionId == null) {
            throw new ApiException("Objection ID is required");
        }

        // جلب الاعتراض المطلوب قبل التحقق من صاحبه.
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

        // نتأكد أن معرف المستخدم المسجل يطابق صاحب الاعتراض.
        // يمنع هذا الشرط عرض اعتراض خاص بمستخدم آخر بمجرد معرفة معرفه.
        Integer ownerUserId = member.getUser().getId();

        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This objection does not belong to you");
        }

        return objection;
    }

    public void addProofObjection(Integer userId, Integer proofId,
                                      ObjectionRequest request) {

        // هوية المستخدم تؤخذ من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        // معرف السجل الذي صدر عليه قرار الذكاء.
        if (proofId == null) {
            throw new ApiException("Proof ID is required");
        }
        if (request == null) {
            throw new ApiException("Objection data is required");
        }

        // سبب الاعتراض يدخله المستخدم، ولا يستطيع تحديد القرار أو الوقت.
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

        // نصل للمالك من الأسبوع والتعهد، لدعم الأهداف والعادات.
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

        // نتأكد أن معرف المستخدم المسجل هو نفسه صاحب التعهد.
        // يمنع هذا الشرط تقديم اعتراض على قرارات تخص شخصا آخر.
        Integer ownerUserId = member.getUser().getId();
        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This proof does not belong to you");
        }

        // يجب أن ينتهي التحليل قبل الاعتراض على قراره.
        if (!"FINISHED".equals(proof.getProcessingStatus())) {
            throw new ApiException("Proof analysis has not finished");
        }
        String status = proof.getResult();

        // نفحص null قبل استخدام equals بالطريقة المتفق عليها.
        if (status == null) {
            throw new ApiException("Decision status is missing");
        }
        boolean hasDecision = status.equals("REJECTED");
        if (!hasDecision) {
            throw new ApiException("Only rejected decisions can be objected to");
        }

        // مهلة الاعتراض تبدأ من القرار، وليس من إرسال الإثبات أو العذر.
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

        // اعتراض واحد لكل قرار حسب علاقة الواحد لواحد الحالية.
        if (proof.getObjection() != null) {
            throw new ApiException("An objection already exists for this proof");
        }

        // نحدد المهمة واليوم لفحص الطلبات المتعارضة.
        // null للتاسك يعني أن السجل يخص عادة داخل هذا الأسبوع.
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

        // لا نفتح اعتراضا أثناء وجود إثبات بديل قيد المعالجة أو مقبول.
        boolean hasBlockingProof = objectionRepository.existsBlockingProof(
                weekId, goalTaskId, dayStart, nextDayStart);
        if (hasBlockingProof) {
            throw new ApiException("This day already has a pending or accepted proof");
        }

        // لا نفتح اعتراضا أثناء معالجة عذر آخر أو بعد قبول إعفاء لنفس اليوم.
        boolean hasBlockingExcuse = objectionRepository.existsBlockingExcuse(
                weekId, goalTaskId, activityDate);
        if (hasBlockingExcuse) {
            throw new ApiException("This day already has an active or accepted excuse");
        }

        // منع إضافة اعتراض أثناء معالجة اعتراض على بروف لنفس المهمة واليوم.
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

        // منع إضافة اعتراض أثناء معالجة اعتراض على عذر لنفس المهمة واليوم.
        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingExcuseObjection(
                        weekId,
                        goalTaskId,
                        activityDate
                );

        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        // سبب قرار الذكاء يؤخذ من السجل المحفوظ.
        String aiReason = proof.getRejectionReason();

        // بعد جميع التشييكات ننشئ الاعتراض ونربطه بنوع واحد فقط.
        Objection objection = new Objection();
        objection.setReason(reason);
        objection.setAiReason(aiReason);
        objection.setCreatedAt(now);
        objection.setStatus("PENDING");
        objection.setMember(member);
        objection.setProof(proof);
        objection.setExcuse(null);
        objection.setPenalty(null);
        objection.setAdmin(null);

        // الحفظ فقط؛ قرار الأدمن لاحقا هو الذي يعالج المبلغ والعداد.
        objectionRepository.save(objection);
    }

    public void addExcuseObjection(Integer userId, Integer excuseId,
                                      ObjectionRequest request) {

        // هوية المستخدم تؤخذ من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }
        // معرف السجل الذي صدر عليه قرار الذكاء.
        if (excuseId == null) {
            throw new ApiException("Excuse ID is required");
        }
        if (request == null) {
            throw new ApiException("Objection data is required");
        }

        // سبب الاعتراض يدخله المستخدم، ولا يستطيع تحديد القرار أو الوقت.
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

        // نصل للمالك من الأسبوع والتعهد، لدعم الأهداف والعادات.
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

        // نتأكد أن معرف المستخدم المسجل هو نفسه صاحب التعهد.
        // يمنع هذا الشرط تقديم اعتراض على قرارات تخص شخصا آخر.
        Integer ownerUserId = member.getUser().getId();
        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This excuse does not belong to you");
        }

        // لا نقبل اعتراضا بهذه الميثود على قرار صادر من الأدمن.
        if (excuse.getAdmin() != null) {
            throw new ApiException("This excuse was reviewed by an admin");
        }
        if (Boolean.TRUE.equals(excuse.getForwardedToAdmin())) {
            throw new ApiException("This excuse is assigned to admin review");
        }
        String status = excuse.getStatus();

        // نفحص null قبل استخدام equals بالطريقة المتفق عليها.
        if (status == null) {
            throw new ApiException("Decision status is missing");
        }
        boolean hasDecision = status.equals("REJECTED");
        if (!hasDecision) {
            throw new ApiException("Only rejected decisions can be objected to");
        }

        // مهلة الاعتراض تبدأ من القرار، وليس من إرسال الإثبات أو العذر.
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

        // اعتراض واحد لكل قرار حسب علاقة الواحد لواحد الحالية.
        if (excuse.getObjection() != null) {
            throw new ApiException("An objection already exists for this excuse");
        }

        // نحدد المهمة واليوم لفحص الطلبات المتعارضة.
        // null للتاسك يعني أن السجل يخص عادة داخل هذا الأسبوع.
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

        // لا نفتح اعتراضا أثناء وجود إثبات بديل قيد المعالجة أو مقبول.
        boolean hasBlockingProof = objectionRepository.existsBlockingProof(
                weekId, goalTaskId, dayStart, nextDayStart);
        if (hasBlockingProof) {
            throw new ApiException("This day already has a pending or accepted proof");
        }

        // لا نفتح اعتراضا أثناء معالجة عذر آخر أو بعد قبول إعفاء لنفس اليوم.
        boolean hasBlockingExcuse = objectionRepository.existsBlockingExcuse(
                weekId, goalTaskId, activityDate);
        if (hasBlockingExcuse) {
            throw new ApiException("This day already has an active or accepted excuse");
        }

        // منع إضافة اعتراض أثناء معالجة اعتراض على بروف لنفس المهمة واليوم.
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

        // منع إضافة اعتراض أثناء معالجة اعتراض على عذر لنفس المهمة واليوم.
        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingExcuseObjection(
                        weekId,
                        goalTaskId,
                        activityDate
                );

        if (hasPendingExcuseObjection) {
            throw new ApiException("An excuse objection for this day is still pending");
        }

        // سبب قرار الذكاء يؤخذ من السجل المحفوظ.
        String aiReason = excuse.getAiAssessment();

        // بعد جميع التشييكات ننشئ الاعتراض ونربطه بنوع واحد فقط.
        Objection objection = new Objection();
        objection.setReason(reason);
        objection.setAiReason(aiReason);
        objection.setCreatedAt(now);
        objection.setStatus("PENDING");
        objection.setMember(member);
        objection.setExcuse(excuse);
        objection.setProof(null);
        objection.setPenalty(null);
        objection.setAdmin(null);

        // الحفظ فقط؛ قرار الأدمن لاحقا هو الذي يعالج المبلغ والعداد.
        objectionRepository.save(objection);
    }




    // تعدّل السبب فقط لصاحب الاعتراض، ما دام قيد الانتظار ولم يبدأ الأدمن مراجعته، بدون إعادة فحص مهلة الـ٤٨ ساعة.
    public void updateObjection(Integer userId,
                                Integer objectionId,
                                ObjectionRequest request) {

        // معرف المستخدم المسجل يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        // معرف الاعتراض الذي يريد المستخدم تعديله.
        if (objectionId == null) {
            throw new ApiException("Objection ID is required");
        }

        if (request == null) {
            throw new ApiException("Objection update data is required");
        }

        // جلب الاعتراض المحفوظ من قاعدة البيانات.
        Objection objection =
                objectionRepository.findObjectionById(objectionId);

        if (objection == null) {
            throw new ApiException("Objection not found");
        }

        // العضو صاحب الاعتراض.
        Member member = objection.getMember();

        if (member == null) {
            throw new ApiException("Objection owner not found");
        }

        if (member.getUser() == null) {
            throw new ApiException("Objection owner user not found");
        }

        // نتأكد أن المستخدم المسجل هو نفسه صاحب الاعتراض.
        // يمنع هذا الشرط تعديل اعتراضات مستخدم آخر.
        Integer ownerUserId = member.getUser().getId();

        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This objection does not belong to you");
        }

        // لا نعدل اعتراضا صدر قرار بقبوله أو رفضه.
        if (!"PENDING".equals(objection.getStatus())) {
            throw new ApiException("Only pending objections can be updated");
        }

        // بدء مراجعة الأدمن يمنع التعديل حتى لو بقيت الحالة PENDING.
        if (objection.getReviewStartedAt() != null) {
            throw new ApiException("This objection is already under review");
        }

        // السبب الجديد الذي أرسله المستخدم، باستخدام نفس DTO الإضافة.
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

        // لا نفحص مهلة 48 ساعة مجددا؛ هي مهلة تقديم الاعتراض فقط.
        // بعد جميع التشييكات نعدل السبب دون تغيير الوقت أو الحالة أو العلاقات.
        objection.setReason(reason);

        // حفظ التعديل على نفس الاعتراض.
        objectionRepository.save(objection);
    }

    // يحذف صاحب الاعتراض طلبه قبل بدء مراجعة الأدمن، دون إعادة فحص مهلة التقديم.
    public void deleteObjection(Integer userId, Integer objectionId) {

        // معرف المستخدم المسجل يأتي من جلسة الدخول.
        if (userId == null) {
            throw new ApiException("User ID is required");
        }

        // معرف الاعتراض المراد حذفه.
        if (objectionId == null) {
            throw new ApiException("Objection ID is required");
        }

        // جلب الاعتراض المحفوظ.
        Objection objection =
                objectionRepository.findObjectionById(objectionId);

        if (objection == null) {
            throw new ApiException("Objection not found");
        }

        // العضو صاحب الاعتراض.
        Member member = objection.getMember();

        if (member == null) {
            throw new ApiException("Objection owner not found");
        }

        if (member.getUser() == null) {
            throw new ApiException("Objection owner user not found");
        }

        // نتأكد أن معرف المستخدم المسجل يطابق صاحب الاعتراض.
        // يمنع هذا الشرط حذف اعتراضات مستخدم آخر.
        Integer ownerUserId = member.getUser().getId();

        if (!userId.equals(ownerUserId)) {
            throw new ApiException("This objection does not belong to you");
        }

        // نفحص وجود الحالة قبل استخدام equals عليها.
        String status = objection.getStatus();

        if (status == null) {
            throw new ApiException("Objection status is missing");
        }

        // لا نحذف اعتراضا صدر قرار بقبوله أو رفضه.
        boolean isPending = status.equals("PENDING");

        if (!isPending) {
            throw new ApiException("Only pending objections can be deleted");
        }

        // لا نحذف الاعتراض بعد بدء مراجعة الأدمن.
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