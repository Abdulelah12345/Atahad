package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.time.LocalDateTime;
//نستخدمها في ميثود addProof
@Data
public class ProofRequest {

    @NotBlank(message = "Type cannot be empty")
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|TIMER)$",
            message = "Invalid proof type")
    private String type;

    @NotNull(message = "Activity time is required")
    @PastOrPresent(message = "Activity time cannot be in the future")
    private LocalDateTime activityTime;

    @NotBlank(message = "Evidence data cannot be empty")
    private String evidenceData;
}