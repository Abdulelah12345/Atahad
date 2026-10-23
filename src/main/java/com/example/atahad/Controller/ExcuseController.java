package com.example.atahad.Controller;

import com.example.atahad.Entity.Excuse;
import com.example.atahad.Service.ExcuseService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.ExcuseRequest;
import com.example.atahad.Entity.User;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import java.util.List;

@RestController
@RequestMapping("/api/v1/excuse")
@RequiredArgsConstructor
public class ExcuseController {

    private final ExcuseService excuseService;

    @GetMapping("/get")
    public ResponseEntity<List<Excuse>> getAllExcuses() {
        return ResponseEntity.ok(excuseService.getAllExcuses());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getExcuseById(
            @AuthenticationPrincipal User user,
            @PathVariable Integer id) {

        // نأخذ هوية المستخدم من الجلسة، والملكية يفحصها السيرفس.
        Integer userId = user.getId();

        Excuse excuse = excuseService.getExcuseById(userId, id);

        return ResponseEntity.status(200).body(excuse);
    }

    @PostMapping("/add/goal-task/{goalTaskId}/week/{commitmentWeekId}")
    public ResponseEntity<?> addGoalTaskExcuse(
            @AuthenticationPrincipal User user,
            @PathVariable Integer goalTaskId,
            @PathVariable Integer commitmentWeekId,
            @RequestBody @Valid ExcuseRequest request) {

        // معرف المستخدم من جلسة الدخول، والملكية يفحصها السيرفس.
        Integer userId = user.getId();

        excuseService.addGoalTaskExcuse(
                userId, goalTaskId, commitmentWeekId, request);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Excuse added successfully"));
    }

}