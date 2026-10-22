package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.AccountService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/account")
@RequiredArgsConstructor
public class AccountController {
    private final AccountService accountService;

    // leaves every group and ends every commitment, only when nothing is owed
    @PutMapping("/deactivate/{memberId}")
    public ResponseEntity<?> deactivate(@PathVariable Integer memberId){
        accountService.deactivate(memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Account deactivated"));
    }

    // admin
    @PutMapping("/unban/{adminId}/{memberId}")
    public ResponseEntity<?> unban(@PathVariable Integer adminId, @PathVariable Integer memberId){
        accountService.unban(adminId, memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Account unbanned"));
    }
}
