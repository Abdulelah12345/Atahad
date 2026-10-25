package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

// one line on the home screen: a habit, or one task of a goal
@Data
@AllArgsConstructor
@NoArgsConstructor
public class TodayTaskResponse {
    private Integer commitmentId;
    private Integer weekId;
    private Integer goalTaskId; // null for habits
    private String type; // HABIT or GOAL
    private String title;
    private String proofMethod;
    private Integer required;
    private Integer completed;
    private Integer excused;
    private Integer remaining;
    private Integer daysLeft;
    private String trackStatus;
    private BigDecimal amountPerTime;
    private String goalTitle;
    private String taskTitle;
    private Boolean plannedToday; // only a reminder, never a deduction
}
