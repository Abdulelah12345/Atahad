package com.example.atahad.Controller;

import com.example.atahad.Dto.In.GroupGoalRequest;
import com.example.atahad.Service.GroupGoalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-goal")
@RequiredArgsConstructor
public class GroupGoalController {
    private final GroupGoalService groupGoalService;

    // the owner confirms the goal (proposalId in the body when it came from the vote)
    @PostMapping("/add/{groupId}/{ownerId}")
    public ResponseEntity<?> createGoal(@PathVariable Integer groupId, @PathVariable Integer ownerId, @RequestBody @Valid GroupGoalRequest dto){
        return ResponseEntity.status(200).body(groupGoalService.createGoal(groupId, ownerId, dto));
    }

    @GetMapping("/active/{groupId}/{memberId}")
    public ResponseEntity<?> getActiveGoal(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupGoalService.getActiveGoal(groupId, memberId));
    }

    @GetMapping("/history/{groupId}/{memberId}")
    public ResponseEntity<?> getGoalHistory(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupGoalService.getGoalHistory(groupId, memberId));
    }

    // the group screen: every member and what is left this week
    @GetMapping("/board/{groupId}/{memberId}")
    public ResponseEntity<?> getBoard(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupGoalService.getBoard(groupId, memberId));
    }
}
