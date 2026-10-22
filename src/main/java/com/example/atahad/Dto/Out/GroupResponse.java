package com.example.atahad.Dto.Out;

import lombok.*;

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
}