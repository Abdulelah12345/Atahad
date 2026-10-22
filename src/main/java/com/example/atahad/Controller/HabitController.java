package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Entity.Habit;
import com.example.atahad.Service.HabitService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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

    @GetMapping("/getMyHabits/{memberId}")
    public ResponseEntity<?> getMyHabits(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(habitService.getMyHabits(memberId));
    }

    @PostMapping("/add/{memberId}")
    public ResponseEntity<?> addHabit(@PathVariable Integer memberId, @RequestBody @Valid Habit habit){
        habitService.addHabit(memberId, habit);
        return ResponseEntity.status(200).body(new ApiResponse("Habit added"));
    }

    @PutMapping("/update/{memberId}/{id}")
    public ResponseEntity<?> updateHabit(@PathVariable Integer memberId, @PathVariable Integer id, @RequestBody @Valid Habit habit){
        habitService.updateHabit(memberId, id, habit);
        return ResponseEntity.status(200).body(new ApiResponse("Habit updated"));
    }

    @DeleteMapping("/delete/{memberId}/{id}")
    public ResponseEntity<?> deleteHabit(@PathVariable Integer memberId, @PathVariable Integer id){
        habitService.deleteHabit(memberId, id);
        return ResponseEntity.status(200).body(new ApiResponse("Habit deleted"));
    }
}
