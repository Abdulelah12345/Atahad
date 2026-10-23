package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.time.LocalDateTime;

// DTO خاصة بتعديل البروف فقط، وليست طلب إضافة.
@Data
public class ProofUpdateRequest {

    @NotNull(message = "Activity time is required")
    @PastOrPresent(message = "Activity time cannot be in the future")
    private LocalDateTime activityTime;

    @NotBlank(message = "Evidence data cannot be empty")
    private String evidenceData;
}
