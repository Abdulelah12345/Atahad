package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.AI.*;
import com.example.atahad.Dto.In.*;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
import java.time.*;

@Service @RequiredArgsConstructor
public class ProofAttemptService {
    private final ProofService proofService;
    private final ProofDecisionService decisions;
    private final ProofRepository proofs;
    private final CommitmentWeekRepository weeks;
    private final GoalTaskRepository tasks;
    private final ProofEvidenceRepository evidence;
    private final ProofCaptureService captures;
    private final ProofCaptureRepository captureRepository;
    private final ProofOutcomeService outcome;
    private final TimerSessionService timers;
    private final TimerMessageAIService timerAI;
    private final ProofImageAIService imageAI;
    private final ProofTime time;
    private final EntityManager entityManager;

    public Map<String,Object> suggestion(Integer memberId,Integer weekId,Integer taskId) {
        CommitmentWeek week = ownWeek(memberId,weekId);
        String title = week.getCommitment().getTitle();
        if (taskId != null) {
            GoalTask task = tasks.findGoalTaskById(taskId);
            if (task == null || task.getGoal() == null || !task.getGoal().getId().equals(week.getCommitment().getId()) || !Objects.equals(task.getWeekNumber(),week.getWeekNumber())) { throw new ApiException("Task does not belong to this week"); }
            title += " - " + task.getTitle();
        }
        Integer configured = week.getCommitment().getTargetMinutes();
        return Map.of("suggestedMinutes", configured == null ? timerAI.suggestMinutes(title) : configured,"editableBeforeStart",true);
    }

    @Transactional
    public Proof start(Integer memberId,Integer weekId,ProofAttemptStartRequest request) {
        CommitmentWeek week = ownWeek(memberId,weekId);
        GoalTask task = request.getGoalTaskId() == null ? null : tasks.findGoalTaskById(request.getGoalTaskId());
        if (request.getGoalTaskId() != null && task == null) { throw new ApiException("Task not found"); }
        // نتحقق من انتماء المهمة قبل إرسال عنوانها للذكاء أو إنشاء أي جلسة.
        if (task != null) {
            if (task.getGoal() == null || !task.getGoal().getId().equals(week.getCommitment().getId())) {
                throw new ApiException("Task does not belong to this goal");
            }
            if (!Objects.equals(task.getWeekNumber(),week.getWeekNumber())) {
                throw new ApiException("Task does not belong to this week");
            }
        }
        String type = task == null ? week.getCommitment().getProofMethod() : task.getProofMethod();
        if("STEPS".equals(type)) { throw new ApiException("Use the walking steps sync or screenshot endpoint"); }
        // ربط نتيجة الزيارة بالمحاولة الإضافية من مسؤولية الزميلة؛ نترك مسار الزيارة الحالي يعمل مستقلا.
        if ("LOCATION".equals(type)) {
            throw new ApiException("Location sessions await visit integration; use the existing visit flow");
        }
        String title = week.getCommitment().getTitle() + (task == null ? "" : " - " + task.getTitle());
        Integer minutes = request.getTargetMinutes();
        if (minutes == null) { minutes = week.getCommitment().getTargetMinutes(); }
        if (type.equals("TIMER") && minutes == null) { minutes = timerAI.suggestMinutes(title); }
        // نجهز التشجيع قبل حجز الأسبوع، كي لا يبقى القفل أثناء طلب الذكاء.
        String messages = type.equals("TIMER") ? timerAI.messages(title) : "";
        boolean withPhotos = false;
        if (request.getBeforeAfter() != null) { withPhotos = request.getBeforeAfter(); }
        if (withPhotos && request.getBeforeCaptureId() == null) { throw new ApiException("Take the before photo before starting"); }
        entityManager.lock(week,LockModeType.PESSIMISTIC_WRITE);
        ProofRequest input = new ProofRequest(); input.setType(type); input.setActivityTime(time.now()); input.setEvidenceData("Awaiting session evidence");
        Proof proof;
        if (task == null) { proof = decisions.prepareHabitProof(memberId,weekId,input); }
        else { proof = proofService.prepareGoalTaskProof(memberId,task.getId(),weekId,input); }
        proof.setBeforeAfterEnabled(withPhotos);
        LocalDateTime deadline = type.equals("TIMER") ? time.now().toLocalDate().plusDays(1).atStartOfDay() : week.getWeekEnd();
        proof.setAttemptDeadline(deadline); proofs.saveAndFlush(proof);
        outcome.primary(proof,"PENDING","بانتظار الدليل الأساسي");
        if (withPhotos) {
            ProofCapture before = captures.use(memberId,request.getBeforeCaptureId(),"BEFORE",proof.getId());
            ProofEvidence photos = new ProofEvidence(); photos.setProof(proof); photos.setType("BEFORE_AFTER");
            photos.setBeforeCaptureId(before.getId()); photos.setCreatedAt(time.now()); evidence.save(photos);
        }
        if (type.equals("TIMER")) { timers.start(proof,minutes,messages); }
        return proof;
    }

