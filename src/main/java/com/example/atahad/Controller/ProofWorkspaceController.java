package com.example.atahad.Controller;

import com.example.atahad.Entity.User;
import com.example.atahad.Service.ProofWorkspaceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/proof-workspace")
@RequiredArgsConstructor
public class ProofWorkspaceController {
    private final ProofWorkspaceService proofWorkspaceService;
    private final com.example.atahad.Service.ProofCaptureService proofCaptureService;

    @GetMapping("/attachment/{captureId}")
    public ResponseEntity<?> getAttachment(@AuthenticationPrincipal User user, @PathVariable Integer captureId) {
        String image = proofCaptureService.read(user.getId(), captureId).getImageData();
        return ResponseEntity.status(200).body(java.util.Map.of("imageData", image == null ? "" : image));
    }

    @GetMapping("/my")
    public ResponseEntity<?> getMyWorkspace(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(proofWorkspaceService.getMyWorkspace(user.getId()));
    }
}
