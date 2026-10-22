package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.GroupCreateRequest;
import com.example.atahad.Dto.In.GroupUpdateRequest;
import com.example.atahad.Service.GroupService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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

    @PostMapping("/add/{memberId}")
    public ResponseEntity<?> addGroup(@PathVariable Integer memberId, @RequestBody @Valid GroupCreateRequest dto) {
        return ResponseEntity.status(200).body(groupService.addGroup(memberId, dto));
    }

    @PutMapping("/update/{groupId}/{memberId}")
    public ResponseEntity<?> updateGroup(@PathVariable Integer groupId, @PathVariable Integer memberId, @RequestBody @Valid GroupUpdateRequest dto) {
        groupService.updateGroup(groupId, memberId, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Group updated successfully"));
    }

    // GENTLE or HYPE
    @PutMapping("/humor/{groupId}/{memberId}/{humorLevel}")
    public ResponseEntity<?> updateHumorLevel(@PathVariable Integer groupId, @PathVariable Integer memberId, @PathVariable String humorLevel) {
        groupService.updateHumorLevel(groupId, memberId, humorLevel);
        return ResponseEntity.status(200).body(new ApiResponse("Humor level updated"));
    }

    // the invite code and the QR content
    @GetMapping("/invite/{groupId}/{memberId}")
    public ResponseEntity<?> getInvite(@PathVariable Integer groupId, @PathVariable Integer memberId) {
        return ResponseEntity.status(200).body(groupService.getInvite(groupId, memberId));
    }

    @PutMapping("/resetInvite/{groupId}/{memberId}")
    public ResponseEntity<?> resetInviteCode(@PathVariable Integer groupId, @PathVariable Integer memberId) {
        return ResponseEntity.status(200).body(groupService.resetInviteCode(groupId, memberId));
    }

    // archived, the history stays
    @DeleteMapping("/delete/{groupId}/{memberId}")
    public ResponseEntity<?> deleteGroup(@PathVariable Integer groupId, @PathVariable Integer memberId) {
        groupService.deleteGroup(groupId, memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Group archived successfully"));
    }
}
