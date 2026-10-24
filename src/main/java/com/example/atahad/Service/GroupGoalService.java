package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GroupGoalRequest;
import com.example.atahad.Dto.Out.GroupBoardResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;

// a group has one goal at a time, every member gets his own habit from it
@Service
@RequiredArgsConstructor
public class GroupGoalService {
    private final GroupGoalRepository groupGoalRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final CommitmentRepository commitmentRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final HabitRepository habitRepository;
    private final GroupAccessService groupAccessService;
    private final CommitmentWeekService commitmentWeekService;

    // the owner confirms the goal, it starts now for every member and the first week ends this saturday
    @Transactional
    public GroupGoal createGoal(Integer groupId, Integer ownerId, GroupGoalRequest dto){
        GroupMember owner = groupAccessService.checkOwner(groupId, ownerId);
        Group group = owner.getGroup();
        if(groupGoalRepository.findGroupGoalByGroupIdAndStatus(groupId, "ACTIVE") != null){
            throw new ApiException("The group already has a goal, one goal at a time");
        }
        if(groupAccessService.activeMembersCount(groupId) < GroupAccessService.MIN_MEMBERS){
            throw new ApiException("A group goal needs at least " + GroupAccessService.MIN_MEMBERS + " members");
        }

        // the chosen proposal becomes the goal itself, the other proposals are closed
        GroupGoal goal = dto.getProposalId() == null ? new GroupGoal() : closeProposals(group, dto.getProposalId());
        goal.setTitle(dto.getTitle());
        goal.setProofMethod(dto.getProofMethod());
        goal.setTimesPerWeek(dto.getTimesPerWeek());
        goal.setAmountPerTime(dto.getAmountPerTime());
        goal.setTotalWeeks(dto.getTotalWeeks());
        if("TIMER".equals(dto.getProofMethod()) && dto.getTargetMinutes() == null){
            throw new ApiException("A TIMER goal needs the minutes of one time");
        }
        goal.setTargetMinutes(dto.getTargetMinutes());
        goal.setStartDate(LocalDate.now());
        goal.setEndDate(LocalDate.now().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY)).plusWeeks(dto.getTotalWeeks() - 1));
        goal.setStatus("ACTIVE");
        goal.setGroup(group);
        groupGoalRepository.save(goal);

        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupId, "ACTIVE")){
            addMemberCommitment(goal, groupMember.getMember());
        }
        groupAccessService.systemMessage(group, "New goal: " + goal.getTitle() + ", " + goal.getTimesPerWeek()
                + " times a week for " + goal.getTotalWeeks() + " weeks, " + goal.getAmountPerTime() + " SAR for every missed time");
        return goal;
    }

    // a habit for the member, linked to the group goal
    @Transactional
    public void addMemberCommitment(GroupGoal goal, Member member){
        Habit habit = new Habit();
        habit.setTitle(goal.getTitle());
        habit.setProofMethod(goal.getProofMethod());
        habit.setTimesPerWeek(goal.getTimesPerWeek());
        habit.setBaseAmount(goal.getAmountPerTime());
        habit.setTargetMinutes(goal.getTargetMinutes()); // LOCATION: the member sets his own place with /commitment/target
        habit.setStatus("ACTIVE");
        habit.setEffectiveFrom(LocalDate.now());
        habit.setMember(member);
        habit.setGroupGoal(goal);
        habitRepository.save(habit);
        commitmentWeekService.startFirstWeek(habit);
    }

    // leaving pays the times left this week, being kicked does not (he already paid in the settlement)
    @Transactional
    public void removeMemberCommitment(Group group, Member member, boolean withPenalties){
        GroupGoal goal = groupGoalRepository.findGroupGoalByGroupIdAndStatus(group.getId(), "ACTIVE");
        if(goal == null){
            return;
        }
        Commitment commitment = getMemberCommitment(goal, member);
        if(commitment == null){
            return;
        }
        commitment.setStatus("WITHDRAWN");
        commitmentRepository.save(commitment);
        if(withPenalties){
            commitmentWeekService.penalizeWithdrawal(commitment);
        }
    }

    public GroupGoal getActiveGoal(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        GroupGoal goal = groupGoalRepository.findGroupGoalByGroupIdAndStatus(groupId, "ACTIVE");
        if(goal == null){
            throw new ApiException("The group has no goal now, choose the next goal");
        }
        return goal;
    }

    public List<GroupGoal> getGoalHistory(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        return groupGoalRepository.findGroupGoalsByGroupIdAndStatusInOrderByStartDateDesc(groupId, List.of("ACTIVE", "ENDED"));
    }

    // the group screen: every member and what is left for him this week
    @Transactional
    public List<GroupBoardResponse> getBoard(Integer groupId, Integer memberId){
        GroupGoal goal = getActiveGoal(groupId, memberId);
        LocalDate today = LocalDate.now();
        List<GroupBoardResponse> board = new ArrayList<>();

        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupId, "ACTIVE")){
            Member member = groupMember.getMember();
            CommitmentWeek week = currentWeek(goal, member);
            if(week == null){
                continue;
            }
            board.add(new GroupBoardResponse(member.getId(), groupAccessService.nameOf(member), week.getRequired(),
                    week.getCompleted(), commitmentWeekService.remainingTimes(week), commitmentWeekService.daysLeftOf(week, today),
                    week.getTrackStatus(), groupMember.getFailureCount(), hasExcuse(week)));
        }
        return board;
    }

    // used by the settlement when the last week of the goal is closed
    @Transactional
    public void endGoal(GroupGoal goal){
        goal.setStatus("ENDED");
        groupGoalRepository.save(goal);
        for(Commitment commitment : commitmentRepository.findCommitmentsByGroupGoal(goal)){
            if("ACTIVE".equals(commitment.getStatus())){
                commitment.setStatus("ENDED");
                commitmentRepository.save(commitment);
            }
        }
        groupAccessService.systemMessage(goal.getGroup(), "The goal " + goal.getTitle() + " ended, vote for the next goal");
    }

    public Commitment getMemberCommitment(GroupGoal goal, Member member){
        for(Commitment commitment : commitmentRepository.findCommitmentsByGroupGoal(goal)){
            if(commitment.getMember().getId().equals(member.getId()) && "ACTIVE".equals(commitment.getStatus())){
                return commitment;
            }
        }
        return null;
    }

    // the running week of the member in the goal
    public CommitmentWeek currentWeek(GroupGoal goal, Member member){
        Commitment commitment = getMemberCommitment(goal, member);
        if(commitment == null){
            return null;
        }
        CommitmentWeek week = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
        LocalDate today = LocalDate.now();
        if(week == null || today.isAfter(week.getWeekEnd().toLocalDate())){
            return null;
        }
        return week;
    }

    // a member with his week in the goal, used by the settlement, the titles and the matches
    public record MemberWeek(GroupMember groupMember, CommitmentWeek week) {}

    // the week of every active member that ended on this saturday
    public List<MemberWeek> closedWeeks(GroupGoal goal, LocalDate saturday){
        List<MemberWeek> list = new ArrayList<>();
        Integer groupId = goal.getGroup().getId();
        for(Commitment commitment : commitmentRepository.findCommitmentsByGroupGoal(goal)){
            if("WITHDRAWN".equals(commitment.getStatus())){
                continue; // left or kicked, he is out of the settlement
            }
            GroupMember groupMember = groupMemberRepository.findGroupMemberByGroupIdAndMemberId(groupId, commitment.getMember().getId());
            if(groupMember == null || !"ACTIVE".equals(groupMember.getStatus())){
                continue;
            }
            for(CommitmentWeek week : commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(commitment)){
                if(week.getWeekEnd().toLocalDate().equals(saturday)){
                    list.add(new MemberWeek(groupMember, week));
                    break;
                }
            }
        }
        return list;
    }

    // an excuse that was sent and not rejected stops the alerts
    public boolean hasExcuse(CommitmentWeek week){
        if(week.getExcuses() == null){
            return false;
        }
        for(Excuse excuse : week.getExcuses()){
            if(!"REJECTED".equals(excuse.getStatus())){
                return true;
            }
        }
        return false;
    }

    private GroupGoal closeProposals(Group group, Integer chosenId){
        GroupGoal chosen = groupGoalRepository.findGroupGoalById(chosenId);
        if(chosen == null || !chosen.getGroup().getId().equals(group.getId())){
            throw new ApiException("Proposal not found in this group");
        }
        if(!"PROPOSED".equals(chosen.getStatus())){
            throw new ApiException("This proposal is closed");
        }
        for(GroupGoal proposal : groupGoalRepository.findGroupGoalsByGroupIdAndStatus(group.getId(), "PROPOSED")){
            if(!proposal.getId().equals(chosenId)){
                proposal.setStatus("REJECTED");
                groupGoalRepository.save(proposal);
            }
        }
        // the votes are finished
        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupId(group.getId())){
            if(groupMember.getVotedGoal() != null){
                groupMember.setVotedGoal(null);
                groupMemberRepository.save(groupMember);
            }
        }
        return chosen;
    }
}
