package com.example.atahad.Controller;

import com.example.atahad.Service.ProofChallengeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/challenge")
@RequiredArgsConstructor
public class ProofChallengeController {
    private final ProofChallengeService proofChallengeService;

    // when the camera opens for a PHOTO proof: ?goalTaskId= for goals
    @PostMapping("/create/{memberId}/{weekId}")
    public ResponseEntity<?> create(@PathVariable Integer memberId, @PathVariable Integer weekId,
                                    @RequestParam(required = false) Integer goalTaskId){
        return ResponseEntity.status(200).body(proofChallengeService.create(memberId, weekId, goalTaskId));
    }
}
