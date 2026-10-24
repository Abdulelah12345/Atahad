package com.example.atahad.Controller;

import com.example.atahad.Dto.In.GroupGoalRequest;
import com.example.atahad.Service.GroupGoalService;
import jakarta.validation.Valid;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-goal")
@RequiredArgsConstructor
public class GroupGoalController {
    private final GroupGoalService groupGoalService;

    // the owner confirms the goal (proposalId in the body when it came from the vote)
    @PostMapping("/add/{groupId}")
    public ResponseEntity<?> createGoal(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @RequestBody @Valid GroupGoalRequest dto){
        return ResponseEntity.status(200).body(groupGoalService.createGoal(groupId, user.getId(), dto));
    }

    @GetMapping("/active/{groupId}")
    public ResponseEntity<?> getActiveGoal(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupGoalService.getActiveGoal(groupId, user.getId()));
    }

    @GetMapping("/history/{groupId}")
    public ResponseEntity<?> getGoalHistory(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupGoalService.getGoalHistory(groupId, user.getId()));
    }

    // the group screen: every member and what is left this week
    @GetMapping("/board/{groupId}")
    public ResponseEntity<?> getBoard(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupGoalService.getBoard(groupId, user.getId()));
    }
}
