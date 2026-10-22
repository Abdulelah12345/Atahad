package com.example.atahad.Controller;

import com.example.atahad.Service.GroupTitleService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-title")
@RequiredArgsConstructor
public class GroupTitleController {
    private final GroupTitleService groupTitleService;

    @GetMapping("/latest/{groupId}/{memberId}")
    public ResponseEntity<?> getLatestTitles(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupTitleService.getLatestTitles(groupId, memberId));
    }

    @GetMapping("/history/{groupId}/{memberId}")
    public ResponseEntity<?> getTitlesHistory(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(groupTitleService.getTitlesHistory(groupId, memberId));
    }
}
