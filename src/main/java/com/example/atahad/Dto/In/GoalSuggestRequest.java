package com.example.atahad.Dto.In;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

// the member writes his goal and when it ends, the AI suggests the weekly plan
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GoalSuggestRequest {
    @NotEmpty(message = "Write your goal")
    @Size(max = 300, message = "Goal must be 300 characters max")
    private String goal;

    @NotNull(message = "End date cannot be empty")
    @Future(message = "End date must be in the future")
    private LocalDate endDate;
}
