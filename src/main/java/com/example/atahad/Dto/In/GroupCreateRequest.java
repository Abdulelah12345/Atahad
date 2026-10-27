package com.example.atahad.Dto.In;

import jakarta.validation.constraints.*;
import lombok.*;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupCreateRequest {

    @NotEmpty(message = "Group name cannot be empty")
    @Size(max = 100, message = "Group name must be 100 characters max")
    private String name;

    @Size(max = 255, message = "Description must be 255 characters max")
    private String description;
    @Pattern(regexp = "^(SOLO|ALL)$", message = "Pay mode must be SOLO or ALL")
    private String payMode; // empty = SOLO
}