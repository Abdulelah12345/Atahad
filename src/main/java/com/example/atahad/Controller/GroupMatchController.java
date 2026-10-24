package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.GroupMatchService;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/group-match")
@RequiredArgsConstructor
public class GroupMatchController {
    private final GroupMatchService groupMatchService;

    // similar groups to challenge
    @GetMapping("/suggest/{groupId}")
    public ResponseEntity<?> suggestOpponents(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupMatchService.suggestOpponents(groupId, user.getId()));
    }

    // ?opponentGroupId=5 or ?inviteCode=AB12CD34
    @PostMapping("/challenge/{groupId}")
    public ResponseEntity<?> challenge(@AuthenticationPrincipal User user, @PathVariable Integer groupId,
                                       @RequestParam(required = false) Integer opponentGroupId,
                                       @RequestParam(required = false) String inviteCode){
        return ResponseEntity.status(200).body(groupMatchService.challenge(groupId, user.getId(), opponentGroupId, inviteCode));
    }

    @PutMapping("/respond/{matchId}/{accept}")
    public ResponseEntity<?> respond(@AuthenticationPrincipal User user, @PathVariable Integer matchId, @PathVariable Boolean accept){
        return ResponseEntity.status(200).body(groupMatchService.respond(matchId, user.getId(), accept));
    }

    @GetMapping("/get/{groupId}")
    public ResponseEntity<?> getMatches(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupMatchService.getMatches(groupId, user.getId()));
    }
}
