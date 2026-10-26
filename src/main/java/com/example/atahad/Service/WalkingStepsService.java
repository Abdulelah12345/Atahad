package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.*;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import jakarta.persistence.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.access.AccessDeniedException;
import java.time.*;
import java.util.*;
import java.io.ByteArrayInputStream;
import javax.imageio.ImageIO;

@Service @RequiredArgsConstructor
public class WalkingStepsService {
    public static final String ZONE = "Asia/Riyadh";
    private final EntityManager entityManager;
    private final StepConnectionRepository connections;
    private final DailyStepsRepository dailySteps;
    private final ProofRepository proofs;
    private final ExcuseRepository excuses;
    private final ObjectionRepository objections;
    private final ProofOutcomeService outcome;
    private final CommitmentWeekService weeks;
    private final ProofTime time;

    @Transactional(readOnly=true)
    public Map<String,Object> connection(Integer memberId) {
        StepConnection c=connections.findById(memberId).orElse(null);
        if(c==null) { return Map.of("status","NOT_CONNECTED","zoneId",ZONE); }
        String status=c.getStatus();
        if("READY".equals(status) && c.getCheckedAt().isBefore(time.now().minusHours(24))) { status="CHECK_REQUIRED"; }
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("status",status);result.put("source",c.getSource());result.put("checkedAt",c.getCheckedAt());
        result.put("lastSuccessfulReadAt",c.getLastSuccessfulReadAt());result.put("zoneId",ZONE);
        result.put("trust","DEVICE_REPORTED");
        return result;
    }

    @Transactional
    public Map<String,Object> check(Integer memberId, StepConnectionRequest request) {
        Member member=lockMember(memberId);
        if("READY".equals(request.getStatus()) && (request.getStepsRead()==null
                || !time.now().toLocalDate().equals(request.getReadDay()))) {
            throw new ApiException("READY requires a successful read of today's steps; zero is allowed");
        }
        StepConnection c=connections.findById(memberId).orElseGet(StepConnection::new);
        c.setMember(member);c.setMemberId(memberId);c.setSource(request.getSource());c.setDeviceId(request.getDeviceId());
        c.setStatus(request.getStatus());c.setCheckedAt(time.now());
        if("READY".equals(c.getStatus())) { c.setLastSuccessfulReadAt(time.now()); }
        connections.saveAndFlush(c);
        return connection(memberId);
    }

    /** Checked before activation, including when the user chooses screenshot evidence. */
    @Transactional(readOnly=true)
    public void checkActivation(Integer memberId, Commitment commitment) {
        if(!"STEPS".equals(commitment.getProofMethod())) { return; }
        if("SCREENSHOT".equals(commitment.getStepEvidenceMode())) { return; }
        StepConnection c=connections.findById(memberId).orElse(null);
        if(c==null || !"READY".equals(c.getStatus()) || c.getCheckedAt().isBefore(time.now().minusHours(24))) {
            throw new ApiException("Check the steps connection before starting, or choose SCREENSHOT evidence");
        }
    }

    @Transactional
    public Map<String,Object> sync(Integer memberId,Integer weekId,StepSyncRequest request) {
        CommitmentWeek week=ownWeek(memberId,weekId,request.getDay());
        Member member=lockMember(memberId);
        if(!"HEALTH_DATA".equals(week.getCommitment().getStepEvidenceMode())) {
            throw new ApiException("This commitment uses screenshot evidence");
        }
        StepConnection c=connections.findById(memberId).orElse(null);
        if(c==null || !"READY".equals(c.getStatus()) || !c.getSource().equals(request.getSource())
                || !c.getDeviceId().equals(request.getDeviceId())) {
            throw new ApiException("Recheck the connection on this device before syncing");
        }
        if(!ZONE.equals(request.getZoneId()) || request.getObservedAt().isAfter(time.now())
                || request.getObservedAt().isBefore(request.getDay().atStartOfDay())
                || request.getObservedAt().isBefore(time.now().minusHours(24))) {
            throw new ApiException("Invalid steps observation time or time zone");
        }
        DailySteps day=dailySteps.findByMemberIdAndDay(memberId,request.getDay());
        if(day==null) { day=new DailySteps();day.setMember(member);day.setDay(request.getDay()); }
        else if(!day.getSource().equals(request.getSource()) || !day.getDeviceId().equals(request.getDeviceId())) {
            throw new ApiException("Use the same data source for this day to avoid counting devices twice");
        }
        // A retry or an older reading must not overwrite a more recent daily total.
        if(day.getObservedAt()==null || request.getObservedAt().isAfter(day.getObservedAt())) {
            day.setTotal(request.getTotal());day.setSource(request.getSource());day.setDeviceId(request.getDeviceId());
            day.setZoneId(ZONE);day.setObservedAt(request.getObservedAt());day.setSyncedAt(time.now());
            dailySteps.saveAndFlush(day);
        } else if(request.getObservedAt().equals(day.getObservedAt()) && !request.getTotal().equals(day.getTotal())) {
            throw new ApiException("Conflicting totals for the same observation time");
        }
        c.setLastSuccessfulReadAt(time.now());c.setCheckedAt(time.now());connections.save(c);
        Proof proof=findDayProof(week,request.getDay());
        if(proof==null && weeks.remainingTimes(week)>0 && !hasExcuse(week,request.getDay())) {
            proof=newProof(week,request.getDay());
        }
        if(proof!=null && !"ACCEPTED".equals(proof.getResult()) && !hasExcuse(week,request.getDay())) {
            proof.setEvidenceData("source="+day.getSource()+";day="+day.getDay()+";total="+day.getTotal()+";trust=DEVICE_REPORTED");
            proofs.saveAndFlush(proof);
            boolean reached=day.getTotal()>=week.getCommitment().getTargetSteps();
            outcome.primary(proof,reached?"ACCEPTED":"PENDING",reached?"اكتمل هدف خطوات اليوم":"بانتظار اكتمال خطوات اليوم");
        }
        return progress(week,request.getDay(),day,proof);
    }

