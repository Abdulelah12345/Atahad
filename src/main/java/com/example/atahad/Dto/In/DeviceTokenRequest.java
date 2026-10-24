package com.example.atahad.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

// the Firebase token the phone gets from firebase_messaging
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class DeviceTokenRequest {

    @NotEmpty(message = "Device token cannot be empty")
    @Size(max = 512, message = "Device token must be 512 characters max")
    private String token;
}
