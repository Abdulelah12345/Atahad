package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupResponse {
    private Integer id;
    private String name;
    private String description;
    private String inviteCode;
    private LocalDateTime createdAt;
    private Integer membersCount;
    private String humorLevel;
    private Integer points;
    private Integer pointsForGraceDay;
    private String status;
    private String activeGoalTitle; // null when the group has no goal now
}
