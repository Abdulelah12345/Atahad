package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GoalPlanRequest;
import com.example.atahad.Dto.In.GoalSuggestRequest;
import com.example.atahad.Dto.In.PlanWeekRequest;
import com.example.atahad.Dto.Out.GoalPlanResponse;
import com.example.atahad.Dto.Out.GoalProgressResponse;
import com.example.atahad.Dto.Out.PlanWeekResponse;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.GoalTask;
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
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class GoalService {
    private final GoalRepository goalRepository;
    private final MemberRepository memberRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final AiService aiService;

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

    // the member writes his goal and its end date, the AI suggests how many times every week (nothing is saved)
    public GoalPlanResponse suggestPlan(Integer memberId, GoalSuggestRequest dto){
        if(memberRepository.findMemberById(memberId) == null){
            throw new ApiException("Member not found");
        }
        LocalDate today = LocalDate.now();
        LocalDate firstSaturday = today.with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
        LocalDate lastSaturday = dto.getEndDate().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
        int totalWeeks = (int) ChronoUnit.WEEKS.between(firstSaturday, lastSaturday) + 1;
        if(totalWeeks > 52){
            throw new ApiException("A goal can be 52 weeks max");
        }
        int firstWeekDays = (int) ChronoUnit.DAYS.between(today, firstSaturday) + 1;

        String fallback = "PROOF: PHOTO\nNOTE: خطة ثابتة، تقدر تعدّلها";
        String answer = aiService.ask(
                "You plan goals in a commitment app. The goal is split into weeks (Sunday to Saturday). "
                        + "Suggest for every week a short task title and how many times (1 to 7) the person must do it that week, "
                        + "starting easy and growing step by step so the goal is reached by the last week. "
                        + "Choose the best proof method: LOCATION (being in a place), PHOTO, QUIZ (learning), PLATFORM (an app or website), TIMER (time spent). "
                        + "Answer only with these lines:\nPROOF: one method\nNOTE: one short sentence in Arabic about the plan\n"
                        + "then one line for every week: WEEK number | task title in Arabic | times",
                "Goal: " + dto.getGoal() + "\nNumber of weeks: " + totalWeeks
                        + "\nWeek 1 has only " + firstWeekDays + " days left",
                fallback);

        String proof = aiService.field(answer, "PROOF");
        if(proof == null || !proof.toUpperCase().matches("^(LOCATION|PHOTO|QUIZ|PLATFORM|TIMER)$")){
            proof = "PHOTO";
        }
        List<PlanWeekResponse> weeks = new ArrayList<>();
        for(String line : answer.split("\n")){
            String clean = line.replace("*", "").trim();
            if(!clean.toUpperCase().startsWith("WEEK")){
                continue;
            }
            String[] parts = clean.split("\\|");
            if(parts.length < 3){
                continue;
            }
            try{
                int times = Integer.parseInt(parts[2].replaceAll("[^0-9]", ""));
                weeks.add(new PlanWeekResponse(weeks.size() + 1, cut(parts[1].trim(), 100), times));
            }catch(NumberFormatException ignored){
            }
            if(weeks.size() == totalWeeks){
                break;
            }
        }
        // missing weeks repeat the last one, the numbers stay inside the rules
        while(weeks.size() < totalWeeks){
            PlanWeekResponse last = weeks.isEmpty() ? new PlanWeekResponse(0, dto.getGoal(), 3) : weeks.get(weeks.size() - 1);
            weeks.add(new PlanWeekResponse(weeks.size() + 1, cut(last.getTitle(), 100), last.getTimesPerWeek()));
        }
        for(PlanWeekResponse week : weeks){
            int max = week.getWeekNumber() == 1 ? Math.min(7, firstWeekDays) : 7;
            week.setTimesPerWeek(Math.max(1, Math.min(max, week.getTimesPerWeek())));
        }
        return new GoalPlanResponse(cut(dto.getGoal(), 100), lastSaturday, totalWeeks, proof.toUpperCase(),
                aiService.field(answer, "NOTE"), weeks);
    }

    // the plan the member agreed on (or changed): the goal, a task for every week, and week 1 starts now
    @Transactional
    public Goal addWithPlan(Integer memberId, GoalPlanRequest dto){
        Goal goal = new Goal();
        goal.setTitle(dto.getTitle());
        goal.setDescription(dto.getDescription());
        goal.setProofMethod(dto.getProofMethod());
        goal.setTotalWeeks(dto.getWeeks().size());
        addGoal(memberId, goal);

        int weekNumber = 1;
        for(PlanWeekRequest week : dto.getWeeks()){
            GoalTask task = new GoalTask();
            task.setGoal(goal);
            task.setWeekNumber(weekNumber++);
            task.setTitle(week.getTitle());
            task.setTimesPerWeek(week.getTimesPerWeek());
            task.setAmountPerTime(dto.getAmountPerTime());
            task.setProofMethod(dto.getProofMethod());
            task.setCompletedCount(0);
            task.setExcusedCount(0);
            goalTaskRepository.save(task);
        }
        startGoal(memberId, goal.getId());
        return goal;
    }

    private String cut(String text, int max){
        return text.length() > max ? text.substring(0, max) : text;
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
