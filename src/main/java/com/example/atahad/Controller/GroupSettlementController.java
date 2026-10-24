package com.example.atahad.Controller;

import com.example.atahad.Service.GroupSettlementService;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-settlement")
@RequiredArgsConstructor
public class GroupSettlementController {
    private final GroupSettlementService groupSettlementService;

    @GetMapping("/get/{groupId}")
    public ResponseEntity<?> getSettlements(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupSettlementService.getSettlements(groupId, user.getId()));
    }

    @GetMapping("/latest/{groupId}")
    public ResponseEntity<?> getLatest(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupSettlementService.getLatest(groupId, user.getId()));
    }
}
