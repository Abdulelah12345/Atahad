package com.example.atahad.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class AiScheduleRequest {

    @NotNull(message = "Member ID is required")
    private Integer memberId;

    @NotEmpty(message = "Goal description is required")
    private String description;
}