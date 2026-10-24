package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// shown on the camera screen, the proof is "challengeId:the link of the clip"
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ProofChallengeResponse {
    private Integer challengeId;
    private String challenge;
    private Integer validMinutes;
    private String howToSend;
}
