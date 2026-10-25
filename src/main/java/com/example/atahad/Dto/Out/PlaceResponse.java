package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one place from the Google search (or the place the member chose)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PlaceResponse {
    private String name;
    private String address;
    private Double latitude;
    private Double longitude;
}
