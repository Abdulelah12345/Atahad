package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.MomentRequest;
import com.example.atahad.Service.MomentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/moment")
@RequiredArgsConstructor
public class MomentController {
    private final MomentService momentService;

    @PostMapping("/add/{memberId}")
    public ResponseEntity<?> add(@PathVariable Integer memberId, @RequestBody @Valid MomentRequest dto){
        return ResponseEntity.status(200).body(momentService.add(memberId, dto));
    }

    @GetMapping("/my/{memberId}")
    public ResponseEntity<?> getMyMoments(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(momentService.getMyMoments(memberId));
    }

    @GetMapping("/group/{groupId}/{memberId}")
    public ResponseEntity<?> getGroupFeed(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(momentService.getGroupFeed(groupId, memberId));
    }

    // the home screen widget
    @GetMapping("/widget/{memberId}")
    public ResponseEntity<?> getLatestForWidget(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(momentService.getLatestForWidget(memberId));
    }

    @DeleteMapping("/delete/{memberId}/{momentId}")
    public ResponseEntity<?> delete(@PathVariable Integer memberId, @PathVariable Integer momentId){
        momentService.delete(memberId, momentId);
        return ResponseEntity.status(200).body(new ApiResponse("Moment deleted"));
    }
}
