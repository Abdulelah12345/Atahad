package com.example.atahad.Controller;

import com.example.atahad.Entity.Proof;
import com.example.atahad.Service.ProofService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.ProofRequest;
import com.example.atahad.Dto.In.ProofUpdateRequest;
import com.example.atahad.Entity.User;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;

import java.util.List;

@RestController
@RequestMapping("/api/v1/proof")
@RequiredArgsConstructor
public class ProofController {
    private final ProofService proofService;

    @GetMapping("/get-all")
    public ResponseEntity<?> getAllProofs() {
        List<Proof> proofList = proofService.getAllProofs();
        return ResponseEntity.status(200).body(proofList);
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getProofById(@AuthenticationPrincipal User user,
                                         @PathVariable Integer id) {
        Proof proof = proofService.getProofById(user.getId(), id);
        return ResponseEntity.status(200).body(proof);
    }

    @PostMapping("/add/goal-task/{goalTaskId}/week/{commitmentWeekId}")
    public ResponseEntity<?> addGoalTaskProof(
            @AuthenticationPrincipal User user,
            @PathVariable Integer goalTaskId,
            @PathVariable Integer commitmentWeekId,
            @RequestBody @Valid ProofRequest request) {

        Integer userId = user.getId();

        proofService.addGoalTaskProof(
                userId, goalTaskId, commitmentWeekId, request);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Proof added successfully"));
    }

    @PutMapping("/update/goal-task/{proofId}")
    public ResponseEntity<?> updateGoalTaskProof(
            @AuthenticationPrincipal User user,
            @PathVariable Integer proofId,
            @RequestBody @Valid ProofUpdateRequest request) {

        Integer userId = user.getId();

        proofService.updateGoalTaskProof(userId, proofId, request);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Proof updated successfully"));
    }

    @DeleteMapping("/delete/goal-task/{proofId}")
    public ResponseEntity<?> deleteGoalTaskProof(
            @AuthenticationPrincipal User user,
            @PathVariable Integer proofId) {

        Integer userId = user.getId();

        proofService.deleteGoalTaskProof(userId, proofId);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Proof deleted successfully"));
    }

    @GetMapping("/get-my-proofs")
    public ResponseEntity<?> getAllProofsByUserId(
            @AuthenticationPrincipal User user) {

        Integer userId = user.getId();

        List<Proof> proofList = proofService.getAllProofsByUserId(userId);

        return ResponseEntity.status(200).body(proofList);
    }
}