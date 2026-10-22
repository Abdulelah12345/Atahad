package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.CommitmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/commitment")
@RequiredArgsConstructor
public class CommitmentController {
    private final CommitmentService commitmentService;

    @GetMapping("/getMyCommitments/{memberId}")
    public ResponseEntity<?> getMyCommitments(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(commitmentService.getMyCommitments(memberId));
    }

    @GetMapping("/get/{memberId}/{id}")
    public ResponseEntity<?> getCommitment(@PathVariable Integer memberId, @PathVariable Integer id){
        return ResponseEntity.status(200).body(commitmentService.getCommitment(memberId, id));
    }

    @PutMapping("/withdraw/{memberId}/{id}")
    public ResponseEntity<?> withdraw(@PathVariable Integer memberId, @PathVariable Integer id){
        Integer penalties = commitmentService.withdraw(memberId, id);
        if(penalties == 0){
            return ResponseEntity.status(200).body(new ApiResponse("Withdrawn from the commitment"));
        }
        return ResponseEntity.status(200).body(new ApiResponse("Withdrawn from the commitment, " + penalties + " times left this week became penalties and the app is locked until you donate"));
    }

    // the lock screen
    @GetMapping("/lockStatus/{memberId}")
    public ResponseEntity<?> getLockStatus(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(commitmentService.getLockStatus(memberId));
    }

    // level, points, grace days and total donated
    @GetMapping("/stats/{memberId}")
    public ResponseEntity<?> getStats(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(commitmentService.getStats(memberId));
    }
}
