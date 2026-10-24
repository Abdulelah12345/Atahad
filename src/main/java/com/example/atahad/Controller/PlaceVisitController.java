package com.example.atahad.Controller;

import com.example.atahad.Dto.In.PlaceVisitRequest;
import com.example.atahad.Service.PlaceVisitService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

// called by the phone by itself (geofencing) when it enters and leaves the place of a LOCATION commitment
@RestController
@RequestMapping("/api/v1/visit")
@RequiredArgsConstructor
public class PlaceVisitController {
    private final PlaceVisitService placeVisitService;

    // ?goalTaskId= for a goal (optional, the LOCATION task of this week is found by itself)
    @PostMapping("/enter/{memberId}/{commitmentId}")
    public ResponseEntity<?> enter(@PathVariable Integer memberId, @PathVariable Integer commitmentId,
                                   @RequestParam(required = false) Integer goalTaskId,
                                   @RequestBody @Valid PlaceVisitRequest request){
        return ResponseEntity.status(200).body(placeVisitService.enter(memberId, commitmentId, goalTaskId, request));
    }

    // closes the visit and makes the proof
    @PostMapping("/exit/{memberId}/{commitmentId}")
    public ResponseEntity<?> exit(@PathVariable Integer memberId, @PathVariable Integer commitmentId){
        return ResponseEntity.status(200).body(placeVisitService.exit(memberId, commitmentId));
    }

    @GetMapping("/my/{memberId}")
    public ResponseEntity<?> getMyVisits(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(placeVisitService.getMyVisits(memberId));
    }
}
