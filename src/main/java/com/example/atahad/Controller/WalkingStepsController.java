package com.example.atahad.Controller;
import com.example.atahad.Dto.In.*;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.Map;

@RestController @RequestMapping("/api/v1/walking") @RequiredArgsConstructor
public class WalkingStepsController {
    private final WalkingStepsService walking;
    private final AuthenticatedUserService auth;
    private Integer member(User user) {
        Integer id=user.getId();auth.checkMember(id);return id;
    }
    @GetMapping("/connection") public Map<String,Object> connection(@AuthenticationPrincipal User user) {
        return walking.connection(member(user));
    }
    @PutMapping("/connection") public Map<String,Object> check(@AuthenticationPrincipal User user,@Valid @RequestBody StepConnectionRequest request) {
        return walking.check(member(user),request);
    }
    @PostMapping("/weeks/{weekId}/sync") public Map<String,Object> sync(@AuthenticationPrincipal User user,@PathVariable Integer weekId,@Valid @RequestBody StepSyncRequest request) {
        return walking.sync(member(user),weekId,request);
    }
    @PostMapping("/weeks/{weekId}/screenshot") public Map<String,Object> screenshot(@AuthenticationPrincipal User user,@PathVariable Integer weekId,@Valid @RequestBody StepScreenshotRequest request) {
        return walking.screenshot(member(user),weekId,request);
    }
    @GetMapping("/weeks/{weekId}/progress") public Map<String,Object> progress(@AuthenticationPrincipal User user,@PathVariable Integer weekId,@RequestParam LocalDate day) {
        return walking.progress(member(user),weekId,day);
    }
}
