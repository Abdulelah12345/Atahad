package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.PenaltyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/penalty")
@RequiredArgsConstructor
public class PenaltyController {
    private final PenaltyService penaltyService;

    @GetMapping("/my/{memberId}")
    public ResponseEntity<?> getMyPenalties(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(penaltyService.getMyPenalties(memberId));
    }

    // admin
    @GetMapping("/get/{adminId}")
    public ResponseEntity<?> getAll(@PathVariable Integer adminId){
        return ResponseEntity.status(200).body(penaltyService.getAll(adminId));
    }

    // admin
    @PutMapping("/cancel/{adminId}/{penaltyId}")
    public ResponseEntity<?> cancel(@PathVariable Integer adminId, @PathVariable Integer penaltyId){
        penaltyService.cancel(adminId, penaltyId);
        return ResponseEntity.status(200).body(new ApiResponse("Penalty cancelled"));
    }
}
