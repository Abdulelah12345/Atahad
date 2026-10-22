package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GoalProgressResponse {
    private Integer goalId;
    private String title;
    private String status;
    private Integer totalWeeks;
    private Integer currentWeek; // 0 when the goal did not start yet
    private Integer weeksLeft;
    private Integer fullWeeks;
    private Integer totalRequired;
    private Integer totalCompleted;
    private Integer percent; // completed out of required, from the weeks that started
    private LocalDate endDate;
}
