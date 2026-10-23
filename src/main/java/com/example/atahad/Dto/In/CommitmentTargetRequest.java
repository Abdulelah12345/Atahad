package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// the place of a LOCATION commitment (or the minutes of a TIMER one), the app takes the place from the map
@Data
@AllArgsConstructor
@NoArgsConstructor
public class CommitmentTargetRequest {
    @DecimalMin(value = "-90.0", message = "Latitude must be between -90 and 90")
    @DecimalMax(value = "90.0", message = "Latitude must be between -90 and 90")
    private Double latitude;

    @DecimalMin(value = "-180.0", message = "Longitude must be between -180 and 180")
    @DecimalMax(value = "180.0", message = "Longitude must be between -180 and 180")
    private Double longitude;

    @Min(value = 50, message = "Radius must be at least 50 meters")
    @Max(value = 2000, message = "Radius must be at most 2000 meters")
    private Integer radiusMeters; // 150 when it is empty

    @Size(max = 100, message = "Place name must be 100 characters max")
    private String placeName;

    @Min(value = 1, message = "Minutes must be at least 1")
    @Max(value = 600, message = "Minutes must be at most 600")
    private Integer minutes;
}
