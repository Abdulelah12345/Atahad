package com.example.atahad.Controller;

import com.example.atahad.Entity.User;
import com.example.atahad.Service.*;
import com.example.atahad.Dto.In.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

@RestController
@RequestMapping("/api/v1/proof-attempt")
@RequiredArgsConstructor
public class ProofAttemptController {
    private final ProofAttemptService attempts;
    private final ProofCaptureService captures;
    private final TimerSessionService timers;
    @GetMapping("/suggest/{weekId}")
    public ResponseEntity<?> suggest(@AuthenticationPrincipal User user,@PathVariable Integer weekId,@RequestParam(required=false) Integer goalTaskId) {
        return ResponseEntity.status(200).body(attempts.suggestion(user.getId(),weekId,goalTaskId));
    }
    @PostMapping("/start/{weekId}")
    public ResponseEntity<?> start(@AuthenticationPrincipal User user,@PathVariable Integer weekId,@Valid @RequestBody ProofAttemptStartRequest request) {
        return ResponseEntity.status(200).body(attempts.start(user.getId(),weekId,request));
    }
    @GetMapping("/{proofId}")
    public ResponseEntity<?> state(@AuthenticationPrincipal User user,@PathVariable Integer proofId) { return ResponseEntity.status(200).body(attempts.state(user.getId(),proofId)); }
    @PostMapping("/{proofId}/submit")
    public ResponseEntity<?> submit(@AuthenticationPrincipal User user,@PathVariable Integer proofId,@Valid @RequestBody ProofEvidenceRequest request) {
        return ResponseEntity.status(200).body(attempts.submit(user.getId(),proofId,request.getEvidenceData()));
    }
    @PostMapping("/{proofId}/after")
    public ResponseEntity<?> after(@AuthenticationPrincipal User user,@PathVariable Integer proofId,@Valid @RequestBody BeforeAfterRequest request) {
        return ResponseEntity.status(200).body(attempts.after(user.getId(),proofId,request.getAfterCaptureId()));
    }
    @PostMapping("/{proofId}/skip-photos")
    public ResponseEntity<?> skipPhotos(@AuthenticationPrincipal User user,@PathVariable Integer proofId) {
        return ResponseEntity.status(200).body(attempts.skipPhotos(user.getId(),proofId));
    }
    @PostMapping("/capture")
    public ResponseEntity<?> capture(@AuthenticationPrincipal User user,@RequestParam String kind,@RequestParam(required=false) Integer proofId) {
        return ResponseEntity.status(200).body(captures.start(user.getId(),kind,proofId));
    }
    @PostMapping("/capture/{id}")
    public ResponseEntity<?> upload(@AuthenticationPrincipal User user,@PathVariable Integer id,@Valid @RequestBody CaptureUploadRequest request) {
        return ResponseEntity.status(200).body(captures.upload(user.getId(),id,request));
    }
    @PostMapping("/timer/{id}/{action}")
    public ResponseEntity<?> timer(@AuthenticationPrincipal User user,@PathVariable Integer id,@PathVariable String action,@Valid @RequestBody(required=false) TimerActionRequest request) {
        return ResponseEntity.status(200).body(timers.action(user.getId(),id,action,request==null?null:request.getMinutes(),request==null?null:request.getFeedback()));
    }
}
