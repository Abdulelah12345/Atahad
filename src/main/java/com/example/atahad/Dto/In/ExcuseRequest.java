package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.time.LocalDate;

// بيانات إضافة أو تعديل العذر؛ حقول النظام لا يستقبلها المستخدم.
@Data
public class ExcuseRequest {

    @NotBlank(message = "Type cannot be empty")
    @Pattern(regexp = "^(SICK|TRAVEL|EMERGENCY|OTHER)$",
            message = "Type must be SICK, TRAVEL, EMERGENCY or OTHER")
    private String type;

    // المستند إلزامي قبل تقديم العذر للتقييم.
    @NotBlank(message = "أرفقي مستندًا داعمًا للعذر")
    @Size(max = 500, message = "Evidence URL must be 500 characters max")
    private String evidenceUrl;

    // يجوز أن يكون التاريخ سابقا أو لاحقا، بشرط انتمائه للأسبوع.
    @NotNull(message = "Excuse date is required")
    private LocalDate excuseDate;
}
