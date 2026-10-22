package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
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

    private Member getMember(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return member;
    }
}
