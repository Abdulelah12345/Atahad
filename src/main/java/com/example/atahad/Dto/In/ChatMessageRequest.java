package com.example.atahad.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChatMessageRequest {
    @NotEmpty(message = "Message cannot be empty")
    @Size(max = 1000, message = "Message must be 1000 characters max")
    private String content;
}
