package com.example.atahad.Dto.In;
@lombok.Data
public class ProofAttemptStartRequest {
    @jakarta.validation.constraints.Min(1) private Integer goalTaskId;
    private Boolean beforeAfter = false;
    private Integer beforeCaptureId;
    @jakarta.validation.constraints.Min(1) @jakarta.validation.constraints.Max(600) private Integer targetMinutes;
}
