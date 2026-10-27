package com.example.atahad.Controller;

import com.example.atahad.Service.ProofMethodService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// the proof methods a member can pick now (the admin turns them on and off)
@RestController
@RequestMapping("/api/v1/proof-method")
@RequiredArgsConstructor
public class ProofMethodController {

    private final ProofMethodService proofMethodService;

    @GetMapping("/active")
    public ResponseEntity<?> getActive() {
        return ResponseEntity.status(200).body(proofMethodService.getActive());
    }
}
