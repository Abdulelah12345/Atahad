package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.GroupCreateRequest;
import com.example.atahad.Dto.In.GroupUpdateRequest;
import com.example.atahad.Service.GroupService;
import jakarta.validation.Valid;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group")
@RequiredArgsConstructor
public class GroupController {

    private final GroupService groupService;

    // admin
    @GetMapping("/get")
    public ResponseEntity<?> getAllGroups() {
        return ResponseEntity.status(200).body(groupService.getAllGroups());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getGroupById(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(groupService.getGroupById(id));
    }

    @PostMapping("/add")
    public ResponseEntity<?> addGroup(@AuthenticationPrincipal User user, @RequestBody @Valid GroupCreateRequest dto) {
        return ResponseEntity.status(200).body(groupService.addGroup(user.getId(), dto));
    }

    @PutMapping("/update/{groupId}")
    public ResponseEntity<?> updateGroup(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @RequestBody @Valid GroupUpdateRequest dto) {
        groupService.updateGroup(groupId, user.getId(), dto);
        return ResponseEntity.status(200).body(new ApiResponse("Group updated successfully"));
    }

    // the invite code and the QR content
    @GetMapping("/invite/{groupId}")
    public ResponseEntity<?> getInvite(@AuthenticationPrincipal User user, @PathVariable Integer groupId) {
        return ResponseEntity.status(200).body(groupService.getInvite(groupId, user.getId()));
    }

    @PutMapping("/resetInvite/{groupId}")
    public ResponseEntity<?> resetInviteCode(@AuthenticationPrincipal User user, @PathVariable Integer groupId) {
        return ResponseEntity.status(200).body(groupService.resetInviteCode(groupId, user.getId()));
    }

    // archived, the history stays
    @DeleteMapping("/delete/{groupId}")
    public ResponseEntity<?> deleteGroup(@AuthenticationPrincipal User user, @PathVariable Integer groupId) {
        groupService.deleteGroup(groupId, user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Group archived successfully"));
    }
}
