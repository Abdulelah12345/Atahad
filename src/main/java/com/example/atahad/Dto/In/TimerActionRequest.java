package com.example.atahad.Dto.In;
@lombok.Data
public class TimerActionRequest {
    @jakarta.validation.constraints.Min(1) @jakarta.validation.constraints.Max(600) private Integer minutes;
    @jakarta.validation.constraints.Pattern(regexp="EASY|OK|TIRING") private String feedback;
}
