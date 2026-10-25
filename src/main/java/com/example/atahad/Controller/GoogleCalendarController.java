
package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.GoogleCalendarService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import com.example.atahad.AI.AiService;
import com.example.atahad.Dto.In.AiScheduleRequest;
import com.example.atahad.Dto.Out.AiScheduleResponse;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/google-calendar")
@RequiredArgsConstructor
public class GoogleCalendarController {

    private final GoogleCalendarService googleCalendarService;

    @GetMapping("/connect")
    public ResponseEntity<?> connect(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(googleCalendarService.getAuthorizationUrl(user.getId()));
    }

    @GetMapping("/callback")
    public ResponseEntity<?> callback(@RequestParam String code,@RequestParam String state){
        googleCalendarService.handleCallback(code,state);
        return ResponseEntity.status(200).body(new ApiResponse("Google Calendar connected successfully"));
    }

    @GetMapping("/status")
    public ResponseEntity<?> status(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(Map.of("connected",googleCalendarService.isConnected(user.getId())));
    }

    @DeleteMapping("/disconnect")
    public ResponseEntity<?> disconnect(@AuthenticationPrincipal User user){
        googleCalendarService.disconnect(user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Google Calendar disconnected successfully"));
    }

    @PostMapping("/generate")
    public ResponseEntity<?> generate(@AuthenticationPrincipal User user,HttpSession session){
        return ResponseEntity.status(200).body(googleCalendarService.generateSchedule(user.getId(),session));
    }

    @PostMapping("/approve-schedule")
    public ResponseEntity<?> approveSchedule(@AuthenticationPrincipal User user,HttpSession session){
        googleCalendarService.approveSchedule(user.getId(),session);
        return ResponseEntity.status(200).body(new ApiResponse("Schedule added to Google Calendar successfully"));
    }

    @PostMapping("/reject-schedule")
    public ResponseEntity<?> rejectSchedule(@AuthenticationPrincipal User user,HttpSession session){
        googleCalendarService.rejectSchedule(user.getId(),session);
        return ResponseEntity.status(200).body(new ApiResponse("Schedule rejected successfully"));
    }
}
