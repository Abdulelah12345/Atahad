package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.AutomationService;
import com.example.atahad.Service.CommitmentWeekService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
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
    public ResponseEntity<?> getWeek(@AuthenticationPrincipal User user, @PathVariable Integer id){
        return ResponseEntity.status(200).body(commitmentWeekService.getMyWeek(user.getId(), id));
    }

    @GetMapping("/getHistory/{commitmentId}")
    public ResponseEntity<?> getHistory(@AuthenticationPrincipal User user, @PathVariable Integer commitmentId){
        return ResponseEntity.status(200).body(commitmentWeekService.getHistory(user.getId(), commitmentId));
    }

    @GetMapping("/getCurrent/{commitmentId}")
    public ResponseEntity<?> getCurrentWeek(@AuthenticationPrincipal User user, @PathVariable Integer commitmentId){
        return ResponseEntity.status(200).body(commitmentWeekService.getCurrentWeek(user.getId(), commitmentId));
    }

    // the home screen: what is left this week and what must be done today
    @GetMapping("/today")
    public ResponseEntity<?> getToday(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(commitmentWeekService.getToday(user.getId()));
    }

    // postpone inside this week (a habit, or one task of a goal with ?goalTaskId=), it only moves the reminders
    @PutMapping("/changePlan/{weekId}")
    public ResponseEntity<?> changeThisWeekPlan(@AuthenticationPrincipal User user, @PathVariable Integer weekId,
                                                @RequestParam(required = false) Integer goalTaskId, @RequestBody Set<String> plannedDays){
        commitmentWeekService.changeThisWeekPlan(user.getId(), weekId, goalTaskId, plannedDays);
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
