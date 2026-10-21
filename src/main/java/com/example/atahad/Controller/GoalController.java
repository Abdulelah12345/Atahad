package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
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
