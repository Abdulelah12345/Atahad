package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupAlertResponse {
    private Integer id;
    private String groupName;
    private String senderName;
    private String message;
    private Boolean isCollective;
    private LocalDateTime sentAt;
}
