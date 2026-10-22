package com.example.atahad.Controller;

import com.example.atahad.Service.GroupAlertService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-alert")
@RequiredArgsConstructor
public class GroupAlertController {
    private final GroupAlertService groupAlertService;

    // the siren to a friend who did not finish yet
    @PostMapping("/send/{groupId}/{senderId}/{receiverId}")
    public ResponseEntity<?> send(@PathVariable Integer groupId, @PathVariable Integer senderId, @PathVariable Integer receiverId){
        return ResponseEntity.status(200).body(groupAlertService.send(groupId, senderId, receiverId));
    }

    @GetMapping("/today/{groupId}/{memberId}")
    public ResponseEntity<?> getMyAlertsToday(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupAlertService.getMyAlertsToday(memberId, groupId));
    }
}
