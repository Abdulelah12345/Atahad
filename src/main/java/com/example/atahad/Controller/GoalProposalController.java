package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.GoalProposalRequest;
import com.example.atahad.Service.GoalProposalService;
import jakarta.validation.Valid;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/goal-proposal")
@RequiredArgsConstructor
public class GoalProposalController {
    private final GoalProposalService goalProposalService;

    // the AI suggests 3 goals
    @PostMapping("/ai/{groupId}")
    public ResponseEntity<?> suggestWithAi(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(goalProposalService.suggestWithAi(groupId, user.getId()));
    }

    @PostMapping("/add/{groupId}")
    public ResponseEntity<?> propose(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @RequestBody @Valid GoalProposalRequest dto){
        goalProposalService.propose(groupId, user.getId(), dto);
        return ResponseEntity.status(200).body(new ApiResponse("Proposal added"));
    }

    // with the votes, most voted first
    @GetMapping("/open/{groupId}")
    public ResponseEntity<?> getOpenProposals(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(goalProposalService.getOpenProposals(groupId, user.getId()));
    }

    @PutMapping("/vote/{proposalId}")
    public ResponseEntity<?> vote(@AuthenticationPrincipal User user, @PathVariable Integer proposalId){
        goalProposalService.vote(proposalId, user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Vote saved"));
    }

    @PutMapping("/reject/{proposalId}")
    public ResponseEntity<?> reject(@AuthenticationPrincipal User user, @PathVariable Integer proposalId){
        goalProposalService.reject(proposalId, user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Proposal rejected"));
    }
}
