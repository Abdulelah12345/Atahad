package com.example.atahad.Controller;

import com.example.atahad.Entity.User;
import com.example.atahad.Service.PointLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/point-log")
@RequiredArgsConstructor
public class PointLogController {
    private final PointLogService pointLogService;

    @GetMapping("/my")
    public ResponseEntity<?> getMyPointLogs(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(pointLogService.getMyPointLogs(user.getId()));
    }

    @GetMapping("/group/{groupId}")
    public ResponseEntity<?> getGroupPointLogs(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(pointLogService.getGroupPointLogs(groupId, user.getId()));
    }
}
