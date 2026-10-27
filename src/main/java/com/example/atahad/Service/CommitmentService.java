package com.example.atahad.Service;
import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.CommitmentTargetRequest;
import com.example.atahad.Dto.Out.LockStatusResponse;
import com.example.atahad.Dto.Out.MemberStatsResponse;
import com.example.atahad.Dto.Out.PendingPenaltyResponse;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.Penalty;
import com.example.atahad.Repository.CommitmentRepository;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.PenaltyRepository;
import com.example.atahad.Repository.ProofRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CommitmentService {
    private final CommitmentRepository commitmentRepository;
    private final MemberRepository memberRepository;
    private final PenaltyRepository penaltyRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final ProofRepository proofRepository;

    // habits and goals together
    public List<Commitment> getMyCommitments(Integer memberId){
        Member member = getMember(memberId);
        return commitmentRepository.findCommitmentsByMember(member);
    }

    public Commitment getCommitment(Integer memberId, Integer id){
        Commitment commitment = commitmentRepository.findCommitmentById(id);
        if(commitment == null){
            throw new ApiException("Commitment not found");
        }
        if(!commitment.getMember().getId().equals(memberId)){
            throw new ApiException("You can only see your own commitment");
        }
        return commitment;
    }

    // the withdrawal is right away, every time left this week becomes a penalty and the app is locked
    @Transactional
    public Integer withdraw(Integer memberId, Integer id){
        Commitment commitment = getCommitment(memberId, id);
        if(commitment.getStatus().equals("WITHDRAWN") || commitment.getStatus().equals("ENDED")){
            throw new ApiException("Commitment is already finished");
        }
        if(commitment.getGroupGoal() != null){
            throw new ApiException("A group commitment ends with the group goal, leave the group instead");
        }
        commitment.setStatus("WITHDRAWN");
        commitmentRepository.save(commitment);
        return commitmentWeekService.penalizeWithdrawal(commitment);
    }

    // what the lock screen shows: the penalties that are waiting for a donation
    public LockStatusResponse getLockStatus(Integer memberId){
        Member member = getMember(memberId);
        BigDecimal total = BigDecimal.ZERO;
        List<PendingPenaltyResponse> list = new ArrayList<>();
        for(Penalty penalty : penaltyRepository.findPenaltiesByMemberAndStatus(member, "PENDING")){
            total = total.add(penalty.getAmount());
            String title = penalty.getCommitmentWeek() == null ? null : penalty.getCommitmentWeek().getCommitment().getTitle();
            list.add(new PendingPenaltyResponse(penalty.getId(), penalty.getAmount(), penalty.getReason(), title, penalty.getCreatedAt()));
        }
        return new LockStatusResponse(Boolean.TRUE.equals(member.getIsLocked()), total, list);
    }

    // the progress card on the profile
    public MemberStatsResponse getStats(Integer memberId){
        Member member = getMember(memberId);
        String level = member.getLevel() == null ? "BEGINNER" : member.getLevel();
        int index = Math.max(0, CommitmentWeekService.LEVELS.indexOf(level));
        int weeks = member.getConsecutiveWeeks() == null ? 0 : member.getConsecutiveWeeks();
        int points = member.getPoints() == null ? 0 : member.getPoints();

        String nextLevel = null;
        Integer weeksToNext = null;
        if(index + 1 < CommitmentWeekService.LEVELS.size()){
            nextLevel = CommitmentWeekService.LEVELS.get(index + 1);
            weeksToNext = Math.max(0, CommitmentWeekService.LEVEL_WEEKS.get(index + 1) - weeks);
        }

        BigDecimal donated = BigDecimal.ZERO;
        for(Penalty penalty : penaltyRepository.findPenaltiesByMemberAndStatus(member, "PAID")){
            donated = donated.add(penalty.getAmount());
        }

        return new MemberStatsResponse(
                level,
                weeks,
                nextLevel,
                weeksToNext,
                points,
                Math.max(0, CommitmentWeekService.POINTS_FOR_GRACE_DAY - points),
                commitmentWeekService.availableGraceDays(member, LocalDate.now()).size(),
                commitmentWeekService.graceDayCapacity(level),
                commitmentWeekRepository.countCommitmentWeeksByCommitmentMemberAndIsFullWeekTrue(member),
                commitmentRepository.findCommitmentsByMemberAndStatus(member, "ACTIVE").size(),
                donated
        );
    }

    // the start day: today (null) or a later day, within a year
    public static void checkStartDate(Commitment commitment){
        LocalDate start = commitment.getStartDate();
        LocalDate today = LocalDate.now();
        if(start == null){
            return;
        }
        if(start.isBefore(today)){
            throw new ApiException("Start date cannot be in the past");
        }
        if(start.isAfter(today.plusYears(1))){
            throw new ApiException("Start date must be within a year");
        }
        if(!start.isAfter(today)){
            commitment.setStartDate(null); // today is the same as now
        }
    }

    // LOCATION needs its place and TIMER its minutes, the proof is checked against them
    public static void checkTargets(Commitment commitment){
        if("STEPS".equals(commitment.getProofMethod())) {
            if(!(commitment instanceof com.example.atahad.Entity.Habit) || commitment.getGroupGoal()!=null) {
                throw new ApiException("Steps currently support personal habits only");
            }
            if(commitment.getTargetSteps()==null || commitment.getTargetSteps()<100 || commitment.getTargetSteps()>100000) {
                throw new ApiException("Daily steps target must be between 100 and 100000");
            }
            if(!java.util.List.of("HEALTH_DATA","SCREENSHOT").contains(java.util.Objects.toString(commitment.getStepEvidenceMode(),""))) {
                throw new ApiException("Choose HEALTH_DATA or SCREENSHOT before starting");
            }
        }
        if("LOCATION".equals(commitment.getProofMethod()) && commitment.getGroupGoal() == null
                && (commitment.getTargetLatitude() == null || commitment.getTargetLongitude() == null)){
            throw new ApiException("A LOCATION commitment needs the place (latitude and longitude)");
        }
        if("TIMER".equals(commitment.getProofMethod()) && commitment.getTargetMinutes() == null){
            throw new ApiException("A TIMER commitment needs the minutes of one time");
        }
    }

    // the place: only before the first accepted proof, so it can not be moved closer to make it easier
    // the minutes (TIMER, or the time in the place for LOCATION): can change any time
    public void setTarget(Integer memberId, Integer id, CommitmentTargetRequest dto){
        Commitment commitment = getCommitment(memberId, id);
        if(!"ACTIVE".equals(commitment.getStatus())){
            throw new ApiException("Commitment is finished");
        }
        String method = commitment.getProofMethod();
        if(!"LOCATION".equals(method) && !"TIMER".equals(method)){
            throw new ApiException("Only LOCATION and TIMER commitments have a target");
        }
        boolean placeSent = dto.getLatitude() != null || dto.getLongitude() != null;
        if("TIMER".equals(method) && dto.getMinutes() == null){
            throw new ApiException("Minutes are required");
        }
        if("LOCATION".equals(method) && !placeSent && dto.getMinutes() == null){
            throw new ApiException("Send the place or the minutes");
        }

        if(dto.getMinutes() != null){
            if(commitment.getGroupGoal() != null){
                throw new ApiException("The minutes of a group goal are the same for every member");
            }
            commitment.setTargetMinutes(dto.getMinutes());
        }
        if("LOCATION".equals(method) && placeSent){
            if(dto.getLatitude() == null || dto.getLongitude() == null){
                throw new ApiException("Latitude and longitude are required");
            }
            if(!proofRepository.findProofsByCommitmentWeekCommitmentIdAndResult(id, "ACCEPTED").isEmpty()){
                throw new ApiException("The place can not change after the first accepted proof");
            }
            commitment.setTargetLatitude(dto.getLatitude());
            commitment.setTargetLongitude(dto.getLongitude());
            commitment.setTargetRadiusMeters(dto.getRadiusMeters());
            commitment.setTargetPlaceName(dto.getPlaceName());
        }
        commitmentRepository.save(commitment);
    }

    private Member getMember(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return member;
    }
    private boolean isLearningGoal(String title) {
        if (title == null || title.isBlank()) {
            return false;
        }

        String text = title.toLowerCase();

        return List.of(
                "قراء", "رواي", "كتاب", "كتب",
                "دراس", "مذاكر", "تعلم", "تعلّم",
                "كورس", "دورة", "برمج", "لغة",
                "reading", "study", "learn", "book"
        ).stream().anyMatch(text::contains);
    }
    public boolean hasLearningGoal(Integer memberId) {
        List<Commitment> commitments = getMyCommitments(memberId);

        for (Commitment commitment : commitments) {
            if ("ACTIVE".equals(commitment.getStatus())
                    && isLearningGoal(commitment.getTitle())) {
                return true;
            }
        }

        return false;
    }
}
