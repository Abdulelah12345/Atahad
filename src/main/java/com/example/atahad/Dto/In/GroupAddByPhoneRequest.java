package com.example.atahad.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

// the owner adds a friend by his phone number: +966501234567, 966501234567, 0501234567 or 501234567
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class GroupAddByPhoneRequest {

    @NotEmpty(message = "Phone cannot be empty")
    @Size(max = 20, message = "Phone must be 20 characters max")
    private String phone;
}
