package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.GroupMemberService;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-member")
@RequiredArgsConstructor
public class GroupMemberController {

    private final GroupMemberService groupMemberService;

    // the members of a group, only for its members
    @GetMapping("/group/{groupId}")
    public ResponseEntity<?> getGroupMembers(@AuthenticationPrincipal User user, @PathVariable Integer groupId) {
        return ResponseEntity.status(200).body(groupMemberService.getGroupMembers(groupId, user.getId()));
    }

    // the groups of the logged in member
    @GetMapping("/my")
    public ResponseEntity<?> getMyGroups(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(groupMemberService.getMemberGroups(user.getId()));
    }

    // admin: the groups of any member
    @GetMapping("/member/{memberId}")
    public ResponseEntity<?> getMemberGroups(@PathVariable Integer memberId) {
        return ResponseEntity.status(200).body(groupMemberService.getMemberGroups(memberId));
    }

    // by the invite code or the QR code
    @PostMapping("/join/{inviteCode}")
    public ResponseEntity<?> joinGroup(@AuthenticationPrincipal User user, @PathVariable String inviteCode) {
        groupMemberService.joinGroup(user.getId(), inviteCode);
        return ResponseEntity.status(200).body(new ApiResponse("Joined group successfully"));
    }

    // the owner adds a member directly
    @PostMapping("/add/{groupId}/{memberId}")
    public ResponseEntity<?> addMemberDirectly(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @PathVariable Integer memberId) {
        groupMemberService.addMemberDirectly(groupId, user.getId(), memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Member added to the group"));
    }

    @DeleteMapping("/leave/{groupId}")
    public ResponseEntity<?> leaveGroup(@AuthenticationPrincipal User user, @PathVariable Integer groupId) {
        groupMemberService.leaveGroup(groupId, user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Left group successfully"));
    }
}
