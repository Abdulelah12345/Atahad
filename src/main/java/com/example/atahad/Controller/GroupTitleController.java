package com.example.atahad.Controller;

import com.example.atahad.Service.GroupTitleService;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-title")
@RequiredArgsConstructor
public class GroupTitleController {
    private final GroupTitleService groupTitleService;

    @GetMapping("/latest/{groupId}")
    public ResponseEntity<?> getLatestTitles(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupTitleService.getLatestTitles(groupId, user.getId()));
    }

    @GetMapping("/history/{groupId}")
    public ResponseEntity<?> getTitlesHistory(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(groupTitleService.getTitlesHistory(groupId, user.getId()));
    }
}
