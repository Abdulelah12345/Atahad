package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.GraceDay;
import com.example.atahad.Service.GraceDayService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/grace-day")
@RequiredArgsConstructor
public class GraceDayController {

    private final GraceDayService graceDayService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllGraceDays() {
        return ResponseEntity.status(200).body(graceDayService.getAllGraceDays());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getGraceDayById(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(graceDayService.getGraceDayById(id));
    }

    @GetMapping("/member/{memberId}")
    public ResponseEntity<?> getMemberGraceDays(@PathVariable Integer memberId) {
        return ResponseEntity.status(200).body(graceDayService.getMemberGraceDays(memberId));
    }

    @PostMapping("/grant/{adminId}/{memberId}")
    public ResponseEntity<?> grantGraceDay(@PathVariable Integer adminId, @PathVariable Integer memberId, @RequestParam String reason) {
        graceDayService.grantGraceDay(adminId, memberId, reason);
        return ResponseEntity.status(200).body(new ApiResponse("Grace day granted successfully"));
    }

    // 150 points -> one grace day (when the automatic one did not happen because the member was full)
    @PostMapping("/earn/{memberId}")
    public ResponseEntity<?> earnGraceDay(@PathVariable Integer memberId) {
        return ResponseEntity.status(200).body(graceDayService.earnGraceDay(memberId));
    }

    @PutMapping("/use/{graceDayId}/{memberId}/{weekId}")
    public ResponseEntity<?> useGraceDay(@PathVariable Integer graceDayId, @PathVariable Integer memberId, @PathVariable Integer weekId) {
        graceDayService.useGraceDay(graceDayId, memberId, weekId);
        return ResponseEntity.status(200).body(new ApiResponse("Grace day used successfully"));
    }
}