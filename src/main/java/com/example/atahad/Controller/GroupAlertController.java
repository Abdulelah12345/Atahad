package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.DeviceTokenRequest;
import com.example.atahad.Service.GroupAlertService;
import jakarta.validation.Valid;
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

    // the phone sends its Firebase token after login, so the alerts reach it as push notifications
    @PutMapping("/device-token")
    public ResponseEntity<?> saveDeviceToken(@AuthenticationPrincipal User user, @RequestBody @Valid DeviceTokenRequest dto){
        groupAlertService.saveDeviceToken(user.getId(), dto.getToken());
        return ResponseEntity.status(200).body(new ApiResponse("Device token saved"));
    }

    // is Firebase on (the key file was found and read)
    @GetMapping("/push-status")
    public ResponseEntity<?> pushStatus(){
        return ResponseEntity.status(200).body(new ApiResponse(groupAlertService.pushStatus()));
    }
}
