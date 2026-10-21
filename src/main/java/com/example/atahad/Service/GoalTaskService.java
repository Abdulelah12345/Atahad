package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GoalTaskRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.HashSet;
import java.util.List;

@Service
@RequiredArgsConstructor
public class GoalTaskService {
    private final GoalTaskRepository goalTaskRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GoalService goalService;

    public List<GoalTask> getTasksByGoal(Integer memberId, Integer goalId){
        Goal goal = goalService.getMyGoal(memberId, goalId);
        return goalTaskRepository.findGoalTasksByGoalOrderByWeekNumber(goal);
    }

    public List<GoalTask> getTasksByWeek(Integer memberId, Integer goalId, Integer weekNumber){
        Goal goal = goalService.getMyGoal(memberId, goalId);
        return goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, weekNumber);
    }

    // a task for one week
    public void addTask(Integer memberId, Integer goalId, GoalTask task){
        Goal goal = goalService.getMyGoal(memberId, goalId);
        checkWeekCanChange(goal, task.getWeekNumber());
        saveNewTask(goal, task, task.getWeekNumber());
    }

    // the same task for every week that did not start yet
    public void addTaskToAllWeeks(Integer memberId, Integer goalId, GoalTask task){
        Goal goal = goalService.getMyGoal(memberId, goalId);
        // the body is not @Valid here because it has no week number, so the fields are checked by hand
        if(task.getTitle() == null || task.getTitle().isBlank()){
            throw new ApiException("Title cannot be empty");
        }
        if(task.getTimesPerWeek() == null || task.getTimesPerWeek() < 1 || task.getTimesPerWeek() > 7){
            throw new ApiException("Times per week must be between 1 and 7");
        }
        if(task.getAmountPerTime() == null || task.getAmountPerTime().compareTo(new BigDecimal("5.00")) < 0){
            throw new ApiException("Amount per time must be at least 5");
        }
        if(goal.getStatus().equals("WITHDRAWN") || goal.getStatus().equals("ENDED")){
            throw new ApiException("Goal is finished and cannot be changed");
        }
        int firstWeek = lastStartedWeek(goal) + 1;
        if(firstWeek > goal.getTotalWeeks()){
            throw new ApiException("All the weeks of this goal already started");
        }
        for(int week = firstWeek; week <= goal.getTotalWeeks(); week++){
            GoalTask copy = new GoalTask();
            copy.setTitle(task.getTitle());
            copy.setTimesPerWeek(task.getTimesPerWeek());
            copy.setAmountPerTime(task.getAmountPerTime());
            copy.setPlannedDays(task.getPlannedDays() == null ? null : new HashSet<>(task.getPlannedDays()));
            saveNewTask(goal, copy, week);
        }
    }

    // only tasks of weeks that did not start yet can change
    public void updateTask(Integer memberId, Integer id, GoalTask task){
        GoalTask oldTask = getMyTask(memberId, id);
        checkWeekCanChange(oldTask.getGoal(), oldTask.getWeekNumber());
        oldTask.setTitle(task.getTitle());
        oldTask.setTimesPerWeek(task.getTimesPerWeek());
        oldTask.setAmountPerTime(task.getAmountPerTime());
        oldTask.setPlannedDays(task.getPlannedDays());
        goalTaskRepository.save(oldTask);
    }

    public void deleteTask(Integer memberId, Integer id){
        GoalTask task = getMyTask(memberId, id);
        checkWeekCanChange(task.getGoal(), task.getWeekNumber());
        goalTaskRepository.delete(task);
    }

    private void saveNewTask(Goal goal, GoalTask task, Integer weekNumber){
        task.setGoal(goal);
        task.setWeekNumber(weekNumber);
        task.setCompletedCount(0);
        task.setExcusedCount(0);
        task.setTrackStatus(null); // set when the week starts
        goalTaskRepository.save(task);
    }

    private GoalTask getMyTask(Integer memberId, Integer id){
        GoalTask task = goalTaskRepository.findGoalTaskById(id);
        if(task == null){
            throw new ApiException("Task not found");
        }
        if(!task.getGoal().getMember().getId().equals(memberId)){
            throw new ApiException("You can only change your own task");
        }
        return task;
    }

    private void checkWeekCanChange(Goal goal, Integer weekNumber){
        if(goal.getStatus().equals("WITHDRAWN") || goal.getStatus().equals("ENDED")){
            throw new ApiException("Goal is finished and cannot be changed");
        }
        if(weekNumber == null || weekNumber < 1 || weekNumber > goal.getTotalWeeks()){
            throw new ApiException("Week number must be between 1 and " + goal.getTotalWeeks());
        }
        if(weekNumber <= lastStartedWeek(goal)){
            throw new ApiException("This week already started, you can change the next weeks only");
        }
    }

    // 0 when no week started yet
    private int lastStartedWeek(Goal goal){
        CommitmentWeek lastWeek = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(goal);
        if(lastWeek == null){
            return 0;
        }
        return lastWeek.getWeekNumber();
    }
}
