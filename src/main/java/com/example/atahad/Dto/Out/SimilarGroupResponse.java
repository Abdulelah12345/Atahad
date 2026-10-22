package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class SimilarGroupResponse {
    private Integer groupId;
    private String name;
    private Integer membersCount;
    private String goalTitle;
    private String proofMethod;
}
