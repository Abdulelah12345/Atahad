package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.AutomationService;
import com.example.atahad.Service.CommitmentWeekService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/commitment-week")
@RequiredArgsConstructor
public class CommitmentWeekController {
    private final CommitmentWeekService commitmentWeekService;
    private final AutomationService automationService;

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getWeek(@PathVariable Integer id){
        return ResponseEntity.status(200).body(commitmentWeekService.getWeekById(id));
    }

    @GetMapping("/getHistory/{memberId}/{commitmentId}")
    public ResponseEntity<?> getHistory(@PathVariable Integer memberId, @PathVariable Integer commitmentId){
        return ResponseEntity.status(200).body(commitmentWeekService.getHistory(memberId, commitmentId));
    }

    @GetMapping("/getCurrent/{memberId}/{commitmentId}")
    public ResponseEntity<?> getCurrentWeek(@PathVariable Integer memberId, @PathVariable Integer commitmentId){
        return ResponseEntity.status(200).body(commitmentWeekService.getCurrentWeek(memberId, commitmentId));
    }

    // the home screen: what is left this week and what must be done today
    @GetMapping("/today/{memberId}")
    public ResponseEntity<?> getToday(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(commitmentWeekService.getToday(memberId));
    }

    // postpone inside this week (habits), it only moves the reminders
    @PutMapping("/changePlan/{memberId}/{weekId}")
    public ResponseEntity<?> changeThisWeekPlan(@PathVariable Integer memberId, @PathVariable Integer weekId, @RequestBody Set<String> plannedDays){
        commitmentWeekService.changeThisWeekPlan(memberId, weekId, plannedDays);
        return ResponseEntity.status(200).body(new ApiResponse("This week plan updated"));
    }

    // admin / demo: runs all the 00:00 automation now (weeks, group settlement, matches, refusals, wrapped)
    // ?date=2026-10-25 to try a sunday
    @PostMapping("/runDaily")
    public ResponseEntity<?> runDaily(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date){
        automationService.run(date == null ? LocalDate.now() : date);
        return ResponseEntity.status(200).body(new ApiResponse("Automation done"));
    }
}