    @Transactional
    public Proof submit(Integer memberId,Integer proofId,String data) {
        Proof proof = captures.ownProof(memberId,proofId);
        checkDeadline(proof);
        if (proof.getType().equals("TIMER")) { throw new ApiException("Use the server timer actions"); }
        if (data == null || data.isBlank()) { throw new ApiException("Evidence is required"); }
        // تحليل الدليل يستخدم نسخة غير مدارة؛ لا يكتب نتيجة قديمة فوق نجاح دليل آخر أثناء انتظار الذكاء.
        entityManager.detach(proof);
        if (proof.getType().equals("PHOTO")) {
            // صورة مفردة أيضا من مسار التصوير، وليس رابطا عشوائيا أو صورة من المعرض.
            int captureId;
            try { captureId=Integer.parseInt(data.trim()); } catch(NumberFormatException ex) { throw new ApiException("Send the camera capture ID"); }
            data = captures.use(memberId,captureId,"PHOTO",proofId).getImageData();
            proof.setPrimaryCaptureId(captureId);
        }
        proof.setEvidenceData(data); decisions.decide(proof);
        return proofs.findProofById(proofId);
    }

    @Transactional
    public Proof after(Integer memberId,Integer proofId,Integer captureId) {
        Proof proof = captures.ownProof(memberId,proofId); checkDeadline(proof);
        ProofEvidence photos = evidence.findFirstByProofIdAndType(proofId,"BEFORE_AFTER");
        if (photos == null) { throw new ApiException("Before/after must be chosen at the beginning"); }
        if (photos.getAfterCaptureId() != null) { throw new ApiException("The after photo was already submitted"); }
        ProofCapture before = captureRepository.findById(photos.getBeforeCaptureId()).orElseThrow();
        ProofCapture after = captures.use(memberId,captureId,"AFTER",proofId);
        if (after.getCapturedAt().isBefore(proof.getActivityTime())) { throw new ApiException("Take the after photo after starting"); }
        if (after.getFingerprint().equals(before.getFingerprint())) { throw new ApiException("Before and after must be different captures"); }
        String title = proof.getCommitmentWeek().getCommitment().getTitle() + (proof.getGoalTask()==null ? "" : " - " + proof.getGoalTask().getTitle());
        String answer = imageAI.compare(title,before.getImageData(),after.getImageData());
        String result = imageAI.field(answer,"DECISION");
        if (!List.of("ACCEPTED","REJECTED","ESCALATED").contains(result)) { result="ESCALATED"; }
        // لا نحجز صف دليل الصور أثناء انتظار الذكاء، حتى يستطيع المؤقت حفظ نجاحه.
        // بعد الرد نحجز الأسبوع أولا، ثم نعيد فحص الدليل ونحفظ النتيجة بنفس ترتيب الأقفال.
        entityManager.lock(proof.getCommitmentWeek(),LockModeType.PESSIMISTIC_WRITE);
        entityManager.refresh(photos,LockModeType.PESSIMISTIC_WRITE);
        if (photos.getAfterCaptureId() != null) { throw new ApiException("The after photo was already submitted"); }
        photos.setAfterCaptureId(after.getId());
        evidence.saveAndFlush(photos);
        outcome.record(proof,"BEFORE_AFTER",result,imageAI.field(answer,"REASON"));
        return proof;
    }

    @Transactional
    public Proof skipPhotos(Integer memberId,Integer proofId) {
        Proof proof=captures.ownProof(memberId,proofId);
        ProofEvidence photos=evidence.findFirstByProofIdAndType(proofId,"BEFORE_AFTER");
        if (photos==null || !photos.getResult().equals("PENDING")) { throw new ApiException("No optional photos are waiting"); }
        outcome.record(proof,"BEFORE_AFTER","REJECTED","اختار المستخدم المتابعة بدون الصور الإضافية");
        return proof;
    }

    public Map<String,Object> state(Integer memberId,Integer proofId) {
        Proof proof = captures.ownProof(memberId,proofId);
        Map<String,Object> result = new LinkedHashMap<>(); result.put("proof",proof);
        result.put("weekId",proof.getCommitmentWeek().getId());
        result.put("goalTaskId",proof.getGoalTask()==null?null:proof.getGoalTask().getId());
        result.put("goalTitle", proof.getGoalTask() == null ? null : proof.getCommitmentWeek().getCommitment().getTitle());
        result.put("taskTitle", proof.getGoalTask() == null ? null : proof.getGoalTask().getTitle());
        // زر الاعتراض يظهر فقط عندما يسمح القرار والمهلة وعدم وجود اعتراض سابق.
        result.put("canObject", "REJECTED".equals(proof.getResult()) && proof.getDecidedAt() != null
                && proof.getObjection() == null && !time.now().isAfter(proof.getDecidedAt().plusHours(48)));
        result.put("evidence",evidence.findByProofIdOrderById(proofId)); result.put("timer",timers.findByProofId(proofId));
        return result;
    }
    public CommitmentWeek ownWeek(Integer memberId,Integer weekId) {
        CommitmentWeek week=weeks.findCommitmentWeekById(weekId);
        if (week==null) { throw new ApiException("Week not found"); }
        if (!week.getCommitment().getMember().getId().equals(memberId)) { throw new org.springframework.security.access.AccessDeniedException("Not your week"); }
        return week;
    }
    private void checkDeadline(Proof proof) {
        if (proof.getAttemptDeadline()==null) { throw new ApiException("Start a managed proof attempt first"); }
        if (!time.now().isBefore(proof.getAttemptDeadline())) { throw new ApiException("The activity submission time ended"); }
        if (proof.getResult().equals("ACCEPTED")) { throw new ApiException("This activity already succeeded"); }
    }
}
