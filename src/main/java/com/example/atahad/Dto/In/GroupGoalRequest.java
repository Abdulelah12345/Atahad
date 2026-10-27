package com.example.atahad.Dto.In;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

// the owner confirms the goal (from a proposal or written by him)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupGoalRequest {
    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 100, message = "Title must be 100 characters max")
    private String title;

    @NotEmpty(message = "Proof method cannot be empty")
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|TIMER)$", message = "Proof method must be LOCATION, PHOTO, QUIZ or TIMER")
    private String proofMethod;

    // the same times every week (not needed when the goal has a plan of weeks)
    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    private Integer timesPerWeek;

    @NotNull(message = "Amount per time cannot be empty")
    @DecimalMin(value = "5.00", message = "Amount per time must be at least 5")
    private BigDecimal amountPerTime;

    // not needed when the goal has a plan of weeks
    @Min(value = 1, message = "Total weeks must be at least 1")
    @Max(value = 52, message = "Total weeks must be at most 52")
    private Integer totalWeeks;

    private Integer proposalId; // optional, the chosen proposal
    // optional, SOLO (the default): only who missed donates, HARD: everyone donates when one misses
    @Pattern(regexp = "^(SOLO|HARD)$", message = "Difficulty must be SOLO or HARD")
    private String difficulty;

    // TIMER only: the minutes of one time, the same for every member
    @Min(value = 1, message = "Minutes must be at least 1")
    @Max(value = 600, message = "Minutes must be at most 600")
    private Integer targetMinutes;

    // optional, the plan of the AI (or changed by the owner): a task and the times for every week,
    // every member gets the same task and times in the same week
    @Size(max = 52, message = "The plan can be 52 weeks max")
    private List<@Valid PlanWeekRequest> weeks;
}
