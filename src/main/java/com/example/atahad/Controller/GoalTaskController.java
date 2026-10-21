package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Service.GoalTaskService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/goal-task")
@RequiredArgsConstructor
public class GoalTaskController {
    private final GoalTaskService goalTaskService;

    @GetMapping("/getByGoal/{memberId}/{goalId}")
    public ResponseEntity<?> getTasksByGoal(@PathVariable Integer memberId, @PathVariable Integer goalId){
        return ResponseEntity.status(200).body(goalTaskService.getTasksByGoal(memberId, goalId));
    }

    @GetMapping("/getByWeek/{memberId}/{goalId}/{weekNumber}")
    public ResponseEntity<?> getTasksByWeek(@PathVariable Integer memberId, @PathVariable Integer goalId, @PathVariable Integer weekNumber){
        return ResponseEntity.status(200).body(goalTaskService.getTasksByWeek(memberId, goalId, weekNumber));
    }

    @PostMapping("/add/{memberId}/{goalId}")
    public ResponseEntity<?> addTask(@PathVariable Integer memberId, @PathVariable Integer goalId, @RequestBody @Valid GoalTask task){
        goalTaskService.addTask(memberId, goalId, task);
        return ResponseEntity.status(200).body(new ApiResponse("Task added"));
    }

    // weekNumber is ignored here, the task is copied to every week that did not start
    @PostMapping("/addToAllWeeks/{memberId}/{goalId}")
    public ResponseEntity<?> addTaskToAllWeeks(@PathVariable Integer memberId, @PathVariable Integer goalId, @RequestBody GoalTask task){
        goalTaskService.addTaskToAllWeeks(memberId, goalId, task);
        return ResponseEntity.status(200).body(new ApiResponse("Task added to all the coming weeks"));
    }

    @PutMapping("/update/{memberId}/{id}")
    public ResponseEntity<?> updateTask(@PathVariable Integer memberId, @PathVariable Integer id, @RequestBody @Valid GoalTask task){
        goalTaskService.updateTask(memberId, id, task);
        return ResponseEntity.status(200).body(new ApiResponse("Task updated"));
    }

    @DeleteMapping("/delete/{memberId}/{id}")
    public ResponseEntity<?> deleteTask(@PathVariable Integer memberId, @PathVariable Integer id){
        goalTaskService.deleteTask(memberId, id);
        return ResponseEntity.status(200).body(new ApiResponse("Task deleted"));
    }
}
