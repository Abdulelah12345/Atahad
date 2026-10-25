package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.MomentRequest;
import com.example.atahad.Service.MomentService;
import jakarta.validation.Valid;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/moment")
@RequiredArgsConstructor
public class MomentController {
    private final MomentService momentService;

    // the photo or the video from the camera (multipart, field "file"), returns its link for /add
    @PostMapping("/upload")
    public ResponseEntity<?> upload(@RequestParam("file") MultipartFile file){
        String name = momentService.upload(file);
        String url = ServletUriComponentsBuilder.fromCurrentContextPath().path("/uploads/moments/").path(name).toUriString();
        return ResponseEntity.status(200).body(Map.of("url", url));
    }

    @PostMapping("/add")
    public ResponseEntity<?> add(@AuthenticationPrincipal User user, @RequestBody @Valid MomentRequest dto){
        return ResponseEntity.status(200).body(momentService.add(user.getId(), dto));
    }

    @GetMapping("/my")
    public ResponseEntity<?> getMyMoments(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(momentService.getMyMoments(user.getId()));
    }

    @GetMapping("/group/{groupId}")
    public ResponseEntity<?> getGroupFeed(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(momentService.getGroupFeed(groupId, user.getId()));
    }

    // the home screen widget
    @GetMapping("/widget")
    public ResponseEntity<?> getLatestForWidget(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(momentService.getLatestForWidget(user.getId()));
    }

    @DeleteMapping("/delete/{momentId}")
    public ResponseEntity<?> delete(@AuthenticationPrincipal User user, @PathVariable Integer momentId){
        momentService.delete(user.getId(), momentId);
        return ResponseEntity.status(200).body(new ApiResponse("Moment deleted"));
    }
}
