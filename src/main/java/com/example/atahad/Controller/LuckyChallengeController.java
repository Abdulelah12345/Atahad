
package com.example.atahad.Controller;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.LuckyChallengeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/lucky-challenge")
public class LuckyChallengeController {

    private final LuckyChallengeService luckyChallengeService;

    @PostMapping("/random/{difficulty}")
    public ResponseEntity<?> randomChallenge(@AuthenticationPrincipal User user,@PathVariable String difficulty){
        return ResponseEntity.status(200).body(luckyChallengeService.randomChallenge(user.getId(),difficulty));
    }

    @PostMapping("/accept/{challengeId}")
    public ResponseEntity<?> acceptChallenge(@AuthenticationPrincipal User user,@PathVariable Integer challengeId){
        luckyChallengeService.acceptChallenge(user.getId(),challengeId);
        return ResponseEntity.status(200).body(Map.of("message","Challenge accepted successfully"));
    }

    @PostMapping("/proof/{challengeId}")
    public ResponseEntity<?> submitProof(@AuthenticationPrincipal User user,@PathVariable Integer challengeId,@RequestBody Map<String,String> request){
        String proofImage = request.get("proofImage");

        if(proofImage == null || proofImage.isBlank()){
            throw new ApiException("Proof image is required");
        }

        String result = luckyChallengeService.submitProof(user.getId(),challengeId,proofImage);
        return ResponseEntity.status(200).body(Map.of("message",result));
    }

    @GetMapping("/my")
    public ResponseEntity<?> getMyChallenge(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(luckyChallengeService.getMyChallenge(user.getId()));
    }
}
