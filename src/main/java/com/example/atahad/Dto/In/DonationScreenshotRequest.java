package com.example.atahad.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// the two screenshots are uploaded by the app to the storage first, here only the links
@Data
@AllArgsConstructor
@NoArgsConstructor
public class DonationScreenshotRequest {
    @NotEmpty(message = "The bank message image is required")
    @Size(max = 500, message = "Image url must be 500 characters max")
    private String bankMessageImageUrl;

    @NotEmpty(message = "The Ehsan message image is required")
    @Size(max = 500, message = "Image url must be 500 characters max")
    private String ehsanMessageImageUrl;
}
