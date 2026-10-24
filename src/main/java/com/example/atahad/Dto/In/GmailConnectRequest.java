package com.example.atahad.Dto.In;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

// the Gmail to read the bank emails from, and its App Password (16 letters from the Google account)
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class GmailConnectRequest {

    @NotEmpty(message = "Gmail address cannot be empty")
    @Email(message = "Gmail address must be in a valid form")
    @Size(max = 100, message = "Gmail address must be 100 characters max")
    private String gmailAddress;

    @NotEmpty(message = "App Password cannot be empty")
    @Size(max = 30, message = "App Password must be 30 characters max")
    private String appPassword;
}
