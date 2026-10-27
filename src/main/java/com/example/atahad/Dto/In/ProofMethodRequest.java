package com.example.atahad.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// a new photo proof method from the admin
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ProofMethodRequest {
    @NotEmpty(message = "Name cannot be empty")
    @Size(max = 40, message = "Name must be 40 characters max")
    private String nameAr;

    @NotEmpty(message = "Write what the photo must show")
    @Size(max = 300, message = "Hint must be 300 characters max")
    private String hint;
}
