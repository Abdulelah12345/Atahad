package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.List;

@Service @RequiredArgsConstructor
public class TimerSessionService {
    private final TimerSessionRepository sessions;
    private final ProofOutcomeService outcome;
    private final ProofTime time;

    @Transactional
    public TimerSession start(Proof proof,int minutes,String messages) {
        if (!proof.getType().equals("TIMER")) { throw new ApiException("This activity is not a timer"); }
        if (minutes < 1 || minutes > 600) { throw new ApiException("Minutes must be between 1 and 600"); }
        if (sessions.findByProofId(proof.getId()) != null) { throw new ApiException("A timer already exists for this attempt"); }
        TimerSession timer = new TimerSession();
        timer.setProof(proof); timer.setRequiredSeconds(minutes*60); timer.setLastStartedAt(time.now());
        timer.setDeadline(proof.getAttemptDeadline()); timer.setMessages(messages);
        return sessions.save(timer);
    }

    @Transactional
    public TimerSession action(Integer memberId,Integer id,String action,Integer minutes,String feedback) {
        TimerSession timer = sessions.findForUpdate(id);
        if (timer == null) { throw new ApiException("Timer not found"); }
        if (!timer.getProof().getCommitmentWeek().getCommitment().getMember().getId().equals(memberId)) {
            throw new org.springframework.security.access.AccessDeniedException("Not your timer");
        }
        sync(timer);
        if (action.equals("feedback")) {
            if (feedback == null || !List.of("EASY","OK","TIRING").contains(feedback)) { throw new ApiException("Invalid feedback"); }
            timer.setFeedback(feedback); return sessions.save(timer);
        }
        if (action.equals("state")) { return timer; }
        if (!time.now().isBefore(timer.getDeadline()) || timer.getStatus().equals("EXPIRED")) { throw new ApiException("This activity day has ended"); }
        if (action.equals("pause") || action.equals("finish")) {
            timer.setLastStartedAt(null);
            timer.setStatus(timer.getRequiredReachedAt() != null && action.equals("finish") ? "FINISHED" : "PAUSED");
        } else if (action.equals("resume")) {
            if (!timer.getStatus().equals("PAUSED")) { throw new ApiException("Only a paused session can resume"); }
            if (timer.getElapsedSeconds() >= timer.getRequiredSeconds() + timer.getExtensionSeconds()) { throw new ApiException("Choose an optional extension first"); }
            timer.setStatus("RUNNING"); timer.setLastStartedAt(time.now());
        } else if (action.equals("extend")) {
            if (timer.getRequiredReachedAt() == null) { throw new ApiException("Finish the original duration before extending"); }
            if (minutes == null || minutes < 1 || minutes > 600) { throw new ApiException("Extension must be 1 to 600 minutes"); }
            timer.setExtensionSeconds(Math.addExact(timer.getExtensionSeconds(),minutes*60));
            if (!timer.getStatus().equals("RUNNING")) { timer.setLastStartedAt(time.now()); }
            timer.setStatus("RUNNING");
        } else { throw new ApiException("Invalid timer action"); }
        return sessions.save(timer);
    }

    // الوقت من السيرفر فقط. إغلاق الشاشة لا يوقف الجلسة، والإيقاف الصريح يستثنى من الحساب.
    @Transactional
    public void sync(TimerSession timer) {
        LocalDateTime now = time.now();
        if (timer.getStatus().equals("RUNNING") && timer.getLastStartedAt() != null) {
            LocalDateTime end = now.isAfter(timer.getDeadline()) ? timer.getDeadline() : now;
            long seconds = Math.max(0,Duration.between(timer.getLastStartedAt(),end).getSeconds());
            long target = (long)timer.getRequiredSeconds()+timer.getExtensionSeconds();
            long available = Math.max(0,target-timer.getElapsedSeconds());
            long added = Math.min(seconds,available);
            LocalDateTime reached = timer.getLastStartedAt().plusSeconds(added);
            timer.setElapsedSeconds(timer.getElapsedSeconds()+added);
            timer.setLastStartedAt(end);
            if (timer.getElapsedSeconds() >= target) { timer.setStatus("PAUSED"); timer.setLastStartedAt(null); }
            if (timer.getRequiredReachedAt() == null && timer.getElapsedSeconds() >= timer.getRequiredSeconds()) {
                timer.setRequiredReachedAt(reached);
                outcome.primary(timer.getProof(),"ACCEPTED","اكتملت المدة الأصلية المحسوبة بالسيرفر");
            }
        }
        if (!now.isBefore(timer.getDeadline())) {
            timer.setLastStartedAt(null);
            if (timer.getRequiredReachedAt() == null) {
                timer.setStatus("EXPIRED");
                outcome.primary(timer.getProof(),"REJECTED","انتهى يوم النشاط قبل اكتمال المدة");
            } else { timer.setStatus("FINISHED"); }
        }
        sessions.save(timer);
    }
    public TimerSession findByProofId(Integer proofId) { return sessions.findByProofId(proofId); }
}
