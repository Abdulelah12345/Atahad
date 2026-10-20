package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

// admin with user info, without the password
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AdminResponse {
    private Integer id;
    private String name;
    private String email;
    private String phone;
    private String jobTitle;
    private LocalDateTime lastLoginAt;
    private Integer reviewedCount;
    private LocalDateTime createdAt;
}
