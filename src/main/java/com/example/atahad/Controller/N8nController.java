package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.AutomationService;
import com.example.atahad.Service.N8nService;
import com.example.atahad.Service.WhatsAppService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

// called by the n8n workflow only (header X-N8N-KEY)
@RestController
@RequestMapping("/api/v1/n8n")
@RequiredArgsConstructor
public class N8nController {
    private final N8nService n8nService;
    private final AutomationService automationService;
    private final WhatsAppService whatsAppService;

    // every day 00:00: weeks, settlements, matches, refusals, wrapped
    @PostMapping("/run-daily")
    public ResponseEntity<?> runDaily(@RequestHeader("X-N8N-KEY") String key,
                                      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date){
        n8nService.checkKey(key);
        automationService.run(date == null ? LocalDate.now() : date);
        return ResponseEntity.status(200).body(new ApiResponse("Automation done"));
    }

    // every day in the evening: a reminder for everyone who must do something today
    @PostMapping("/reminders")
    public ResponseEntity<?> createReminders(@RequestHeader("X-N8N-KEY") String key){
        n8nService.checkKey(key);
        return ResponseEntity.status(200).body(new ApiResponse(n8nService.createReminders() + " reminders created"));
    }

    // every few minutes: the messages to send with UltraMsg
    @GetMapping("/whatsapp/pending")
    public ResponseEntity<?> getPending(@RequestHeader("X-N8N-KEY") String key){
        n8nService.checkKey(key);
        return ResponseEntity.status(200).body(n8nService.getPending());
    }

    @PutMapping("/whatsapp/sent/{id}")
    public ResponseEntity<?> markSent(@RequestHeader("X-N8N-KEY") String key, @PathVariable Integer id){
        n8nService.checkKey(key);
        whatsAppService.markSent(id);
        return ResponseEntity.status(200).body(new ApiResponse("Marked as sent"));
    }

    @PutMapping("/whatsapp/failed/{id}")
    public ResponseEntity<?> markFailed(@RequestHeader("X-N8N-KEY") String key, @PathVariable Integer id,
                                        @RequestParam(required = false) String error){
        n8nService.checkKey(key);
        whatsAppService.markFailed(id, error);
        return ResponseEntity.status(200).body(new ApiResponse("Marked as failed"));
    }
    @GetMapping("/weekly-reports")
    public ResponseEntity<?> getWeeklyReports(@RequestHeader("X-N8N-KEY") String key){
        return ResponseEntity.status(200).body(n8nService.generateWeeklyReports(key));
    }
}
