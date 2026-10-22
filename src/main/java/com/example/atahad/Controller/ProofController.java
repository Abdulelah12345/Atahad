package com.example.atahad.Controller;

import com.example.atahad.Entity.Proof;
import com.example.atahad.Service.ProofService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/proof")
@RequiredArgsConstructor
public class ProofController {
    private final ProofService proofService;



    @GetMapping("/get-all")
    public ResponseEntity<?> getAllProofs() {
        List<Proof> proofList = proofService.getAllProofs();
        return ResponseEntity.status(200).body(proofList);
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getProofById(@PathVariable Integer id) {
        Proof proof = proofService.getProofById(id);
        return ResponseEntity.status(200).body(proof);
    }


}