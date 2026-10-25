package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.CommitmentTargetRequest;
import com.example.atahad.Dto.In.GoalSuggestRequest;
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

    // the owner writes the goal and its end date, the AI suggests a task and times for every week (nothing is saved),
    // then the owner sends the weeks he agreed on (or changed) with /add
    @PostMapping("/suggest/{groupId}")
    public ResponseEntity<?> suggestPlan(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @RequestBody @Valid GoalSuggestRequest dto){
        return ResponseEntity.status(200).body(groupGoalService.suggestPlan(groupId, user.getId(), dto));
    }

    // the owner confirms the goal (proposalId in the body when it came from the vote, weeks when he chose a plan)
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

    // my task of the goal this week, to prove it from the group page
    @GetMapping("/my-task/{groupId}")
    public ResponseEntity<?> getMyTask(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupGoalService.getMyTask(groupId, user.getId()));
    }

    // LOCATION goal: the place of the member (null until he chooses it)
    @GetMapping("/my-place/{groupId}")
    public ResponseEntity<?> getMyPlace(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupGoalService.getMyPlace(groupId, user.getId()));
    }

    @PutMapping("/my-place/{groupId}")
    public ResponseEntity<?> setMyPlace(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @RequestBody @Valid CommitmentTargetRequest dto){
        groupGoalService.setMyPlace(groupId, user.getId(), dto);
        return ResponseEntity.status(200).body(new ApiResponse("Your place is saved"));
    }
}
