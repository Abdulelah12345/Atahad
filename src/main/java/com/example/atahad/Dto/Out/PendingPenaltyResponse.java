package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PendingPenaltyResponse {
    private Integer id;
    private BigDecimal amount;
    private String reason;
    private String commitmentTitle;
    private LocalDateTime createdAt;
}
