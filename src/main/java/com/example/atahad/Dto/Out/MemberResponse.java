package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

// member with user info, without the password or card token
@Data
@AllArgsConstructor
@NoArgsConstructor
public class MemberResponse {
    private Integer id;
    private String name;
    private String email;
    private String phone;
//    private String plan;
//    private LocalDate trialEndsAt;
     private LocalDate renewsAt;
    private String cardType;
    private String level;
    private Integer consecutiveWeeks;
    private Integer taskPoints;
    private Boolean canCreateCommitment;
    private Boolean hasNoHoldPrivilege;
    private LocalDateTime createdAt;
}