    @Transactional
    public Map<String,Object> screenshot(Integer memberId,Integer weekId,StepScreenshotRequest request) {
        CommitmentWeek week=ownWeek(memberId,weekId,request.getDay());
        lockMember(memberId);
        validateImage(request.getImageData());
        Proof proof=findDayProof(week,request.getDay());
        if(proof!=null && "ACCEPTED".equals(proof.getResult())) {
            return progress(week,request.getDay(),dailySteps.findByMemberIdAndDay(memberId,request.getDay()),proof);
        }
        if(hasExcuse(week,request.getDay()) || weeks.remainingTimes(week)<=0) { throw new ApiException("This day or week is already covered"); }
        if(proof==null) { proof=newProof(week,request.getDay()); }
        var existing=entityManager.createQuery("select e from ProofEvidence e where e.proof.id=:id and e.type='STEP_SCREENSHOT'",ProofEvidence.class)
                .setParameter("id",proof.getId()).getResultList();
        if(!existing.isEmpty()) { throw new ApiException("A screenshot was already submitted for this day"); }
        // Keep the image out of public proof responses; admin review reads evidence.data.
        ProofEvidence image=new ProofEvidence();image.setProof(proof);image.setType("STEP_SCREENSHOT");
        image.setData(request.getImageData());image.setCreatedAt(time.now());entityManager.persist(image);entityManager.flush();
        proof.setEvidenceData("Screenshot of daily steps for "+request.getDay()+"; target="+week.getCommitment().getTargetSteps());
        proofs.saveAndFlush(proof);
        outcome.record(proof,"STEP_SCREENSHOT","ESCALATED","تحقق من تاريخ الصورة ومجموع خطوات اليوم قبل القبول");
        // Supersede waiting health data so a rejected screenshot can receive a final review outcome.
        outcome.primary(proof,"ESCALATED","بانتظار مراجعة صورة خطوات اليوم");
        return progress(week,request.getDay(),dailySteps.findByMemberIdAndDay(memberId,request.getDay()),proof);
    }

    @Transactional(readOnly=true)
    public Map<String,Object> progress(Integer memberId,Integer weekId,LocalDate day) {
        CommitmentWeek week=entityManager.find(CommitmentWeek.class,weekId);
        checkOwner(memberId,week);
        if(!"STEPS".equals(week.getCommitment().getProofMethod()) || day.isBefore(week.getWeekStart().toLocalDate())
                || day.isAfter(week.getWeekEnd().toLocalDate())) { throw new ApiException("Invalid steps day"); }
        return progress(week,day,dailySteps.findByMemberIdAndDay(memberId,day),findDayProof(week,day));
    }

    private Map<String,Object> progress(CommitmentWeek week,LocalDate day,DailySteps data,Proof proof) {
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("day",day);result.put("zoneId",ZONE);result.put("targetSteps",week.getCommitment().getTargetSteps());
        result.put("evidenceMode",week.getCommitment().getStepEvidenceMode());
        result.put("weekStart",week.getWeekStart());result.put("weekEnd",week.getWeekEnd());
        result.put("totalSteps",data==null?null:data.getTotal());result.put("lastSyncedAt",data==null?null:data.getSyncedAt());
        result.put("proofId",proof==null?null:proof.getId());
        boolean screenshotSubmitted=proof!=null && entityManager.createQuery(
                "select count(e) from ProofEvidence e where e.proof.id=:id and e.type='STEP_SCREENSHOT'",Long.class)
                .setParameter("id",proof.getId()).getSingleResult()>0;
        result.put("screenshotSubmitted",screenshotSubmitted);
        String status=proof==null?"AWAITING_SYNC":proof.getResult();
        if("PENDING".equals(status)) { status=data==null?"AWAITING_SYNC":"IN_PROGRESS"; }
        if(("AWAITING_SYNC".equals(status) || "IN_PROGRESS".equals(status))
                && !time.now().isBefore(day.plusDays(2).atStartOfDay())) { status="SYNC_WINDOW_ENDED"; }
        if(proof==null && hasExcuse(week,day)) { status="COVERED_BY_EXCUSE"; }
        result.put("status",status);result.put("syncDeadline",day.plusDays(2).atStartOfDay());
        result.put("trust","DEVICE_REPORTED");return result;
    }

