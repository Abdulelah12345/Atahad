package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor

public class GoalProposalRequest {
    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 100, message = "Title must be 100 characters max")
    private String title;

    @Size(max = 500, message = "Details must be 500 characters max")
    private String details;

    @NotNull(message = "Times per week cannot be null")
    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    private Integer timesPerWeek;
    public GoalProposalRequest(String title, String details){
        this.title = title;
        this.details = details;
        this.timesPerWeek = 3;
    }
}
