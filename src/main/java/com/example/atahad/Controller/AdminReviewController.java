package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.AdminReviewService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin-review")
@RequiredArgsConstructor
public class AdminReviewController {
    private final AdminReviewService adminReviewService;

    @GetMapping("/penalties/{adminId}")
    public ResponseEntity<?> getPenaltyWorkspace(@PathVariable Integer adminId) {
        return ResponseEntity.status(200).body(adminReviewService.getPenaltyWorkspace(adminId));
    }

    @PostMapping("/start/{adminId}/{objectionId}")
    public ResponseEntity<?> startReview(@PathVariable Integer adminId, @PathVariable Integer objectionId) {
        adminReviewService.startObjectionReview(adminId, objectionId);
        return ResponseEntity.status(200).body(new ApiResponse("Review started"));
    }

    // everything the AI was not sure about
    @GetMapping("/queue/{adminId}")
    public ResponseEntity<?> getQueue(@PathVariable Integer adminId){
        return ResponseEntity.status(200).body(adminReviewService.getQueue(adminId));
    }

    // kind: PROOF, EXCUSE, OBJECTION or DONATION, ?note=... optional
    @PutMapping("/decide/{adminId}/{kind}/{id}/{accept}")
    public ResponseEntity<?> decide(@PathVariable Integer adminId, @PathVariable String kind, @PathVariable Integer id,
                                    @PathVariable Boolean accept, @RequestParam(required = false) String note){
        adminReviewService.decide(adminId, kind, id, accept, note);
        return ResponseEntity.status(200).body(new ApiResponse(accept ? "Accepted" : "Rejected"));
    }
}
