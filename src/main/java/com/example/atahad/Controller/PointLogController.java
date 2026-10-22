package com.example.atahad.Controller;

import com.example.atahad.Service.PointLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/point-log")
@RequiredArgsConstructor
public class PointLogController {
    private final PointLogService pointLogService;

    @GetMapping("/my/{memberId}")
    public ResponseEntity<?> getMyPointLogs(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(pointLogService.getMyPointLogs(memberId));
    }

    @GetMapping("/group/{groupId}/{memberId}")
    public ResponseEntity<?> getGroupPointLogs(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(pointLogService.getGroupPointLogs(groupId, memberId));
    }
}
