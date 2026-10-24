package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.GoalTaskService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/goal-task")
@RequiredArgsConstructor
public class GoalTaskController {
    private final GoalTaskService goalTaskService;

    @GetMapping("/getByGoal/{goalId}")
    public ResponseEntity<?> getTasksByGoal(@AuthenticationPrincipal User user, @PathVariable Integer goalId){
        return ResponseEntity.status(200).body(goalTaskService.getTasksByGoal(user.getId(), goalId));
    }

    @GetMapping("/getByWeek/{goalId}/{weekNumber}")
    public ResponseEntity<?> getTasksByWeek(@AuthenticationPrincipal User user, @PathVariable Integer goalId, @PathVariable Integer weekNumber){
        return ResponseEntity.status(200).body(goalTaskService.getTasksByWeek(user.getId(), goalId, weekNumber));
    }

    @PostMapping("/add/{goalId}")
    public ResponseEntity<?> addTask(@AuthenticationPrincipal User user, @PathVariable Integer goalId, @RequestBody @Valid GoalTask task){
        goalTaskService.addTask(user.getId(), goalId, task);
        return ResponseEntity.status(200).body(new ApiResponse("Task added"));
    }

    // weekNumber is ignored here, the task is copied to every week that did not start
    @PostMapping("/addToAllWeeks/{goalId}")
    public ResponseEntity<?> addTaskToAllWeeks(@AuthenticationPrincipal User user, @PathVariable Integer goalId, @RequestBody GoalTask task){
        goalTaskService.addTaskToAllWeeks(user.getId(), goalId, task);
        return ResponseEntity.status(200).body(new ApiResponse("Task added to all the coming weeks"));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateTask(@AuthenticationPrincipal User user, @PathVariable Integer id, @RequestBody @Valid GoalTask task){
        goalTaskService.updateTask(user.getId(), id, task);
        return ResponseEntity.status(200).body(new ApiResponse("Task updated"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteTask(@AuthenticationPrincipal User user, @PathVariable Integer id){
        goalTaskService.deleteTask(user.getId(), id);
        return ResponseEntity.status(200).body(new ApiResponse("Task deleted"));
    }
}
