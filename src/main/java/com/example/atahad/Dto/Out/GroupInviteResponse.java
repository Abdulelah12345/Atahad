package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// the app draws the QR code from qrContent
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupInviteResponse {
    private String inviteCode;
    private String qrContent;
}
