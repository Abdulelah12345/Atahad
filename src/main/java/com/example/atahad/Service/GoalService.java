package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.GoalProgressResponse;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GoalRepository;
import com.example.atahad.Repository.GoalTaskRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.List;

@Service
@RequiredArgsConstructor
public class GoalService {
    private final GoalRepository goalRepository;
    private final MemberRepository memberRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final CommitmentWeekService commitmentWeekService;

    // admin
    public List<Goal> getAllGoals(){
        return goalRepository.findAll();
    }

    public List<Goal> getMyGoals(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return goalRepository.findGoalsByMember(member);
    }

    // the tasks of every week are added after the goal from the goal task endpoints, then the goal is started
    public void addGoal(Integer memberId, Goal goal){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        if(Boolean.TRUE.equals(member.getIsLocked())){
            throw new ApiException("Your app is locked, donate first to add a new goal");
        }
        goal.setMember(member);
        goal.setStatus("ACTIVE");
        goal.setEffectiveFrom(LocalDate.now());
        goal.setBaseAmount(null); // goals use the amount of each task
        goal.setPendingBaseAmount(null);
        goal.setEndDate(calculateEndDate(goal.getTotalWeeks()));
        goalRepository.save(goal);
    }

    // week 1 starts now and ends this saturday
    @Transactional
    public void startGoal(Integer memberId, Integer id){
        Goal goal = getMyGoal(memberId, id);
        if(!goal.getStatus().equals("ACTIVE")){
            throw new ApiException("Goal is finished");
        }
        if(hasStarted(goal)){
            throw new ApiException("Goal already started");
        }
        if(goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, 1).isEmpty()){
            throw new ApiException("Add the tasks of week 1 first");
        }
        goal.setEffectiveFrom(LocalDate.now());
        goal.setEndDate(calculateEndDate(goal.getTotalWeeks()));
        goalRepository.save(goal);

        commitmentWeekService.startFirstWeek(goal);
    }

    // the weeks count and the proof method can change only before the first week starts
    public void updateGoal(Integer memberId, Integer id, Goal goal){
        Goal oldGoal = getMyGoal(memberId, id);
        if(oldGoal.getStatus().equals("WITHDRAWN") || oldGoal.getStatus().equals("ENDED")){
            throw new ApiException("Goal is finished and cannot be updated");
        }
        oldGoal.setTitle(goal.getTitle());
        oldGoal.setDescription(goal.getDescription());
        if(!hasStarted(oldGoal)){
            oldGoal.setProofMethod(goal.getProofMethod());
            oldGoal.setTotalWeeks(goal.getTotalWeeks());
            oldGoal.setEndDate(calculateEndDate(goal.getTotalWeeks()));
        }else{
            if(!oldGoal.getProofMethod().equals(goal.getProofMethod())){
                throw new ApiException("Proof method cannot change after the goal starts");
            }
            if(!oldGoal.getTotalWeeks().equals(goal.getTotalWeeks())){
                throw new ApiException("Total weeks cannot change after the goal starts");
            }
        }
        goalRepository.save(oldGoal);
    }

    // only a goal that did not start yet can be deleted, after that it is withdrawn
    public void deleteGoal(Integer memberId, Integer id){
        Goal goal = getMyGoal(memberId, id);
        if(hasStarted(goal)){
            throw new ApiException("Goal already started, withdraw from it instead");
        }
        goalRepository.delete(goal);
    }

    // how far the member is in the goal
    public GoalProgressResponse getProgress(Integer memberId, Integer id){
        Goal goal = getMyGoal(memberId, id);
        List<CommitmentWeek> weeks = commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(goal);

        int currentWeek = weeks.isEmpty() ? 0 : weeks.get(0).getWeekNumber();
        int fullWeeks = 0;
        int required = 0;
        int completed = 0;
        for(CommitmentWeek week : weeks){
            if(Boolean.TRUE.equals(week.getIsFullWeek())){
                fullWeeks++;
            }
            required += week.getRequired();
            completed += week.getCompleted();
        }
        int percent = required == 0 ? 0 : Math.min(100, completed * 100 / required);

        return new GoalProgressResponse(goal.getId(), goal.getTitle(), goal.getStatus(), goal.getTotalWeeks(),
                currentWeek, Math.max(0, goal.getTotalWeeks() - currentWeek), fullWeeks,
                required, completed, percent, goal.getEndDate());
    }

    public Goal getMyGoal(Integer memberId, Integer id){
        Goal goal = goalRepository.findGoalById(id);
        if(goal == null){
            throw new ApiException("Goal not found");
        }
        if(!goal.getMember().getId().equals(memberId)){
            throw new ApiException("You can only change your own goal");
        }
        return goal;
    }

    // the first week ends this saturday, the last week ends after the rest of the weeks
    private LocalDate calculateEndDate(Integer totalWeeks){
        LocalDate firstSaturday = LocalDate.now().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
        return firstSaturday.plusWeeks(totalWeeks - 1);
    }

    // true when week 1 was started
    private boolean hasStarted(Goal commitment){
        return commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment) != null;
    }
}
