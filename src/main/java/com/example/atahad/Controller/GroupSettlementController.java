package com.example.atahad.Controller;

import com.example.atahad.Service.GroupSettlementService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-settlement")
@RequiredArgsConstructor
public class GroupSettlementController {
    private final GroupSettlementService groupSettlementService;

    @GetMapping("/get/{groupId}/{memberId}")
    public ResponseEntity<?> getSettlements(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupSettlementService.getSettlements(groupId, memberId));
    }

    @GetMapping("/latest/{groupId}/{memberId}")
    public ResponseEntity<?> getLatest(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupSettlementService.getLatest(groupId, memberId));
    }
}
