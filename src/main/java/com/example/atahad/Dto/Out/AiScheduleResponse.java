package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class AiScheduleResponse {

    private String title;
    private Integer durationMinutes;
    private List<ScheduleSuggestion> suggestions;

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class ScheduleSuggestion {
        private String date;
        private String startTime;
        private String endTime;
    }
}