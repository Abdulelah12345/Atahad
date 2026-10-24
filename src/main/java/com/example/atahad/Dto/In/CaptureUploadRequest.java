package com.example.atahad.Dto.In;
@lombok.Data
public class CaptureUploadRequest {
    @jakarta.validation.constraints.NotBlank private String token;
    @jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Size(max=3000000) private String imageData;
}
