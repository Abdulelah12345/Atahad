package com.example.atahad.Dto.In;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.LocalDate;

@Data
public class StepConnectionRequest {
    @NotBlank @Pattern(regexp="HEALTH_CONNECT|HEALTH_KIT") private String source;
    @NotBlank @Size(max=100) private String deviceId;
    // UNKNOWN also covers HealthKit's deliberately ambiguous read authorization.
    @NotBlank @Pattern(regexp="READY|UNAVAILABLE|NEEDS_PERMISSION|UNKNOWN") private String status;
    private LocalDate readDay;
    @Min(0) @Max(200000) private Integer stepsRead;
}
