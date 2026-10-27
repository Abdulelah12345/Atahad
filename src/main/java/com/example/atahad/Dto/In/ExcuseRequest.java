package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.time.LocalDate;

// add or edit an excuse, the status fields are set by the server
@Data
public class ExcuseRequest {

    @NotBlank(message = "Type cannot be empty")
    @Pattern(regexp = "^(SICK|TRAVEL|EMERGENCY|OTHER)$",
            message = "Type must be SICK, TRAVEL, EMERGENCY or OTHER")
    private String type;

    @NotBlank(message = "أرفق مستندًا داعمًا للعذر")
    @Size(max = 500, message = "Evidence URL must be 500 characters max")
    private String evidenceUrl;

    // any day of the week, before or after today
    @NotNull(message = "Excuse date is required")
    private LocalDate excuseDate;
}
