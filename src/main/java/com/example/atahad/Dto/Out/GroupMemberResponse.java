package com.example.atahad.Dto.Out;

import lombok.*;
import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupMemberResponse {

    private Integer groupId;
    private String groupName;
    private Integer memberId;
    private String name;
    private Integer points;
    private String role;
    private LocalDateTime joinedAt;
}