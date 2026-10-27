package com.example.atahad.Controller;

import com.example.atahad.Dto.In.CaptureUploadRequest;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.ProofCaptureService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class ProofAttachmentController {
    private final ProofCaptureService proofCaptureService;

    // excuse and donation attachments work while the app is locked
    @PostMapping({"/api/v1/excuse/attachment", "/api/v1/donation-proof/attachment"})
    public ResponseEntity<?> create(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(proofCaptureService.start(user.getId(), "PHOTO", null));
    }

    @PostMapping({"/api/v1/excuse/attachment/{captureId}", "/api/v1/donation-proof/attachment/{captureId}"})
    public ResponseEntity<?> upload(@AuthenticationPrincipal User user, @PathVariable Integer captureId,
                                    @RequestBody @Valid CaptureUploadRequest request) {
        proofCaptureService.upload(user.getId(), captureId, request);
        return ResponseEntity.status(200).body(java.util.Map.of("reference", "capture:" + captureId));
    }
}
