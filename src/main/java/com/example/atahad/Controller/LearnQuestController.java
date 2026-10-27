
package com.example.atahad.Controller;

import com.example.atahad.Service.LearnQuestService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/learn-quest")
@RequiredArgsConstructor
public class LearnQuestController {

    private final LearnQuestService learnQuestService;

    @GetMapping("/search")
    public ResponseEntity<?> search(@RequestParam String query){
        return ResponseEntity.status(200).body(learnQuestService.search(query));
    }

    @GetMapping("/books")
    public ResponseEntity<?> books(@RequestParam String query){
        return ResponseEntity.status(200).body(learnQuestService.searchBooks(query));
    }

    @GetMapping("/podcasts")
    public ResponseEntity<?> podcasts(@RequestParam String query){
        return ResponseEntity.status(200).body(learnQuestService.searchPodcasts(query));
    }

    @GetMapping("/courses")
    public ResponseEntity<?> courses(@RequestParam String query){
        return ResponseEntity.status(200).body(learnQuestService.searchCourses(query));
    }
}
