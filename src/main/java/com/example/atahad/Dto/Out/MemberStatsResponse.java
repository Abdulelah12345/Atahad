package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

// the progress card on the profile
@Data
@AllArgsConstructor
@NoArgsConstructor
public class MemberStatsResponse {
    private String level;
    private Integer consecutiveWeeks;
    private String nextLevel; // null when the member is IRON
    private Integer weeksToNextLevel;
    private Integer points;
    private Integer pointsToGraceDay;
    private Integer availableGraceDays;
    private Integer graceDayCapacity;
    private Integer fullWeeks;
    private Integer activeCommitments;
    private BigDecimal totalDonated;
}
