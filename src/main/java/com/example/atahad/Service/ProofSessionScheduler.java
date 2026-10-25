package com.example.atahad.Service;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Scheduled;
import java.util.List;

@Component @RequiredArgsConstructor
public class ProofSessionScheduler {
    private final TimerSessionRepository timers;
    private final ProofRepository proofs;
    private final ProofSessionMaintenance maintenance;
    private static final org.slf4j.Logger LOG=org.slf4j.LoggerFactory.getLogger(ProofSessionScheduler.class);
    @Scheduled(cron="0 * * * * *",zone="Asia/Riyadh")
    public void tick() {
        for (var timer:timers.findByStatusIn(List.of("RUNNING","PAUSED"))) {
            try { maintenance.timer(timer.getId()); } catch (RuntimeException ex) { LOG.warn("Could not synchronize timer {}",timer.getId()); }
        }
        for (var proof:proofs.findProofsByResult("PENDING")) {
            try { maintenance.expire(proof.getId()); } catch (RuntimeException ex) { LOG.warn("Could not expire proof {}",proof.getId()); }
        }
    }
}
