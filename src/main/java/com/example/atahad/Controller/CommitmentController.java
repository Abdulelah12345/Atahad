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
        commitmentService.withdraw(memberId, id);
        return ResponseEntity.status(200).body(new ApiResponse("Withdrawn from the commitment"));
    }
}
