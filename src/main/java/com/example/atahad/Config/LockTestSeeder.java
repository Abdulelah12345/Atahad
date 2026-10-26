package com.example.atahad.Config;

import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import com.example.atahad.Service.LockService;
import com.example.atahad.Service.WhatsAppService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

// OWNER: Fai - test only: locks the app of the main user (seed.main-email) and one more member,
// with an unpaid donation like a lost time, so the lock screen, the WhatsApp message, «تبرّعت» and the bank email can be tested.
// on only when seed.lock-test=true (application-local.properties), on a seeded database, and only once for every member
// (a member who already owes something is skipped). Turn it off after the test.
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "seed.lock-test", havingValue = "true")
public class LockTestSeeder implements ApplicationRunner {

    private final UserRepository userRepository;
    private final MemberRepository memberRepository;
    private final CommitmentRepository commitmentRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final PenaltyRepository penaltyRepository;
    private final ExcuseRepository excuseRepository;
    private final LockService lockService;
    private final WhatsAppService whatsAppService;

    @Value("${seed.main-email}")
    private String mainEmail;
    @Value("${seed.friend-email:}")
    private String friendEmail;
    @Value("${seed.lock-test.second-email:}")
    private String secondEmail; // optional, the other member to lock (else the friend, else sara)

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        String second = !secondEmail.isBlank() ? secondEmail : !friendEmail.isBlank() ? friendEmail : "sara@atahad.test";
        // the main user: the donation counts from this run (to test the bank email of a new transfer)
        lock(mainEmail, 1, LocalDateTime.now(), true);
        // the other member: an old donation (3 days ago), so a transfer made before today proves it
        lock(second, 1, LocalDateTime.now().minusDays(3), true);
    }

    // times x 5 SAR, on his first active commitment that has a week now
    // since: the time of the donation (a transfer must be after it), moveOld: an unpaid donation from a run before gets this time too
    private void lock(String email, int times, LocalDateTime since, boolean moveOld) {
        User user = userRepository.findUserByEmail(email);
        Member member = user == null ? null : memberRepository.findMemberById(user.getId());
        if (member == null) {
            log.warn("Lock test: no member with the email {}", email);
            return;
        }
        // an excuse waiting for a decision keeps the app open (LockService), the seed gave the main user one, so it is closed here
        for (String status : List.of("ESCALATED", "PENDING")) {
            for (Excuse excuse : excuseRepository.findExcusesByCommitmentWeekCommitmentMemberIdAndStatus(member.getId(), status)) {
                excuse.setStatus("REJECTED");
                excuse.setProcessingStatus("FINISHED");
                excuse.setAiAssessment("اختبار القفل: انرفض العذر عشان يتقفل التطبيق");
                excuseRepository.save(excuse);
            }
        }
        List<Penalty> owed = penaltyRepository.findPenaltiesByMemberAndStatus(member, "PENDING");
        if (!owed.isEmpty()) {
            if (moveOld) {
                for (Penalty penalty : owed) {
                    penalty.setCreatedAt(since);
                    penaltyRepository.save(penalty);
                }
            }
            lockService.refresh(member); // owes from a run before: only lock it again
            log.info("Lock test: {} already owes a donation, locked={}, a transfer after {} proves it", email, member.getIsLocked(), since);
            return;
        }
        CommitmentWeek week = currentWeek(member); // null is fine: the penalty shows without a commitment title
        BigDecimal amount = BigDecimal.valueOf(5);
        for (int i = 0; i < times; i++) {
            Penalty penalty = new Penalty();
            penalty.setAmount(amount);
            penalty.setReason("LOST_DAY");
            penalty.setCreatedAt(since);
            penalty.setStatus("PENDING");
            penalty.setMember(member);
            penalty.setCommitmentWeek(week);
            penaltyRepository.save(penalty);
        }
        lockService.refresh(member);
        BigDecimal total = amount.multiply(BigDecimal.valueOf(times));
        String title = week == null ? "تعهّداتك" : week.getCommitment().getTitle();
        whatsAppService.lockMessage(member, title, times, amount, total, false);
        log.info("Lock test: {} is locked={}, owes {} SAR, a transfer after {} proves it, the WhatsApp message is in the queue",
                email, member.getIsLocked(), total, since);
    }

    private CommitmentWeek currentWeek(Member member) {
        LocalDateTime now = LocalDateTime.now();
        List<Commitment> commitments = commitmentRepository.findCommitmentsByMemberAndStatus(member, "ACTIVE");
        for (Commitment commitment : commitments) {
            for (CommitmentWeek week : commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(commitment)) {
                if (week.getWeekStart() != null && week.getWeekEnd() != null
                        && !now.isBefore(week.getWeekStart()) && !now.isAfter(week.getWeekEnd())) {
                    return week;
                }
            }
        }
        for (Commitment commitment : commitments) {
            List<CommitmentWeek> weeks = commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(commitment);
            if (!weeks.isEmpty()) {
                return weeks.get(0);
            }
        }
        return null;
    }
}
