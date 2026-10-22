package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GoalProposalResponse {
    private Integer id;
    private String title;
    private String details;
    private String suggestedBy;
    private Integer votes;
    private Boolean myVote;
}
