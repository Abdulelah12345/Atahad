package com.example.atahad.Dto.In;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.LocalDate;

@Data
public class StepScreenshotRequest {
    @NotNull private LocalDate day;
    @NotBlank @Size(max=3000000) private String imageData;
}
