package com.example.atahad.Controller;

import com.example.atahad.Service.PlaceSearchService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/place")
@RequiredArgsConstructor
public class PlaceController {
    private final PlaceSearchService placeSearchService;

    // search a place by its name, lat and lng (optional) put the near places first
    @GetMapping("/search")
    public ResponseEntity<?> search(@RequestParam String query,
                                    @RequestParam(required = false) Double lat,
                                    @RequestParam(required = false) Double lng) {
        return ResponseEntity.status(200).body(placeSearchService.search(query, lat, lng));
    }
}
