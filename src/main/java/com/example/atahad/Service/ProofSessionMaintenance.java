package com.example.atahad.Service;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service @RequiredArgsConstructor
public class ProofSessionMaintenance {
    private final TimerSessionRepository timers;
    private final TimerSessionService timerService;
    private final ProofRepository proofs;
    private final ProofEvidenceRepository evidence;
    private final ProofOutcomeService outcome;
    private final ProofTime time;

    @Transactional
    public void timer(Integer id) {
        TimerSession timer=timers.findForUpdate(id);
        if (timer!=null) { timerService.sync(timer); }
    }
    @Transactional
    public void expire(Integer id) {
        Proof proof=proofs.findProofById(id);
        if (proof==null || proof.getAttemptDeadline()==null || time.now().isBefore(proof.getAttemptDeadline()) || proof.getResult().equals("ACCEPTED")) { return; }
        for (ProofEvidence item:evidence.findByProofIdOrderById(id)) {
            if (item.getResult().equals("PENDING")) { outcome.record(proof,item.getType(),"REJECTED","انتهت مهلة تقديم هذا الدليل"); }
        }
        evidence.flush(); outcome.recompute(proof);
    }
}
