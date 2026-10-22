package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

// member with user info, without the password
@Data
@AllArgsConstructor
@NoArgsConstructor
public class MemberResponse {
    private Integer id;
    private String name;
    private String email;
    private String phone;
    private String level;
    private Integer consecutiveWeeks;
    private Integer points;
    private Boolean isLocked;
    private Boolean emailLinked;
    private LocalDateTime createdAt;
}
