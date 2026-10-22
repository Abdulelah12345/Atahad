package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;

// the suggestion of the AI, not saved: the member agrees or changes it, then sends it to /goal/addWithPlan
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GoalPlanResponse {
    private String title;
    private LocalDate endDate;
    private Integer totalWeeks;
    private String proofMethod;
    private String note; // why this plan, from the AI
    private List<PlanWeekResponse> weeks;
}
