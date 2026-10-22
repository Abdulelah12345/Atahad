package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.AdminRegisterRequest;
import com.example.atahad.Dto.In.AdminUpdateRequest;
import com.example.atahad.Service.AdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllAdmins() {
        return ResponseEntity.status(200).body(adminService.getAllAdmins());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getAdminById(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(adminService.getAdminById(id));
    }

    @PostMapping("/register")
    public ResponseEntity<?> registerAdmin(@RequestBody @Valid AdminRegisterRequest dto) {
        adminService.registerAdmin(dto);
        return ResponseEntity.status(200).body(new ApiResponse("Admin registered successfully"));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateAdmin(@PathVariable Integer id, @RequestBody @Valid AdminUpdateRequest dto) {
        adminService.updateAdmin(id, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Admin updated successfully"));
    }
}