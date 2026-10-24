package com.example.atahad.Controller;

import com.example.atahad.Entity.User;
import com.example.atahad.Service.MonthlyWrappedService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/monthly-wrapped")
@RequiredArgsConstructor
public class MonthlyWrappedController {
    private final MonthlyWrappedService monthlyWrappedService;

    @GetMapping("/my")
    public ResponseEntity<?> getMyWrapped(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(monthlyWrappedService.getMyWrapped(user.getId()));
    }

    // month like 2026-10, makes it again if it exists
    @PostMapping("/generate/{month}")
    public ResponseEntity<?> generate(@AuthenticationPrincipal User user, @PathVariable String month){
        return ResponseEntity.status(200).body(monthlyWrappedService.generate(user.getId(), month));
    }
}
