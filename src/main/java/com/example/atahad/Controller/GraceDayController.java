package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.GraceDayService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/grace-day")
@RequiredArgsConstructor
public class GraceDayController {

    private final GraceDayService graceDayService;

    // admin
    @GetMapping("/get")
    public ResponseEntity<?> getAllGraceDays() {
        return ResponseEntity.status(200).body(graceDayService.getAllGraceDays());
    }

    // admin
    @GetMapping("/get/{id}")
    public ResponseEntity<?> getGraceDayById(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(graceDayService.getGraceDayById(id));
    }

    // admin: the grace days of any member
    @GetMapping("/member/{memberId}")
    public ResponseEntity<?> getMemberGraceDays(@PathVariable Integer memberId) {
        return ResponseEntity.status(200).body(graceDayService.getMemberGraceDays(memberId));
    }

    @GetMapping("/my")
    public ResponseEntity<?> getMyGraceDays(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(graceDayService.getMemberGraceDays(user.getId()));
    }

    // admin
    @PostMapping("/grant/{memberId}")
    public ResponseEntity<?> grantGraceDay(@AuthenticationPrincipal User user, @PathVariable Integer memberId, @RequestParam String reason) {
        graceDayService.grantGraceDay(user.getId(), memberId, reason);
        return ResponseEntity.status(200).body(new ApiResponse("Grace day granted successfully"));
    }

    // 150 points -> one grace day (when the automatic one did not happen because the member was full)
    @PostMapping("/earn")
    public ResponseEntity<?> earnGraceDay(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(graceDayService.earnGraceDay(user.getId()));
    }

    @PutMapping("/use/{graceDayId}/{weekId}")
    public ResponseEntity<?> useGraceDay(@AuthenticationPrincipal User user, @PathVariable Integer graceDayId, @PathVariable Integer weekId) {
        graceDayService.useGraceDay(graceDayId, user.getId(), weekId);
        return ResponseEntity.status(200).body(new ApiResponse("Grace day used successfully"));
    }
}
