package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.GoogleCalendarService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/google-calendar")
@RequiredArgsConstructor
public class GoogleCalendarController {

    private final GoogleCalendarService googleCalendarService;

    @GetMapping("/connect")
    public ResponseEntity<?> connect(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(googleCalendarService.getAuthorizationUrl(user.getId()));
    }

    @GetMapping(value = "/callback", produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> callback(@RequestParam String code,@RequestParam String state){

        googleCalendarService.handleCallback(code,state);

        String html = """
            <!DOCTYPE html>
            <html lang="ar" dir="rtl">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>تم ربط التقويم - تعهّد</title>
                <style>
                    * { box-sizing: border-box; }

                    body {
                        margin: 0;
                        min-height: 100vh;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        background: #f5f7fc;
                        font-family: Arial, sans-serif;
                        padding: 24px;
                    }

                    .card {
                        background: white;
                        padding: 36px 24px;
                        border-radius: 20px;
                        text-align: center;
                        max-width: 400px;
                        width: 100%;
                        border: 1px solid #e3e8f0;
                    }

                    .icon {
                        background: #e8f0ff;
                        color: #2563eb;
                        width: 76px;
                        height: 76px;
                        border-radius: 50%;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        font-size: 40px;
                        margin: 0 auto 24px;
                    }

                    h2 {
                        color: #10245e;
                        font-size: 23px;
                        margin-bottom: 12px;
                    }

                    p {
                        color: #64748b;
                        line-height: 1.8;
                        font-size: 15px;
                    }

                    .note {
                        margin-top: 24px;
                        padding: 14px;
                        border-radius: 12px;
                        background: #f1f5f9;
                        color: #475569;
                        font-size: 14px;
                    }
                </style>
            </head>
            <body>
                <div class="card">
                    <div class="icon">✓</div>
                    <h2>تم ربط Google Calendar بنجاح</h2>
                    <p>
                        أصبح تقويم Google مرتبطًا بحسابك في تعهّد.
                        يمكنك الآن العودة إلى التطبيق والاستفادة من ميزات التقويم.
                    </p>
                    <div class="note">
                        يمكنك إغلاق هذه الصفحة والعودة إلى تطبيق تعهّد.
                    </div>
                </div>
            </body>
            </html>
            """;

        return ResponseEntity.status(200).body(html);
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
    public ResponseEntity<?> generate(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(googleCalendarService.generateSchedule(user.getId()));
    }

    @PostMapping("/approve-schedule")
    public ResponseEntity<?> approveSchedule(@AuthenticationPrincipal User user,@RequestBody List<Map<String,Object>> schedules){
        googleCalendarService.approveSchedule(user.getId(),schedules);
        return ResponseEntity.status(200).body(new ApiResponse("Schedule added to Google Calendar successfully"));
    }

    @PostMapping("/reject-schedule")
    public ResponseEntity<?> rejectSchedule(@AuthenticationPrincipal User user){
        googleCalendarService.rejectSchedule(user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Schedule rejected successfully"));
    }
}