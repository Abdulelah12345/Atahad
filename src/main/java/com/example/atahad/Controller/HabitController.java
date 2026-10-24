package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.Habit;
import com.example.atahad.Entity.User;
import com.example.atahad.Service.HabitService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/habit")
@RequiredArgsConstructor
public class HabitController {
    private final HabitService habitService;

    // admin
    @GetMapping("/get")
    public ResponseEntity<?> getAllHabits(){
        return ResponseEntity.status(200).body(habitService.getAllHabits());
    }

    @GetMapping("/getMyHabits")
    public ResponseEntity<?> getMyHabits(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(habitService.getMyHabits(user.getId()));
    }

    @PostMapping("/add")
    public ResponseEntity<?> addHabit(@AuthenticationPrincipal User user, @RequestBody @Valid Habit habit){
        habitService.addHabit(user.getId(), habit);
        return ResponseEntity.status(200).body(new ApiResponse("Habit added"));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateHabit(@AuthenticationPrincipal User user, @PathVariable Integer id, @RequestBody @Valid Habit habit){
        habitService.updateHabit(user.getId(), id, habit);
        return ResponseEntity.status(200).body(new ApiResponse("Habit updated"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteHabit(@AuthenticationPrincipal User user, @PathVariable Integer id){
        habitService.deleteHabit(user.getId(), id);
        return ResponseEntity.status(200).body(new ApiResponse("Habit deleted"));
    }
}
