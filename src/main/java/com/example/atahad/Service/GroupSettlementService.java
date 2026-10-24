package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import com.example.atahad.Service.GroupGoalService.MemberWeek;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// the weekly settlement of a group (sunday 00:00, after the weeks are closed)
// nobody failed -> golden week, points for the group
// somebody failed (without an accepted excuse) -> every member who finished donates half of the task price,
// and every member who failed donates the task price. first failure he stays, second failure he is removed
@Service
@RequiredArgsConstructor
public class GroupSettlementService {
    private final GroupSettlementRepository groupSettlementRepository;
    private final GroupGoalRepository groupGoalRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final PenaltyRepository penaltyRepository;
    private final MemberRepository memberRepository;
    private final GroupAccessService groupAccessService;
    private final GroupGoalService groupGoalService;
    private final GroupMemberService groupMemberService;
    private final GroupTitleService groupTitleService;
    private final PointLogService pointLogService;
    private final AiService aiService;
    private final LockService lockService;
    private final WhatsAppService whatsAppService;

    public static final int REFUSAL_DAYS = 7; // a group donation not paid in 7 days = refusal

    @Transactional
    public void runWeekly(LocalDate sunday){
        LocalDate saturday = sunday.minusDays(1);
        LocalDate weekStart = saturday.minusDays(6);
        for(GroupGoal goal : groupGoalRepository.findGroupGoalsByStatus("ACTIVE")){
            if(goal.getStartDate() != null && goal.getStartDate().isAfter(saturday)){
                continue; // started today, nothing to settle yet
            }
            if(groupSettlementRepository.findGroupSettlementByGroupGoalIdAndWeekStart(goal.getId(), weekStart) == null){
                settle(goal, weekStart, saturday, sunday);
            }
            if(goal.getEndDate() != null && !saturday.isBefore(goal.getEndDate())){
                groupGoalService.endGoal(goal);
            }
        }
    }

    private void settle(GroupGoal goal, LocalDate weekStart, LocalDate saturday, LocalDate sunday){
        Group group = goal.getGroup();
        List<MemberWeek> weeks = groupGoalService.closedWeeks(goal, saturday);
        if(weeks.isEmpty()){
            return;
        }

        GroupSettlement settlement = new GroupSettlement();
        settlement.setWeekStart(weekStart);
        settlement.setCreatedAt(LocalDateTime.now());
        settlement.setGroupGoal(goal);
        groupSettlementRepository.save(settlement);

        List<MemberWeek> failed = new ArrayList<>();
        for(MemberWeek w : weeks){
            if(!Boolean.TRUE.equals(w.week().getIsFullWeek())){
                failed.add(w);
            }
        }

        BigDecimal price = goal.getAmountPerTime();
        List<GroupMember> toKick = new ArrayList<>();
        if(failed.isEmpty()){
            pointLogService.addGroupPoints(group, PointLogService.GOLDEN_WEEK_POINTS, "GOLDEN_WEEK");
        }else{
            for(MemberWeek w : weeks){
                createPenalty(w, failed.contains(w) ? price : half(price), "GROUP_COLLECTIVE", settlement, sunday);
            }
            for(MemberWeek w : failed){
                GroupMember groupMember = w.groupMember();
                groupMember.setFailureCount((groupMember.getFailureCount() == null ? 0 : groupMember.getFailureCount()) + 1);
                groupMemberRepository.save(groupMember);
                if(groupMember.getFailureCount() >= 2){
                    toKick.add(groupMember);
                }
            }
        }

        List<GroupTitleService.Win> titles = groupTitleService.giveTitles(group, weeks, weekStart, saturday);
        settlement.setTitles(groupTitleService.encode(titles));

        String text = writeText(group, goal, weeks, failed, toKick, titles, price);
        settlement.setSettlementText(text.length() > 2000 ? text.substring(0, 2000) : text);
        groupSettlementRepository.save(settlement);
        groupAccessService.systemMessage(group, settlement.getSettlementText());
        sendWhatsApp(group, goal, weeks, failed, price, settlement.getSettlementText());

        for(GroupMember groupMember : toKick){
            groupMemberService.kick(groupMember, "failed twice in this group");
        }
    }

    // every member gets the result of the week and his own amount
    private void sendWhatsApp(Group group, GroupGoal goal, List<MemberWeek> weeks, List<MemberWeek> failed,
                              BigDecimal price, String text){
        List<String> board = new ArrayList<>();
        for(MemberWeek w : weeks){
            boolean done = Boolean.TRUE.equals(w.week().getIsFullWeek());
            board.add((done ? "✓ " : "✗ ") + groupAccessService.nameOf(w.groupMember().getMember())
                    + "  " + w.week().getCompleted() + "/" + w.week().getRequired());
        }
        for(MemberWeek w : weeks){
            BigDecimal mine = BigDecimal.ZERO;
            if(!failed.isEmpty()){
                mine = failed.contains(w) ? price : half(price);
            }
            whatsAppService.settlementMessage(w.groupMember().getMember(), group.getName(), goal.getTitle(), text, board, mine);
        }
    }

