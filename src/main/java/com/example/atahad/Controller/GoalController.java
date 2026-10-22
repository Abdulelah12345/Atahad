package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.GoalPlanRequest;
import com.example.atahad.Dto.In.GoalSuggestRequest;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Service.GoalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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

    @GetMapping("/getMyGoals/{memberId}")
    public ResponseEntity<?> getMyGoals(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(goalService.getMyGoals(memberId));
    }

    @PostMapping("/add/{memberId}")
    public ResponseEntity<?> addGoal(@PathVariable Integer memberId, @RequestBody @Valid Goal goal){
        goalService.addGoal(memberId, goal);
        return ResponseEntity.status(200).body(new ApiResponse("Goal added"));
    }

    // the AI suggests the times of every week from the goal and its end date (nothing is saved)
    @PostMapping("/suggest/{memberId}")
    public ResponseEntity<?> suggestPlan(@PathVariable Integer memberId, @RequestBody @Valid GoalSuggestRequest dto){
        return ResponseEntity.status(200).body(goalService.suggestPlan(memberId, dto));
    }

    // the plan after the member agreed or changed it: saves the goal and its weekly tasks and starts it
    @PostMapping("/addWithPlan/{memberId}")
    public ResponseEntity<?> addWithPlan(@PathVariable Integer memberId, @RequestBody @Valid GoalPlanRequest dto){
        return ResponseEntity.status(200).body(goalService.addWithPlan(memberId, dto));
    }

    // after adding the tasks of week 1
    @PutMapping("/start/{memberId}/{id}")
    public ResponseEntity<?> startGoal(@PathVariable Integer memberId, @PathVariable Integer id){
        goalService.startGoal(memberId, id);
        return ResponseEntity.status(200).body(new ApiResponse("Goal started, week 1 ends this saturday"));
    }

    @GetMapping("/progress/{memberId}/{id}")
    public ResponseEntity<?> getProgress(@PathVariable Integer memberId, @PathVariable Integer id){
        return ResponseEntity.status(200).body(goalService.getProgress(memberId, id));
    }

    @PutMapping("/update/{memberId}/{id}")
    public ResponseEntity<?> updateGoal(@PathVariable Integer memberId, @PathVariable Integer id, @RequestBody @Valid Goal goal){
        goalService.updateGoal(memberId, id, goal);
        return ResponseEntity.status(200).body(new ApiResponse("Goal updated"));
    }

    @DeleteMapping("/delete/{memberId}/{id}")
    public ResponseEntity<?> deleteGoal(@PathVariable Integer memberId, @PathVariable Integer id){
        goalService.deleteGoal(memberId, id);
        return ResponseEntity.status(200).body(new ApiResponse("Goal deleted"));
    }
}
