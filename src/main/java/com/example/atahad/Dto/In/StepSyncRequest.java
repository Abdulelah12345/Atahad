package com.example.atahad.Dto.In;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.*;

@Data
public class StepSyncRequest {
    @NotNull private LocalDate day;
    @NotNull @Min(0) @Max(200000) private Integer total;
    @NotBlank @Pattern(regexp="HEALTH_CONNECT|HEALTH_KIT") private String source;
    @NotBlank @Size(max=100) private String deviceId;
    @NotBlank @Pattern(regexp="Asia/Riyadh") private String zoneId;
    @NotNull private LocalDateTime observedAt;
}
