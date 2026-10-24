package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.GoalPlanRequest;
import com.example.atahad.Dto.In.GoalSuggestRequest;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.GoalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/goal")
@RequiredArgsConstructor
public class GoalController {
    private final GoalService goalService;

    // admin
    @GetMapping("/get")
    public ResponseEntity<?> getAllGoals(){
        return ResponseEntity.status(200).body(goalService.getAllGoals());
    }

    @GetMapping("/getMyGoals")
    public ResponseEntity<?> getMyGoals(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(goalService.getMyGoals(user.getId()));
    }

    @PostMapping("/add")
    public ResponseEntity<?> addGoal(@AuthenticationPrincipal User user, @RequestBody @Valid Goal goal){
        goalService.addGoal(user.getId(), goal);
        return ResponseEntity.status(200).body(new ApiResponse("Goal added"));
    }

    // the AI suggests the times of every week from the goal and its end date (nothing is saved)
    @PostMapping("/suggest")
    public ResponseEntity<?> suggestPlan(@AuthenticationPrincipal User user, @RequestBody @Valid GoalSuggestRequest dto){
        return ResponseEntity.status(200).body(goalService.suggestPlan(user.getId(), dto));
    }

    // the plan after the member agreed or changed it: saves the goal and its weekly tasks and starts it
    @PostMapping("/addWithPlan")
    public ResponseEntity<?> addWithPlan(@AuthenticationPrincipal User user, @RequestBody @Valid GoalPlanRequest dto){
        return ResponseEntity.status(200).body(goalService.addWithPlan(user.getId(), dto));
    }

    // after adding the tasks of week 1
    @PutMapping("/start/{id}")
    public ResponseEntity<?> startGoal(@AuthenticationPrincipal User user, @PathVariable Integer id){
        goalService.startGoal(user.getId(), id);
        return ResponseEntity.status(200).body(new ApiResponse("Goal started, week 1 ends this saturday"));
    }

    @GetMapping("/progress/{id}")
    public ResponseEntity<?> getProgress(@AuthenticationPrincipal User user, @PathVariable Integer id){
        return ResponseEntity.status(200).body(goalService.getProgress(user.getId(), id));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateGoal(@AuthenticationPrincipal User user, @PathVariable Integer id, @RequestBody @Valid Goal goal){
        goalService.updateGoal(user.getId(), id, goal);
        return ResponseEntity.status(200).body(new ApiResponse("Goal updated"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteGoal(@AuthenticationPrincipal User user, @PathVariable Integer id){
        goalService.deleteGoal(user.getId(), id);
        return ResponseEntity.status(200).body(new ApiResponse("Goal deleted"));
    }
}
