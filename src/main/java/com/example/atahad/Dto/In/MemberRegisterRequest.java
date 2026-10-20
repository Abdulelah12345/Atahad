package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one request creates the user and the member
@Data
@AllArgsConstructor
@NoArgsConstructor
public class MemberRegisterRequest {
    @NotEmpty(message = "Name cannot be empty")
    @Size(max = 50, message = "Name must be 50 characters max")
    private String name;

    @NotEmpty(message = "Email cannot be empty")
    @Email(message = "Email must be in a valid form")
    private String email;

    @NotEmpty(message = "Phone cannot be empty")
    @Pattern(regexp = "^\\+[1-9]\\d{7,14}$", message = "Phone must be in international format, e.g. +966501234567")
    private String phone;

    @NotEmpty(message = "Password cannot be empty")
    @Size(min = 8, message = "Password must be at least 8 characters")
    private String password;
}
