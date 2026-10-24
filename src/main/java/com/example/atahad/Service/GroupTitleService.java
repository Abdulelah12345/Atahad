package com.example.atahad.Service;

import com.example.atahad.Dto.Out.GroupTitleResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.ChatMessageRepository;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GroupMemberRepository;
import com.example.atahad.Repository.GroupSettlementRepository;
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
// no table for the titles: the winner keeps them in GroupMember.title, and the history is in GroupSettlement.titles
@Service
@RequiredArgsConstructor
public class GroupTitleService {
    private final GroupMemberRepository groupMemberRepository;
    private final GroupSettlementRepository groupSettlementRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final PenaltyRepository penaltyRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GroupAccessService groupAccessService;

    // one title won by one member
    public record Win(String title, GroupMember groupMember){}

    @Transactional
    public List<Win> giveTitles(Group group, List<MemberWeek> weeks, LocalDate weekStart, LocalDate saturday){
        List<Win> titles = new ArrayList<>();
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
            int count = chatMessageRepository.findChatMessagesByTypeInAndSenderIdAndSentAtBetween(GroupAlertService.ALERT_TYPES, w.groupMember().getId(), from, to).size();
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

        // the titles of last week are replaced by the new ones
        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupId(group.getId())){
            StringBuilder mine = new StringBuilder();
            for(Win win : titles){
                if(win.groupMember().getId().equals(groupMember.getId())){
                    mine.append(mine.length() == 0 ? "" : ",").append(win.title());
                }
            }
            groupMember.setTitle(mine.length() == 0 ? null : mine.toString());
            groupMemberRepository.save(groupMember);
        }
        return titles;
    }

    // saved in GroupSettlement.titles: IRON=4;ROCKET=7 (the id of the GroupMember)
    public String encode(List<Win> titles){
        StringBuilder text = new StringBuilder();
        for(Win win : titles){
            text.append(text.length() == 0 ? "" : ";").append(win.title()).append("=").append(win.groupMember().getId());
        }
        return text.length() == 0 ? null : text.toString();
    }

    // the titles a member won in his groups between two dates (for the monthly wrapped)
    public List<String> titlesOf(Member member, LocalDate from, LocalDate to){
        List<String> list = new ArrayList<>();
        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByMemberId(member.getId())){
            for(GroupSettlement settlement : groupSettlementRepository.findGroupSettlementsByGroupGoalGroupIdAndWeekStartBetween(groupMember.getGroup().getId(), from, to)){
                for(String[] pair : decode(settlement.getTitles())){
                    if(pair[1].equals(String.valueOf(groupMember.getId()))){
                        list.add(pair[0]);
                    }
                }
            }
        }
        return list;
    }

    // the titles of the last week
    public List<GroupTitleResponse> getLatestTitles(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        for(GroupSettlement settlement : groupSettlementRepository.findGroupSettlementsByGroupGoalGroupIdOrderByCreatedAtDesc(groupId)){
            if(settlement.getTitles() != null){
                return toResponses(settlement);
            }
        }
        return new ArrayList<>();
    }

    public List<GroupTitleResponse> getTitlesHistory(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        List<GroupTitleResponse> list = new ArrayList<>();
        for(GroupSettlement settlement : groupSettlementRepository.findGroupSettlementsByGroupGoalGroupIdOrderByCreatedAtDesc(groupId)){
            list.addAll(toResponses(settlement));
        }
        return list;
    }

    public String nameOf(Win win){
        return groupAccessService.nameOf(win.groupMember().getMember());
    }

    private List<GroupTitleResponse> toResponses(GroupSettlement settlement){
        List<GroupTitleResponse> list = new ArrayList<>();
        for(String[] pair : decode(settlement.getTitles())){
            GroupMember winner = groupMemberRepository.findGroupMemberById(Integer.valueOf(pair[1]));
            if(winner != null){
                list.add(new GroupTitleResponse(settlement.getWeekStart(), pair[0], winner.getMember().getId(), groupAccessService.nameOf(winner.getMember())));
            }
        }
        return list;
    }

    private List<String[]> decode(String titles){
        List<String[]> list = new ArrayList<>();
        if(titles == null || titles.isBlank()){
            return list;
        }
        for(String part : titles.split(";")){
            String[] pair = part.split("=");
            if(pair.length == 2){
                list.add(pair);
            }
        }
        return list;
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

    private void add(List<Win> titles, Group group, MemberWeek winner, String title, LocalDate weekStart){
        if(winner != null){
            titles.add(new Win(title, winner.groupMember()));
        }
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
