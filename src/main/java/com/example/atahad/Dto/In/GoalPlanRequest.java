package com.example.atahad.Dto.In;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

// the plan after the member agreed or changed it, saved as a goal with a task for every week
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GoalPlanRequest {
    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 100, message = "Title must be 100 characters max")
    private String title;

    @Size(max = 500, message = "Description must be 500 characters max")
    private String description;

    @NotEmpty(message = "Proof method cannot be empty")
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|PLATFORM|TIMER)$", message = "Proof method must be LOCATION, PHOTO, QUIZ, PLATFORM or TIMER")
    private String proofMethod;

    @NotNull(message = "Amount per time cannot be empty")
    @DecimalMin(value = "5.00", message = "Amount per time must be at least 5")
    private BigDecimal amountPerTime;

    @NotEmpty(message = "The plan needs at least one week")
    @Size(max = 52, message = "The plan can be 52 weeks max")
    private List<@Valid PlanWeekRequest> weeks;

    // LOCATION: the place (each member can set his own with /commitment/target), TIMER: the minutes of one time
    @DecimalMin(value = "-90.0", message = "Latitude must be between -90 and 90")
    @DecimalMax(value = "90.0", message = "Latitude must be between -90 and 90")
    private Double targetLatitude;

    @DecimalMin(value = "-180.0", message = "Longitude must be between -180 and 180")
    @DecimalMax(value = "180.0", message = "Longitude must be between -180 and 180")
    private Double targetLongitude;

    @Min(value = 50, message = "Radius must be at least 50 meters")
    @Max(value = 2000, message = "Radius must be at most 2000 meters")
    private Integer targetRadiusMeters;

    @Size(max = 100, message = "Place name must be 100 characters max")
    private String targetPlaceName;

    @Min(value = 1, message = "Minutes must be at least 1")
    @Max(value = 600, message = "Minutes must be at most 600")
    private Integer targetMinutes;
}