    private Member lockMember(Integer memberId) {
        Member member=entityManager.find(Member.class,memberId,LockModeType.PESSIMISTIC_WRITE);
        if(member==null) { throw new ApiException("Member not found"); }
        entityManager.refresh(member,LockModeType.PESSIMISTIC_WRITE);return member;
    }
    private CommitmentWeek ownWeek(Integer memberId,Integer weekId,LocalDate day) {
        // Query locking avoids the eager inverse one-to-one loader used by find(..., lockMode).
        CommitmentWeek week=entityManager.createQuery("select w from CommitmentWeek w where w.id=:id",CommitmentWeek.class)
                .setParameter("id",weekId).setLockMode(LockModeType.PESSIMISTIC_WRITE).getResultStream().findFirst().orElse(null);
        checkOwner(memberId,week);
        Commitment c=week.getCommitment();
        if(!"STEPS".equals(c.getProofMethod()) || c.getGroupGoal()!=null || !(org.hibernate.Hibernate.unproxy(c) instanceof Habit)) {
            throw new ApiException("Steps currently support personal habits only");
        }
        if(!"ACTIVE".equals(c.getStatus()) || day.isBefore(week.getWeekStart().toLocalDate())
                || day.isAfter(week.getWeekEnd().toLocalDate()) || day.isAfter(time.now().toLocalDate())
                || !time.now().isBefore(day.plusDays(2).atStartOfDay())) { throw new ApiException("Steps submission window has ended or day is invalid"); }
        if(objections.existsPendingProofObjection(weekId,null,day.atStartOfDay(),day.plusDays(1).atStartOfDay())
                || objections.existsPendingExcuseObjection(weekId,null,day)) { throw new ApiException("Wait for the pending objection"); }
        return week;
    }
    private void checkOwner(Integer memberId,CommitmentWeek week) {
        if(week==null) { throw new ApiException("Week not found"); }
        if(!memberId.equals(week.getCommitment().getMember().getId())) { throw new AccessDeniedException("You can only access your own steps"); }
    }
    private Proof findDayProof(CommitmentWeek week,LocalDate day) {
        return proofs.findProofsByCommitmentWeekId(week.getId()).stream()
                .filter(p->p.getGoalTask()==null && p.getActivityTime().toLocalDate().equals(day))
                .sorted(Comparator.comparing((Proof p)->"ACCEPTED".equals(p.getResult())).reversed().thenComparing(Proof::getId))
                .findFirst().orElse(null);
    }
    private boolean hasExcuse(CommitmentWeek week,LocalDate day) {
        return excuses.findExcusesByCommitmentWeekId(week.getId()).stream().anyMatch(e->day.equals(e.getExcuseDate()) && !"REJECTED".equals(e.getStatus()));
    }
    private Proof newProof(CommitmentWeek week,LocalDate day) {
        Proof p=new Proof();p.setType("STEPS");p.setCommitmentWeek(week);p.setResult("PENDING");p.setProcessingStatus("WAITING");
        // The first day's total includes the whole day, but its proof timestamp stays inside the week.
        p.setActivityTime(day.equals(week.getWeekStart().toLocalDate())?week.getWeekStart():day.atStartOfDay());
        p.setSubmittedAt(time.now());p.setEvidenceData("Awaiting daily steps");
        p.setAttemptDeadline(day.plusDays(2).atStartOfDay());
        return proofs.saveAndFlush(p);
    }
    private void validateImage(String data) {
        if(data==null || data.length()>3000000 || !(data.startsWith("data:image/png;base64,") || data.startsWith("data:image/jpeg;base64,"))) {
            throw new ApiException("Send a PNG or JPEG screenshot, at most 3 MB encoded");
        }
        try(var input=ImageIO.createImageInputStream(new ByteArrayInputStream(Base64.getDecoder().decode(data.substring(data.indexOf(',')+1))))) {
            var readers=ImageIO.getImageReaders(input);
            if(!readers.hasNext()) { throw new IllegalArgumentException(); }
            var reader=readers.next();
            try {
                if(!List.of("png","jpeg","jpg").contains(reader.getFormatName().toLowerCase(Locale.ROOT))) { throw new IllegalArgumentException(); }
                reader.setInput(input);long pixels=(long)reader.getWidth(0)*reader.getHeight(0);
                if(pixels<1 || pixels>20000000) { throw new IllegalArgumentException(); }
            }
            finally { reader.dispose(); }
        } catch(Exception e) { throw new ApiException("Invalid screenshot image"); }
    }
}
