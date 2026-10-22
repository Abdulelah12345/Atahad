package com.example.atahad.Controller;

import com.example.atahad.Entity.Excuse;
import com.example.atahad.Service.ExcuseService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/excuse")
@RequiredArgsConstructor
public class ExcuseController {

    private final ExcuseService excuseService;

    @GetMapping("/get")
    public ResponseEntity<List<Excuse>> getAllExcuses() {
        return ResponseEntity.ok(excuseService.getAllExcuses());
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<Excuse> getExcuseById(@PathVariable Integer id) {
        return ResponseEntity.ok(excuseService.getExcuseById(id));
    }
}