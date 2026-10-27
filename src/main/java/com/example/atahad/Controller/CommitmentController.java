package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.User;

import com.example.atahad.Dto.In.CommitmentTargetRequest;
import jakarta.validation.Valid;
import com.example.atahad.Service.CommitmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/commitment")
@RequiredArgsConstructor
public class CommitmentController {
    private final CommitmentService commitmentService;

    @GetMapping("/getMyCommitments")
    public ResponseEntity<?> getMyCommitments(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(commitmentService.getMyCommitments(user.getId()));
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getCommitment(@AuthenticationPrincipal User user, @PathVariable Integer id){
        return ResponseEntity.status(200).body(commitmentService.getCommitment(user.getId(), id));
    }

    @PutMapping("/withdraw/{id}")
    public ResponseEntity<?> withdraw(@AuthenticationPrincipal User user, @PathVariable Integer id){
        boolean waits = commitmentService.withdraw(user.getId(), id);
        return ResponseEntity.status(200).body(new ApiResponse(waits ? "WITHDRAW_AT_WEEK_END" : "WITHDRAWN"));
    }

    @PutMapping("/withdraw/cancel/{id}")
    public ResponseEntity<?> cancelWithdraw(@AuthenticationPrincipal User user, @PathVariable Integer id){
        commitmentService.cancelWithdraw(user.getId(), id);
        return ResponseEntity.status(200).body(new ApiResponse("Withdrawal canceled"));
    }

    // LOCATION: the place from the map (a group member sets his own), TIMER: the minutes
    @PutMapping("/target/{id}")
    public ResponseEntity<?> setTarget(@AuthenticationPrincipal User user, @PathVariable Integer id, @RequestBody @Valid CommitmentTargetRequest dto){
        commitmentService.setTarget(user.getId(), id, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Target saved"));
    }

    // the lock screen
    @GetMapping("/lockStatus")
    public ResponseEntity<?> getLockStatus(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(commitmentService.getLockStatus(user.getId()));
    }

    // level, points, grace days and total donated
    @GetMapping("/stats")
    public ResponseEntity<?> getStats(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(commitmentService.getStats(user.getId()));
    }
    @GetMapping("/learning-goal")
    public ResponseEntity<?> hasLearningGoal(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(commitmentService.hasLearningGoal(user.getId()));
    }
}
