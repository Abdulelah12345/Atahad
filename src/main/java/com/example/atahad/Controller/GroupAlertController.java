package com.example.atahad.Controller;

import com.example.atahad.Service.GroupAlertService;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-alert")
@RequiredArgsConstructor
public class GroupAlertController {
    private final GroupAlertService groupAlertService;

    // the siren to a friend who did not finish yet
    @PostMapping("/send/{groupId}/{receiverId}")
    public ResponseEntity<?> send(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @PathVariable Integer receiverId){
        return ResponseEntity.status(200).body(groupAlertService.send(groupId, user.getId(), receiverId));
    }

    @GetMapping("/today/{groupId}")
    public ResponseEntity<?> getMyAlertsToday(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupAlertService.getMyAlertsToday(user.getId(), groupId));
    }
}
