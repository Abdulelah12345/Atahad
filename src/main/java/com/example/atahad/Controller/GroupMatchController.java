package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Service.GroupMatchService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/group-match")
@RequiredArgsConstructor
public class GroupMatchController {
    private final GroupMatchService groupMatchService;

    // similar groups to challenge
    @GetMapping("/suggest/{groupId}/{memberId}")
    public ResponseEntity<?> suggestOpponents(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupMatchService.suggestOpponents(groupId, memberId));
    }

    // ?opponentGroupId=5 or ?inviteCode=AB12CD34
    @PostMapping("/challenge/{groupId}/{ownerId}")
    public ResponseEntity<?> challenge(@PathVariable Integer groupId, @PathVariable Integer ownerId,
                                       @RequestParam(required = false) Integer opponentGroupId,
                                       @RequestParam(required = false) String inviteCode){
        return ResponseEntity.status(200).body(groupMatchService.challenge(groupId, ownerId, opponentGroupId, inviteCode));
    }

    @PutMapping("/respond/{matchId}/{ownerId}/{accept}")
    public ResponseEntity<?> respond(@PathVariable Integer matchId, @PathVariable Integer ownerId, @PathVariable Boolean accept){
        return ResponseEntity.status(200).body(groupMatchService.respond(matchId, ownerId, accept));
    }

    @GetMapping("/get/{groupId}/{memberId}")
    public ResponseEntity<?> getMatches(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupMatchService.getMatches(groupId, memberId));
    }
}
