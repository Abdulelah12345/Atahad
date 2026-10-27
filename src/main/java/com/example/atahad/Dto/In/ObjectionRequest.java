package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.Data;

// an objection on a proof or an excuse, the member sends the reason only
@Data
public class ObjectionRequest {

    @NotBlank(message = "Reason cannot be empty")
    @Size(max = 1000, message = "Reason must be 1000 characters max")
    private String reason;
}
