package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChatMessageResponse {
    private Integer id;
    private String type;
    private String content;
    private Integer senderId; // null for SYSTEM messages
    private String senderName;
    private LocalDateTime sentAt;
}
