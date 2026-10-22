package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupMatchResponse {
    private Integer id;
    private String status;
    private Integer challengerId;
    private String challengerName;
    private Integer opponentId;
    private String opponentName;
    private Integer challengerScore;
    private Integer opponentScore;
    private String winnerName; // null until it finishes or when it is a draw
    private String leastProcrastinatingName;
    private LocalDate startDate;
    private LocalDate endDate;
}
