package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.MemberRegisterRequest;
import com.example.atahad.Dto.In.MemberUpdateRequest;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.MemberService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/member")
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllMembers() {
        return ResponseEntity.status(200).body(memberService.getAllMembers());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getMemberById(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(memberService.getMemberById(id));
    }

    @GetMapping("/profile")
    public ResponseEntity<?> getMyProfile(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(memberService.getMemberById(user.getId()));
    }

    @PostMapping("/register")
    public ResponseEntity<?> registerMember(@RequestBody @Valid MemberRegisterRequest dto) {
        memberService.registerMember(dto);
        return ResponseEntity.status(200).body(new ApiResponse("Member registered successfully"));
    }

    @PutMapping("/update")
    public ResponseEntity<?> updateMember(@AuthenticationPrincipal User user,@RequestBody @Valid MemberUpdateRequest dto) {
        memberService.updateMember(user.getId(),dto);
        return ResponseEntity.status(200).body(new ApiResponse("Member updated successfully"));
    }

    @DeleteMapping("/delete")
    public ResponseEntity<?> deleteMember(@AuthenticationPrincipal User user) {
        memberService.deleteMember(user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Member deleted successfully"));
    }
}