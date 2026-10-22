package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

// the owner confirms the goal (from a proposal or written by him)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupGoalRequest {
    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 100, message = "Title must be 100 characters max")
    private String title;

    @NotEmpty(message = "Proof method cannot be empty")
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|PLATFORM|TIMER)$", message = "Proof method must be LOCATION, PHOTO, QUIZ, PLATFORM or TIMER")
    private String proofMethod;

    @NotNull(message = "Times per week cannot be empty")
    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    private Integer timesPerWeek;

    @NotNull(message = "Amount per time cannot be empty")
    @DecimalMin(value = "5.00", message = "Amount per time must be at least 5")
    private BigDecimal amountPerTime;

    @NotNull(message = "Total weeks cannot be empty")
    @Min(value = 1, message = "Total weeks must be at least 1")
    @Max(value = 52, message = "Total weeks must be at most 52")
    private Integer totalWeeks;

    private Integer proposalId; // optional, the chosen proposal
}
