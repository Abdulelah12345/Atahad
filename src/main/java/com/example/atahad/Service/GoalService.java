package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.GoalRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.List;

@Service
@RequiredArgsConstructor
public class GoalService {
    private final GoalRepository goalRepository;
    private final MemberRepository memberRepository;

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

    // the tasks of every week are added after the goal from the goal task endpoints
    public void addGoal(Integer memberId, Goal goal){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        goal.setMember(member);
        goal.setStatus("DRAFT"); // becomes ACTIVE after the first hold succeeds
        goal.setEffectiveFrom(LocalDate.now());
        goal.setBaseAmount(null); // goals use the amount of each task
        goal.setPendingBaseAmount(null);
        goal.setEndDate(calculateEndDate(goal.getTotalWeeks()));
        goalRepository.save(goal);
    }

    // the weeks count and the proof method can change only while it is a draft
    public void updateGoal(Integer memberId, Integer id, Goal goal){
        Goal oldGoal = getMyGoal(memberId, id);
        if(oldGoal.getStatus().equals("WITHDRAWN") || oldGoal.getStatus().equals("ENDED")){
            throw new ApiException("Goal is finished and cannot be updated");
        }
        oldGoal.setTitle(goal.getTitle());
        oldGoal.setDescription(goal.getDescription());
        if(oldGoal.getStatus().equals("DRAFT")){
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

    // only a draft can be deleted, a running goal is withdrawn instead
    public void deleteGoal(Integer memberId, Integer id){
        Goal goal = getMyGoal(memberId, id);
        if(!goal.getStatus().equals("DRAFT")){
            throw new ApiException("Goal already started, withdraw from it instead");
        }
        goalRepository.delete(goal);
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
}
