package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class MomentResponse {
    private Integer id;
    private Integer memberId;
    private String name;
    private String mediaUrl;
    private String mediaType;
    private String caption;
    private String visibility;
    private String groupName;
    private LocalDateTime createdAt;
}
