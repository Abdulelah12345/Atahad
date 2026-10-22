package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PlanWeekResponse {
    private Integer weekNumber;
    private String title;
    private Integer timesPerWeek;
}
