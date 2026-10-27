
package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class LearnResourceDTO {

    private String title;
    private String type;
    private String creator;
    private String description;
    private String imageUrl;
    private String source;
    private String url;
}
