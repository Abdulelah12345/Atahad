package com.example.atahad.Controller;

import com.example.atahad.Service.CommitmentWeekService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/commitment-week")
@RequiredArgsConstructor
public class CommitmentWeekController {
    private final CommitmentWeekService commitmentWeekService;

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getWeek(@PathVariable Integer id){
        return ResponseEntity.status(200).body(commitmentWeekService.getWeekById(id));
    }

    @GetMapping("/getHistory/{memberId}/{commitmentId}")
    public ResponseEntity<?> getHistory(@PathVariable Integer memberId, @PathVariable Integer commitmentId){
        return ResponseEntity.status(200).body(commitmentWeekService.getHistory(memberId, commitmentId));
    }

    @GetMapping("/getCurrent/{memberId}/{commitmentId}")
    public ResponseEntity<?> getCurrentWeek(@PathVariable Integer memberId, @PathVariable Integer commitmentId){
        return ResponseEntity.status(200).body(commitmentWeekService.getCurrentWeek(memberId, commitmentId));
    }
}
