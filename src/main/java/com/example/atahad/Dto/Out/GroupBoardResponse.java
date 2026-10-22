package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one row of the group screen: how every member is doing this week
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupBoardResponse {
    private Integer memberId;
    private String name;
    private Integer required;
    private Integer completed;
    private Integer remaining;
    private Integer daysLeft;
    private String trackStatus;
    private Integer failureCount;
    private Boolean hasExcuse; // alerts stop when the member sent an excuse
}
