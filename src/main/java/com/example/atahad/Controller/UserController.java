package com.example.atahad.Controller;

import com.example.atahad.Entity.User;
import com.example.atahad.Service.UserService;
import com.example.atahad.Api.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllUsers() {
        return ResponseEntity.status(200).body(userService.getAllUsers());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getUserById(@PathVariable Integer id) {
        return ResponseEntity.status(200).body(userService.getUserById(id));
    }

    @PutMapping("/update")
    public ResponseEntity<?> updateUser(@AuthenticationPrincipal User user,@RequestBody User updatedUser) {
        userService.updateUser(user.getId(),updatedUser);
        return ResponseEntity.status(200).body(new ApiResponse("User updated successfully"));
    }

    @DeleteMapping("/delete")
    public ResponseEntity<?> deleteUser(@AuthenticationPrincipal User user) {
        userService.deleteUser(user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("User deleted successfully"));
    }
}