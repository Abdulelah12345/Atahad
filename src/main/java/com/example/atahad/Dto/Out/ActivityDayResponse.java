package com.example.atahad.Dto.Out;

import java.time.LocalDate;

public record ActivityDayResponse(
        LocalDate date,
        Integer completed,
        String status
) {
}