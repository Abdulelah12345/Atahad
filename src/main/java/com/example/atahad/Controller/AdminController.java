package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.AdminRegisterRequest;
import com.example.atahad.Dto.In.AdminUpdateRequest;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.AdminMemberService;
import com.example.atahad.Service.AdminService;
import com.example.atahad.Service.GraceDayService;
import com.example.atahad.Service.ProofMethodService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;
    private final AdminMemberService adminMemberService;
    private final ProofMethodService proofMethodService;
    private final GraceDayService graceDayService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllAdmins() {
        return ResponseEntity.status(200).body(adminService.getAllAdmins());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getAdminById(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(adminService.getAdminById(id));
    }

    @GetMapping("/profile")
    public ResponseEntity<?> getMyProfile(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(adminService.getAdminById(user.getId()));
    }

    @PostMapping("/register")
    public ResponseEntity<?> registerAdmin(@RequestBody @Valid AdminRegisterRequest dto) {
        adminService.registerAdmin(dto);
        return ResponseEntity.status(200).body(new ApiResponse("Admin registered successfully"));
    }

    @PutMapping("/update")
    public ResponseEntity<?> updateAdmin(@AuthenticationPrincipal User user,@RequestBody @Valid AdminUpdateRequest dto) {
        adminService.updateAdmin(user.getId(),dto);
        return ResponseEntity.status(200).body(new ApiResponse("Admin updated successfully"));
    }

    // ---- members ----

    @GetMapping("/members")
    public ResponseEntity<?> searchMembers(@RequestParam(required = false) String query) {
        return ResponseEntity.status(200).body(adminMemberService.search(query));
    }

    @PutMapping("/members/{memberId}/suspend")
    public ResponseEntity<?> suspendMember(@PathVariable Integer memberId) {
        adminMemberService.suspend(memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Account suspended"));
    }

    @PutMapping("/members/{memberId}/restore")
    public ResponseEntity<?> restoreMember(@PathVariable Integer memberId) {
        adminMemberService.restore(memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Account restored"));
    }

    // a pardon card as a gift (4 weeks, like the earned ones)
    @PostMapping("/members/{memberId}/grace-day")
    public ResponseEntity<?> giveGraceDay(@AuthenticationPrincipal User user, @PathVariable Integer memberId, @RequestParam String reason) {
        graceDayService.grantGraceDay(user.getId(), memberId, reason);
        return ResponseEntity.status(200).body(new ApiResponse("Grace day granted"));
    }

    // ---- proof methods ----

    @GetMapping("/proof-methods")
    public ResponseEntity<?> getProofMethods() {
        return ResponseEntity.status(200).body(proofMethodService.getAll());
    }

    @PutMapping("/proof-methods/{id}/toggle")
    public ResponseEntity<?> toggleProofMethod(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(proofMethodService.toggle(id));
    }
}
