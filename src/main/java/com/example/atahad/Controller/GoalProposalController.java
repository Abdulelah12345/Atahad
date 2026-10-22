package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.GoalProposalRequest;
import com.example.atahad.Service.GoalProposalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/goal-proposal")
@RequiredArgsConstructor
public class GoalProposalController {
    private final GoalProposalService goalProposalService;

    // the AI suggests 3 goals
    @PostMapping("/ai/{groupId}/{memberId}")
    public ResponseEntity<?> suggestWithAi(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(goalProposalService.suggestWithAi(groupId, memberId));
    }

    @PostMapping("/add/{groupId}/{memberId}")
    public ResponseEntity<?> propose(@PathVariable Integer groupId, @PathVariable Integer memberId, @RequestBody @Valid GoalProposalRequest dto){
        goalProposalService.propose(groupId, memberId, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Proposal added"));
    }

    // with the votes, most voted first
    @GetMapping("/open/{groupId}/{memberId}")
    public ResponseEntity<?> getOpenProposals(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(goalProposalService.getOpenProposals(groupId, memberId));
    }

    @PutMapping("/vote/{proposalId}/{memberId}")
    public ResponseEntity<?> vote(@PathVariable Integer proposalId, @PathVariable Integer memberId){
        goalProposalService.vote(proposalId, memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Vote saved"));
    }

    @PutMapping("/reject/{proposalId}/{ownerId}")
    public ResponseEntity<?> reject(@PathVariable Integer proposalId, @PathVariable Integer ownerId){
        goalProposalService.reject(proposalId, ownerId);
        return ResponseEntity.status(200).body(new ApiResponse("Proposal rejected"));
    }
}
