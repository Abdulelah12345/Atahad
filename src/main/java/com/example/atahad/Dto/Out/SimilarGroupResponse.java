package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class SimilarGroupResponse {

    private Integer groupId;
    private String name;
    private Integer membersCount;
    private String goalTitle;
    private String proofMethod;
    private Integer compatibilityScore;
    private String reason;
}