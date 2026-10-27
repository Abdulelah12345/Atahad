package com.example.atahad.Controller;

import com.example.atahad.Entity.Objection;
import com.example.atahad.Service.ObjectionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.ObjectionRequest;
import com.example.atahad.Entity.User;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;

import java.util.List;

@RestController
@RequestMapping("/api/v1/objection")
@RequiredArgsConstructor
public class ObjectionController {

    private final ObjectionService objectionService;

    // admin: all objections
    @GetMapping("/get-all")
    public ResponseEntity<?> getAllObjections() {
        List<Objection> objectionList = objectionService.getAllObjections();
        return ResponseEntity.status(200).body(objectionList);
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getObjectionById(
            @AuthenticationPrincipal User user,
            @PathVariable Integer id) {

        Integer userId = user.getId();

        Objection objection = objectionService.getObjectionById(userId, id);
        return ResponseEntity.status(200).body(objection);
    }

    @PostMapping("/add/proof/{proofId}")
    public ResponseEntity<?> addProofObjection(
            @AuthenticationPrincipal User user,
            @PathVariable Integer proofId,
            @RequestBody @Valid ObjectionRequest request) {

        Integer userId = user.getId();
        objectionService.addProofObjection(userId, proofId, request);
        return ResponseEntity.status(200)
                .body(new ApiResponse("Proof objection added successfully"));
    }

    @PostMapping("/add/excuse/{excuseId}")
    public ResponseEntity<?> addExcuseObjection(
            @AuthenticationPrincipal User user,
            @PathVariable Integer excuseId,
            @RequestBody @Valid ObjectionRequest request) {

        Integer userId = user.getId();
        objectionService.addExcuseObjection(userId, excuseId, request);
        return ResponseEntity.status(200)
                .body(new ApiResponse("Excuse objection added successfully"));
    }

    @PutMapping("/update/{objectionId}")
    public ResponseEntity<?> updateObjection(
            @AuthenticationPrincipal User user,
            @PathVariable Integer objectionId,
            @RequestBody @Valid ObjectionRequest request) {

        Integer userId = user.getId();

        objectionService.updateObjection(userId, objectionId, request);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Objection updated successfully"));
    }

    @DeleteMapping("/delete/{objectionId}")
    public ResponseEntity<?> deleteObjection(
            @AuthenticationPrincipal User user,
            @PathVariable Integer objectionId) {

        Integer userId = user.getId();

        objectionService.deleteObjection(userId, objectionId);

        return ResponseEntity.status(200)
                .body(new ApiResponse("Objection deleted successfully"));
    }
}