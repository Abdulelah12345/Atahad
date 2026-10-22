package com.example.atahad.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// a moment is not a proof, it is only for sharing
@Data
@AllArgsConstructor
@NoArgsConstructor
public class MomentRequest {
    @NotEmpty(message = "Media cannot be empty")
    @Size(max = 500, message = "Media url must be 500 characters max")
    private String mediaUrl; // uploaded by the app to the storage first

    @NotEmpty(message = "Media type cannot be empty")
    @Pattern(regexp = "^(PHOTO|VIDEO)$", message = "Media type must be PHOTO or VIDEO")
    private String mediaType; // videos are 15 seconds max, checked by the app

    @Size(max = 200, message = "Caption must be 200 characters max")
    private String caption;

    @NotEmpty(message = "Visibility cannot be empty")
    @Pattern(regexp = "^(PRIVATE|GROUP)$", message = "Visibility must be PRIVATE or GROUP")
    private String visibility;

    private Integer groupId; // required when the visibility is GROUP

    private Integer commitmentWeekId; // optional, the week it belongs to
}
