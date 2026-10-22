package com.example.atahad.Controller;

import com.example.atahad.Entity.Objection;
import com.example.atahad.Service.ObjectionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/objection")
@RequiredArgsConstructor
public class ObjectionController {

    private final ObjectionService objectionService;

    @GetMapping("/get-all")
    public ResponseEntity<?> getAllObjections() {
        List<Objection> objectionList = objectionService.getAllObjections();
        return ResponseEntity.status(200).body(objectionList);
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> getObjectionById(@PathVariable Integer id) {
        Objection objection = objectionService.getObjectionById(id);
        return ResponseEntity.status(200).body(objection);
    }

}