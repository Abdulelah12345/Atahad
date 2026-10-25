package com.example.atahad.Controller;

import com.example.atahad.Service.QuizService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/quiz")
@RequiredArgsConstructor
public class QuizController {
    private final QuizService quizService;

    // a new quiz for a QUIZ commitment: ?goalTaskId= for goals, ?topic= what he studied today (optional)
    @PostMapping("/create/{memberId}/{weekId}")
    public ResponseEntity<?> create(@PathVariable Integer memberId, @PathVariable Integer weekId,
                                    @RequestParam(required = false) Integer goalTaskId,
                                    @RequestParam(required = false) String topic,
                                    @jakarta.validation.Valid @RequestBody(required=false) com.example.atahad.Dto.In.QuizSourceRequest source){
        return ResponseEntity.status(200).body(quizService.create(memberId, weekId, goalTaskId, topic, source==null?new com.example.atahad.Dto.In.QuizSourceRequest():source));
    }
}
