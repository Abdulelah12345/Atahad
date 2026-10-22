package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

// what the lock screen shows
@Data
@AllArgsConstructor
@NoArgsConstructor
public class LockStatusResponse {
    private Boolean isLocked;
    private BigDecimal totalToDonate;
    private List<PendingPenaltyResponse> penalties;
}
