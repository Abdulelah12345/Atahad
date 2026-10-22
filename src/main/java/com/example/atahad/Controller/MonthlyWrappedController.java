package com.example.atahad.Controller;

import com.example.atahad.Service.MonthlyWrappedService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/monthly-wrapped")
@RequiredArgsConstructor
public class MonthlyWrappedController {
    private final MonthlyWrappedService monthlyWrappedService;

    @GetMapping("/my/{memberId}")
    public ResponseEntity<?> getMyWrapped(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(monthlyWrappedService.getMyWrapped(memberId));
    }

    // month like 2026-10, makes it again if it exists
    @PostMapping("/generate/{memberId}/{month}")
    public ResponseEntity<?> generate(@PathVariable Integer memberId, @PathVariable String month){
        return ResponseEntity.status(200).body(monthlyWrappedService.generate(memberId, month));
    }
}
