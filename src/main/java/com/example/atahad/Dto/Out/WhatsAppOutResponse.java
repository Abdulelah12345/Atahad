package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// what n8n needs to send one message with UltraMsg
@Data
@AllArgsConstructor
@NoArgsConstructor
public class WhatsAppOutResponse {
    private Integer id;
    private String to;
    private String body;
    private String type;
}
