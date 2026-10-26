package com.example.atahad.Controller;

import com.example.atahad.Entity.User;
import com.example.atahad.Service.ActivityMapService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/member")
public class ActivityMapController {

    private final ActivityMapService activityMapService;

    @GetMapping("/activity-map")
    public ResponseEntity<?> getActivityMap(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(activityMapService.getActivityMap(user.getId()));
    }
}