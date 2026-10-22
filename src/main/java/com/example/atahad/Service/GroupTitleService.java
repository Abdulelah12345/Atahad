package com.example.atahad.Service;

import com.example.atahad.Dto.Out.GroupTitleResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GroupAlertRepository;
import com.example.atahad.Repository.GroupTitleRepository;
import com.example.atahad.Repository.PenaltyRepository;
import com.example.atahad.Service.GroupGoalService.MemberWeek;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.function.ToDoubleFunction;

// the weekly titles of the group, given in the settlement
// IRON: finished with the most times and no excuse | ROCKET: finished the week first | OWL: most proofs at night
// ALARMIST: sent the most alerts | COMEBACK: failed last week and finished this week
// EXCUSE_KING: most accepted excuses | TOP_DONOR: paid the most donations this week
@Service
@RequiredArgsConstructor
public class GroupTitleService {
    private final GroupTitleRepository groupTitleRepository;
    private final GroupAlertRepository groupAlertRepository;
    private final PenaltyRepository penaltyRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GroupAccessService groupAccessService;

    @Transactional
    public List<GroupTitle> giveTitles(Group group, List<MemberWeek> weeks, LocalDate weekStart, LocalDate saturday){
        List<GroupTitle> titles = new ArrayList<>();
        LocalDateTime from = weekStart.atStartOfDay();
        LocalDateTime to = saturday.atTime(23, 59, 59);

        // IRON
        MemberWeek iron = best(weeks, w -> isFull(w) && w.week().getExcusedDays() == 0 && w.week().getCompleted() > 0 ? w.week().getCompleted() : -1);
        add(titles, group, iron, "IRON", weekStart);

        // ROCKET: the earliest time the last proof of the week came
        MemberWeek rocket = best(weeks, w -> {
            LocalDateTime last = lastAcceptedProof(w.week());
            return isFull(w) && last != null ? java.time.Duration.between(last, to).getSeconds() : -1; // earlier = bigger
        });
        if(rocket != null && lastAcceptedProof(rocket.week()) != null){
            add(titles, group, rocket, "ROCKET", weekStart);
        }

        // OWL: proofs between 22:00 and 03:59
        add(titles, group, best(weeks, w -> {
            int count = 0;
            for(Proof proof : acceptedProofs(w.week())){
                int hour = proof.getSubmittedAt().getHour();
                if(hour >= 22 || hour < 4){
                    count++;
                }
            }
            return count == 0 ? -1 : count;
        }), "OWL", weekStart);

        // ALARMIST
        add(titles, group, best(weeks, w -> {
            int count = groupAlertRepository.findGroupAlertsBySenderIdAndSentAtBetween(w.groupMember().getId(), from, to).size();
            return count == 0 ? -1 : count;
        }), "ALARMIST", weekStart);

        // COMEBACK
        add(titles, group, best(weeks, w -> {
            if(!isFull(w)){
                return -1;
            }
            for(CommitmentWeek old : commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(w.week().getCommitment())){
                if(old.getWeekNumber() == w.week().getWeekNumber() - 1){
                    return Boolean.TRUE.equals(old.getIsFullWeek()) ? -1 : 1;
                }
            }
            return -1;
        }), "COMEBACK", weekStart);

        // EXCUSE_KING
        add(titles, group, best(weeks, w -> {
            int count = 0;
            if(w.week().getExcuses() != null){
                for(Excuse excuse : w.week().getExcuses()){
                    if("ACCEPTED".equals(excuse.getStatus())){
                        count++;
                    }
                }
            }
            return count == 0 ? -1 : count;
        }), "EXCUSE_KING", weekStart);

        // TOP_DONOR
        add(titles, group, best(weeks, w -> {
            BigDecimal total = BigDecimal.ZERO;
            for(Penalty penalty : penaltyRepository.findPenaltiesByMemberAndStatus(w.groupMember().getMember(), "PAID")){
                if(penalty.getPaidAt() != null && !penalty.getPaidAt().isBefore(from) && !penalty.getPaidAt().isAfter(to)){
                    total = total.add(penalty.getAmount());
                }
            }
            return total.signum() == 0 ? -1 : total.doubleValue();
        }), "TOP_DONOR", weekStart);

        return titles;
    }

    // the titles of the last week
    public List<GroupTitleResponse> getLatestTitles(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        List<GroupTitle> all = groupTitleRepository.findGroupTitlesByGroupIdOrderByWeekStartDesc(groupId);
        List<GroupTitleResponse> list = new ArrayList<>();
        if(all.isEmpty()){
            return list;
        }
        LocalDate last = all.get(0).getWeekStart();
        for(GroupTitle title : groupTitleRepository.findGroupTitlesByGroupIdAndWeekStart(groupId, last)){
            list.add(toResponse(title));
        }
        return list;
    }

    public List<GroupTitleResponse> getTitlesHistory(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        List<GroupTitleResponse> list = new ArrayList<>();
        for(GroupTitle title : groupTitleRepository.findGroupTitlesByGroupIdOrderByWeekStartDesc(groupId)){
            list.add(toResponse(title));
        }
        return list;
    }

    public String nameOf(GroupTitle title){
        return groupAccessService.nameOf(title.getGroupMember().getMember());
    }

    private GroupTitleResponse toResponse(GroupTitle title){
        return new GroupTitleResponse(title.getWeekStart(), title.getTitle(),
                title.getGroupMember().getMember().getId(), nameOf(title));
    }

    // the member with the highest value, values below zero do not win
    private MemberWeek best(List<MemberWeek> weeks, ToDoubleFunction<MemberWeek> value){
        MemberWeek best = null;
        double bestValue = -1;
        for(MemberWeek w : weeks){
            double v = value.applyAsDouble(w);
            if(v >= 0 && (best == null || v > bestValue)){
                best = w;
                bestValue = v;
            }
        }
        return best;
    }

    private void add(List<GroupTitle> titles, Group group, MemberWeek winner, String title, LocalDate weekStart){
        if(winner == null){
            return;
        }
        GroupTitle groupTitle = new GroupTitle();
        groupTitle.setWeekStart(weekStart);
        groupTitle.setTitle(title);
        groupTitle.setGroup(group);
        groupTitle.setGroupMember(winner.groupMember());
        groupTitleRepository.save(groupTitle);
        titles.add(groupTitle);
    }

    private boolean isFull(MemberWeek w){
        return Boolean.TRUE.equals(w.week().getIsFullWeek());
    }

    private List<Proof> acceptedProofs(CommitmentWeek week){
        List<Proof> list = new ArrayList<>();
        if(week.getProofs() != null){
            for(Proof proof : week.getProofs()){
                if("ACCEPTED".equals(proof.getResult()) && proof.getSubmittedAt() != null){
                    list.add(proof);
                }
            }
        }
        return list;
    }

    private LocalDateTime lastAcceptedProof(CommitmentWeek week){
        LocalDateTime last = null;
        for(Proof proof : acceptedProofs(week)){
            if(last == null || proof.getSubmittedAt().isAfter(last)){
                last = proof.getSubmittedAt();
            }
        }
        return last;
    }
}
