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
}
