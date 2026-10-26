package com.example.atahad.Service;

import com.example.atahad.Dto.Out.PlaceResponse;
import com.example.atahad.Dto.Out.TodayTaskResponse;
import com.example.atahad.Dto.In.CommitmentTargetRequest;
import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GoalSuggestRequest;
import com.example.atahad.Dto.In.GroupGoalRequest;
import com.example.atahad.Dto.In.PlanWeekRequest;
import com.example.atahad.Dto.Out.GoalPlanResponse;
import com.example.atahad.Dto.Out.GroupBoardResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;

// a group has one goal at a time, every member gets his own habit from it
// (or his own goal with a task for every week, when the owner chose a plan of weeks)
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
    private final GoalRepository goalRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final GoalService goalService;
    private final CommitmentService commitmentService;

    // a week of the plan
    public record WeekTask(String title, Integer timesPerWeek) {}

    // the owner writes the goal and its end date, the AI suggests a task and the times for every week (nothing is saved)
    // the same AI of the personal goals (GoalService.suggestPlan)
    public GoalPlanResponse suggestPlan(Integer groupId, Integer ownerId, GoalSuggestRequest dto){
        groupAccessService.checkOwner(groupId, ownerId);
        return goalService.suggestPlan(ownerId, dto);
    }

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
        // a plan of weeks, or the same times every week
        List<WeekTask> plan = null;
        if(dto.getWeeks() != null && !dto.getWeeks().isEmpty()){
            plan = new ArrayList<>();
            for(PlanWeekRequest week : dto.getWeeks()){
                plan.add(new WeekTask(week.getTitle(), week.getTimesPerWeek()));
            }
        }else if(dto.getTimesPerWeek() == null || dto.getTotalWeeks() == null){
            throw new ApiException("Write the times per week and the weeks, or choose a plan of weeks");
        }
        int totalWeeks = plan == null ? dto.getTotalWeeks() : plan.size();
        goal.setTimesPerWeek(plan == null ? dto.getTimesPerWeek() : plan.get(0).timesPerWeek());
        goal.setAmountPerTime(dto.getAmountPerTime());
        goal.setDifficulty(dto.getDifficulty() == null ? "SOLO" : dto.getDifficulty());
        goal.setTotalWeeks(totalWeeks);
        if("TIMER".equals(dto.getProofMethod()) && dto.getTargetMinutes() == null){
            throw new ApiException("A TIMER goal needs the minutes of one time");
        }
        goal.setTargetMinutes(dto.getTargetMinutes());
        goal.setStartDate(LocalDate.now());
        goal.setEndDate(LocalDate.now().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY)).plusWeeks(totalWeeks - 1));
        goal.setStatus("ACTIVE");
        goal.setGroup(group);
        groupGoalRepository.save(goal);

        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupId, "ACTIVE")){
            if(plan == null){
                addMemberCommitment(goal, groupMember.getMember());
            }else{
                addMemberGoal(goal, groupMember.getMember(), plan);
            }
        }
        if(plan == null){
            groupAccessService.systemMessage(group, "New goal: " + goal.getTitle() + ", " + goal.getTimesPerWeek()
                    + " times a week for " + goal.getTotalWeeks() + " weeks, " + goal.getAmountPerTime() + " SAR for every missed time");
        }else{
            groupAccessService.systemMessage(group, "New goal: " + goal.getTitle() + ", a plan of " + goal.getTotalWeeks()
                    + " weeks (week 1: " + plan.get(0).title() + ", " + plan.get(0).timesPerWeek() + " times), "
                    + goal.getAmountPerTime() + " SAR for every missed time");
        }
        return goal;
    }

    // a habit for the member, linked to the group goal
    // (when the goal has a plan, a member who joins later gets the weeks that are left of the same plan)
    @Transactional
    public void addMemberCommitment(GroupGoal goal, Member member){
        Goal model = planOf(goal);
        if(model != null){
            List<WeekTask> left = weeksLeft(goal, model);
            if(!left.isEmpty()){
                addMemberGoal(goal, member, left);
            }
            return;
        }
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

    // a goal for the member with a task for every week, linked to the group goal, week 1 starts now
    @Transactional
    public void addMemberGoal(GroupGoal groupGoal, Member member, List<WeekTask> weeks){
        Goal goal = new Goal();
        goal.setTitle(groupGoal.getTitle());
        goal.setDescription(groupGoal.getDetails());
        goal.setProofMethod(groupGoal.getProofMethod());
        goal.setTargetMinutes(groupGoal.getTargetMinutes()); // LOCATION: the member sets his own place with /commitment/target
        goal.setTotalWeeks(weeks.size());
        goal.setMember(member);
        goal.setStatus("ACTIVE");
        goal.setEffectiveFrom(LocalDate.now());
        goal.setBaseAmount(null); // goals use the amount of each task
        goal.setEndDate(groupGoal.getEndDate());
        goal.setGroupGoal(groupGoal);
        goalRepository.save(goal);

        // week 1 can not ask for more times than the days left until saturday
        LocalDate today = LocalDate.now();
        int daysLeft = (int) ChronoUnit.DAYS.between(today, today.with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY))) + 1;
        int number = 1;
        for(WeekTask week : weeks){
            GoalTask task = new GoalTask();
            task.setGoal(goal);
            task.setWeekNumber(number);
            task.setTitle(week.title());
            task.setTimesPerWeek(number == 1 ? Math.min(week.timesPerWeek(), daysLeft) : week.timesPerWeek());
            task.setAmountPerTime(groupGoal.getAmountPerTime());
            task.setProofMethod(groupGoal.getProofMethod());
            task.setCompletedCount(0);
            task.setExcusedCount(0);
            goalTaskRepository.save(task);
            number++;
        }
        commitmentWeekService.startFirstWeek(goal);
    }

    // the goal of one member that holds the plan (null when the group goal is the same times every week)
    private Goal planOf(GroupGoal groupGoal){
        for(Commitment commitment : commitmentRepository.findCommitmentsByGroupGoal(groupGoal)){
            if(commitment instanceof Goal goal){
                return goal;
            }
        }
        return null;
    }

    // the weeks of the plan from this week to the end (for a member who joins in the middle)
    private List<WeekTask> weeksLeft(GroupGoal groupGoal, Goal model){
        LocalDate firstSaturday = groupGoal.getStartDate().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
        LocalDate thisSaturday = LocalDate.now().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
        int groupWeek = (int) ChronoUnit.WEEKS.between(firstSaturday, thisSaturday) + 1;
        // the model may have joined late too, so its week 1 is not always the week 1 of the group
        LocalDate modelFirstSaturday = model.getEffectiveFrom().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
        int offset = (int) ChronoUnit.WEEKS.between(firstSaturday, modelFirstSaturday);
        List<WeekTask> left = new ArrayList<>();
        for(GoalTask task : goalTaskRepository.findGoalTasksByGoalOrderByWeekNumber(model)){
            if(task.getWeekNumber() + offset >= groupWeek){
                left.add(new WeekTask(task.getTitle(), task.getTimesPerWeek()));
            }
        }
        return left;
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

    // my task of the group goal this week (the same card as the today page), the app opens its proof from the group
    public TodayTaskResponse getMyTask(Integer groupId, Integer memberId){
        GroupGoal goal = getActiveGoal(groupId, memberId);
        Commitment commitment = getMemberCommitment(goal, groupAccessService.getMember(memberId));
        if(commitment == null){
            throw new ApiException("You are not in this goal");
        }
        for(TodayTaskResponse task : commitmentWeekService.getToday(memberId)){
            if(commitment.getId().equals(task.getCommitmentId())){
                return task;
            }
        }
        throw new ApiException("No task of this goal this week");
    }

    // the place of the member in a LOCATION goal (every member has his own place, like his own gym)
    public PlaceResponse getMyPlace(Integer groupId, Integer memberId){
        Commitment commitment = myLocationCommitment(groupId, memberId);
        if(commitment.getTargetLatitude() == null){
            return null;
        }
        return new PlaceResponse(commitment.getTargetPlaceName(), null,
                commitment.getTargetLatitude(), commitment.getTargetLongitude());
    }

    // he chose it from the search, it can change until his first accepted proof (checked in setTarget)
    public void setMyPlace(Integer groupId, Integer memberId, CommitmentTargetRequest dto){
        if(dto.getLatitude() == null || dto.getLongitude() == null){
            throw new ApiException("Choose the place first");
        }
        dto.setMinutes(null); // the minutes of a group goal are the same for every member
        Commitment commitment = myLocationCommitment(groupId, memberId);
        commitmentService.setTarget(memberId, commitment.getId(), dto);
    }

    private Commitment myLocationCommitment(Integer groupId, Integer memberId){
        GroupGoal goal = getActiveGoal(groupId, memberId);
        if(!"LOCATION".equals(goal.getProofMethod())){
            throw new ApiException("This goal is not proved with the location");
        }
        Commitment commitment = getMemberCommitment(goal, groupAccessService.getMember(memberId));
        if(commitment == null){
            throw new ApiException("You are not in this goal");
        }
        return commitment;
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
