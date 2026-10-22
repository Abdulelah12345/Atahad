package com.example.atahad.Dto.In;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one week of the plan, the member can change it before saving
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PlanWeekRequest {
    @NotEmpty(message = "Week task title cannot be empty")
    @Size(max = 100, message = "Week task title must be 100 characters max")
    private String title;

    @NotNull(message = "Times per week cannot be empty")
    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    private Integer timesPerWeek;
}
