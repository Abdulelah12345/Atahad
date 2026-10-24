package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.AccountService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/account")
@RequiredArgsConstructor
public class AccountController {
    private final AccountService accountService;

    @PutMapping("/deactivate")
    public ResponseEntity<?> deactivate(@AuthenticationPrincipal User user){
        accountService.deactivate(user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("Account deactivated"));
    }


    @PutMapping("/unban/{adminId}/{memberId}")
    public ResponseEntity<?> unban(@PathVariable Integer adminId, @PathVariable Integer memberId){
        accountService.unban(adminId, memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Account unbanned"));
    }
}
