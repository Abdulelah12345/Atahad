package com.example.atahad.Controller;

import com.example.atahad.Entity.Excuse;
import com.example.atahad.Service.ExcuseService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.ExcuseRequest;
import com.example.atahad.Entity.User;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import java.util.List;

@RestController
@RequestMapping("/api/v1/excuse")
@RequiredArgsConstructor
public class ExcuseController {

    private final ExcuseService excuseService;

    @GetMapping("/get")
    public ResponseEntity<List<Excuse>> getAllExcuses() {
        return ResponseEntity.ok(excuseService.getAllExcuses());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getExcuseById(
            @AuthenticationPrincipal User user,
            @PathVariable Integer id) {

        Integer userId = user.getId();

        Excuse excuse = excuseService.getExcuseById(userId, id);

        return ResponseEntity.status(200).body(excuse);
    }

    @PostMapping("/add/goal-task/{goalTaskId}/week/{commitmentWeekId}")
    public ResponseEntity<?> addGoalTaskExcuse(
            @AuthenticationPrincipal User user,
            @PathVariable Integer goalTaskId,
            @PathVariable Integer commitmentWeekId,
            @RequestBody @Valid ExcuseRequest request) {

        Integer userId = user.getId();

        excuseService.addGoalTaskExcuse(
                userId, goalTaskId, commitmentWeekId, request);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Excuse added successfully"));
    }

    @PutMapping("/update/goal-task/{excuseId}")
    public ResponseEntity<?> updateGoalTaskExcuse(
            @AuthenticationPrincipal User user,
            @PathVariable Integer excuseId,
            @RequestBody @Valid ExcuseRequest request) {

        Integer userId = user.getId();

        excuseService.updateGoalTaskExcuse(userId, excuseId, request);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Excuse updated successfully"));
    }

    @DeleteMapping("/delete/goal-task/{excuseId}")
    public ResponseEntity<?> deleteGoalTaskExcuse(
            @AuthenticationPrincipal User user,
            @PathVariable Integer excuseId) {

        Integer userId = user.getId();

        excuseService.deleteGoalTaskExcuse(userId, excuseId);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Excuse deleted successfully"));
    }
}