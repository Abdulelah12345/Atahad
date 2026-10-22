package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PenaltyResponse {
    private Integer id;
    private Integer memberId;
    private BigDecimal amount;
    private String reason; // LOST_DAY, WITHDRAWAL, GROUP_COLLECTIVE, GROUP_EXTRA
    private String status; // PENDING, PAID, CANCELLED
    private String about; // the commitment or the group
    private LocalDateTime createdAt;
    private LocalDateTime paidAt;
}
