package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.GroupMemberService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-member")
@RequiredArgsConstructor
public class GroupMemberController {

    private final GroupMemberService groupMemberService;

    @GetMapping("/group/{groupId}")
    public ResponseEntity<?> getGroupMembers(@PathVariable Integer groupId) {
        return ResponseEntity.status(200).body(groupMemberService.getGroupMembers(groupId));
    }

    @GetMapping("/member/{memberId}")
    public ResponseEntity<?> getMemberGroups(@PathVariable Integer memberId) {
        return ResponseEntity.status(200).body(groupMemberService.getMemberGroups(memberId));
    }

    @PostMapping("/join/{memberId}/{inviteCode}")
    public ResponseEntity<?> joinGroup(@PathVariable Integer memberId, @PathVariable String inviteCode) {
        groupMemberService.joinGroup(memberId, inviteCode);
        return ResponseEntity.status(200).body(new ApiResponse("Joined group successfully"));
    }

    @DeleteMapping("/leave/{groupId}/{memberId}")
    public ResponseEntity<?> leaveGroup(@PathVariable Integer groupId, @PathVariable Integer memberId) {
        groupMemberService.leaveGroup(groupId, memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Left group successfully"));
    }
}