    // the facts are written by the code, the AI only makes them fun to read
    private String writeText(Group group, GroupGoal goal, List<MemberWeek> weeks, List<MemberWeek> failed,
                             List<GroupMember> toKick, List<GroupTitleService.Win> titles, BigDecimal price){
        StringBuilder facts = new StringBuilder();
        facts.append("Goal: ").append(goal.getTitle()).append("\n");
        for(MemberWeek w : weeks){
            facts.append("- ").append(groupAccessService.nameOf(w.groupMember().getMember()))
                    .append(": ").append(w.week().getCompleted()).append("/").append(w.week().getRequired())
                    .append(Boolean.TRUE.equals(w.week().getIsFullWeek()) ? " done" : " failed").append("\n");
        }
        StringBuilder titleLine = new StringBuilder();
        for(GroupTitleService.Win title : titles){
            titleLine.append(title.title()).append(": ").append(groupTitleService.nameOf(title)).append(", ");
        }

        String fallback;
        if(failed.isEmpty()){
            fallback = "أسبوع ذهبي! الكل التزم في " + goal.getTitle() + "، والقروب كسب " + PointLogService.GOLDEN_WEEK_POINTS + " نقطة.";
        }else{
            List<String> names = new ArrayList<>();
            for(MemberWeek w : failed){
                names.add(groupAccessService.nameOf(w.groupMember().getMember()));
            }
            fallback = "تسوية الأسبوع: " + String.join(" و", names) + " ما كمّلوا " + goal.getTitle()
                    + ". اللي كمّلوا عليهم تبرع " + money(half(price)) + " ريال لإحسان، واللي ما كمّلوا عليهم " + money(price) + " ريال.";
            if(!toKick.isEmpty()){
                fallback += " وهذي المرة الثانية، فطلعوا من القروب.";
            }
        }
        if(titleLine.length() > 0){
            fallback += " ألقاب الأسبوع: " + titleLine.substring(0, titleLine.length() - 2);
        }

        return aiService.ask(
                "You write the weekly settlement message of a group in a commitment app (max 80 words). "
                        + "Keep every name, number and amount exactly as given, do not add new penalties. "
                        + "Donations go to Ehsan charity. " + aiService.tone(),
                facts + "\nSettlement:\n" + fallback,
                fallback);
    }

    // the members who finished pay half of the task price, even when it is less than 5
    private BigDecimal half(BigDecimal price){
        return price.divide(BigDecimal.valueOf(2), 2, java.math.RoundingMode.HALF_UP);
    }

    private String money(BigDecimal amount){
        return amount.stripTrailingZeros().toPlainString();
    }

    private void createPenalty(MemberWeek w, BigDecimal amount, String reason, GroupSettlement settlement, LocalDate sunday){
        Member member = w.groupMember().getMember();
        Penalty penalty = new Penalty();
        penalty.setAmount(amount);
        penalty.setReason(reason);
        penalty.setCreatedAt(sunday.atStartOfDay()); // the 7 days to pay start from the settlement day
        penalty.setStatus("PENDING");
        penalty.setMember(member);
        penalty.setCommitmentWeek(w.week());
        penalty.setGroupSettlement(settlement);
        penaltyRepository.save(penalty);
        lockService.refresh(member);
    }

    // a group donation not paid for 7 days: 1st time removed + one month ban from groups,
    // 2nd time banned from groups forever, 3rd time the account is banned
    @Transactional
    public void punishRefusals(LocalDate today){
        LocalDateTime before = today.minusDays(REFUSAL_DAYS).atStartOfDay();
        for(Penalty penalty : penaltyRepository.findPenaltiesByStatusAndGroupSettlementIsNotNullAndCreatedAtBefore("PENDING", before)){
            if(Boolean.TRUE.equals(penalty.getRefusalCounted())){
                continue; // this settlement was already counted as a refusal
            }
            Member member = penalty.getMember();
            GroupSettlement settlement = penalty.getGroupSettlement();
            // one refusal for every settlement, even if he has two penalties in it
            for(Penalty samePenalty : penaltyRepository.findPenaltiesByMemberAndStatus(member, "PENDING")){
                if(samePenalty.getGroupSettlement() != null && samePenalty.getGroupSettlement().getId().equals(settlement.getId())){
                    samePenalty.setRefusalCounted(true);
                    penaltyRepository.save(samePenalty);
                }
            }

            int count = (member.getGroupRefusalCount() == null ? 0 : member.getGroupRefusalCount()) + 1;
            member.setGroupRefusalCount(count);
            if(count == 1){
                member.setGroupBanUntil(today.plusMonths(1));
            }else if(count == 2){
                member.setGroupBannedForever(true);
            }else{
                member.setGroupBannedForever(true);
                member.setAccountBanned(true);
            }
            memberRepository.save(member);

            // removed from the group of the settlement (if he is still in it), and from every group after the 2nd time
            Group group = settlement.getGroupGoal().getGroup();
            for(GroupMember groupMember : groupMemberRepository.findGroupMembersByMemberIdAndStatus(member.getId(), "ACTIVE")){
                if(count >= 2 || groupMember.getGroup().getId().equals(group.getId())){
                    groupMemberService.kick(groupMember, "did not pay the group donation for " + REFUSAL_DAYS + " days");
                }
            }
        }
    }

    public List<GroupSettlement> getSettlements(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        return groupSettlementRepository.findGroupSettlementsByGroupGoalGroupIdOrderByCreatedAtDesc(groupId);
    }

    public GroupSettlement getLatest(Integer groupId, Integer memberId){
        List<GroupSettlement> list = getSettlements(groupId, memberId);
        if(list.isEmpty()){
            throw new ApiException("No settlement yet, the first one is on sunday");
        }
        return list.get(0);
    }
}
