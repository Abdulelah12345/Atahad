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
        groupService.addGroup(memberId, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Group added successfully"));
    }

    @PutMapping("/update/{groupId}/{memberId}")
    public ResponseEntity<?> updateGroup(@PathVariable Integer groupId, @PathVariable Integer memberId, @RequestBody @Valid GroupUpdateRequest dto) {
        groupService.updateGroup(groupId, memberId, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Group updated successfully"));
    }

    @DeleteMapping("/delete/{groupId}/{memberId}")
    public ResponseEntity<?> deleteGroup(@PathVariable Integer groupId,@PathVariable Integer memberId) {
        groupService.deleteGroup(groupId, memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Group deleted successfully"));
    }
}