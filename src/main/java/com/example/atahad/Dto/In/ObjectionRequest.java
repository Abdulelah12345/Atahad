package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.Data;

// بيانات إضافة أو تعديل اعتراض على بروف أو عذر؛ المستخدم يرسل السبب فقط.
@Data
public class ObjectionRequest {

    @NotBlank(message = "Reason cannot be empty")
    @Size(max = 1000, message = "Reason must be 1000 characters max")
    private String reason;
}
