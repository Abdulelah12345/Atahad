package com.example.atahad.Dto.Out;

import java.time.LocalDate;
import java.util.List;

public record WeeklyReportResponse(
        Integer memberId,
        String name,
        String email,
        LocalDate weekStart,
        LocalDate weekEnd,
        Integer required,
        Integer completed,
        Integer excused,
        Integer completionPercentage,
        List<CommitmentResult> commitments,
        String aiAnalysis
) {
    public record CommitmentResult(
            String title,
            Integer required,
            Integer completed,
            Integer excused
    ) {}
}