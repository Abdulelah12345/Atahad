package com.example.atahad.Dto.In;
@lombok.Data
public class QuizSourceRequest {
    private Integer proofId;
    @jakarta.validation.constraints.Size(max=6) private java.util.List<Integer> captureIds = new java.util.ArrayList<>();
    private Boolean reupload = false;
}
