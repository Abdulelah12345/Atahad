package com.example.atahad.Controller;

import com.example.atahad.Dto.In.ExcuseRequest;
import com.example.atahad.Dto.In.ProofRequest;
import com.example.atahad.Service.ExcuseDecisionService;
import com.example.atahad.Service.ProofDecisionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

// proofs and excuses of habits (personal and group), the goal tasks use /proof and /excuse
// the answer has the AI decision right away: ACCEPTED, REJECTED or ESCALATED
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class HabitCheckInController {
    private final com.example.atahad.Service.AuthenticatedUserService authenticatedUserService;
    private final ProofDecisionService proofDecisionService;
    private final ExcuseDecisionService excuseDecisionService;

    @PostMapping("/proof/habit/{memberId}/{weekId}")
    public ResponseEntity<?> addHabitProof(@PathVariable Integer memberId, @PathVariable Integer weekId, @RequestBody @Valid ProofRequest request){
        // the identity check is here, the scheduled visit close creates proofs too
        authenticatedUserService.checkMember(memberId);
        return ResponseEntity.status(200).body(proofDecisionService.addHabitProof(memberId, weekId, request));
    }

    // allowed while the app is locked
    @PostMapping("/excuse/habit/{memberId}/{weekId}")
    public ResponseEntity<?> addHabitExcuse(@PathVariable Integer memberId, @PathVariable Integer weekId, @RequestBody @Valid ExcuseRequest request){
        return ResponseEntity.status(200).body(excuseDecisionService.addHabitExcuse(memberId, weekId, request));
    }
}
