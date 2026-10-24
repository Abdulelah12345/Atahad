package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.GoogleCalendarService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import com.example.atahad.Service.AiService;
import com.example.atahad.Dto.In.AiScheduleRequest;
import com.example.atahad.DTO.Out.AiScheduleResponse;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/google-calendar")
@RequiredArgsConstructor
public class GoogleCalendarController {

    private final GoogleCalendarService googleCalendarService;
    private final AiService aiService;
    @GetMapping("/connect")
    public ResponseEntity<?> connect(HttpSession session){
        return ResponseEntity.status(200).body(googleCalendarService.getAuthorizationUrl(session));
    }
    @GetMapping("/callback")
    public ResponseEntity<?> callback(@RequestParam String code, @RequestParam String state, HttpSession session){

        googleCalendarService.handleCallback(code, state, session);

        return ResponseEntity.status(200).body("Google Calendar connected successfully");
    }
    @PostMapping("/suggest-schedule")
    public ResponseEntity<?> suggestSchedule(@RequestBody @Valid AiScheduleRequest request,HttpSession session){

        AiScheduleResponse response=aiService.suggestSchedule(request);

        session.setAttribute("pendingSchedule",response);

        return ResponseEntity.status(200).body(response);
    }

    @PostMapping("/approve-schedule")
    public ResponseEntity<?> approveSchedule(HttpSession session){
        googleCalendarService.approveSchedule(session);
        return ResponseEntity.status(200).body(new ApiResponse("Schedule added to Google Calendar successfully"));
    }

    @PostMapping("/reject-schedule")
    public ResponseEntity<?> rejectSchedule(HttpSession session){
        googleCalendarService.rejectSchedule(session);
        return ResponseEntity.status(200).body(new ApiResponse("Schedule rejected successfully"));
    }
}