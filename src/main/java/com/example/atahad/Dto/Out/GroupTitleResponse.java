package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupTitleResponse {
    private LocalDate weekStart;
    private String title;
    private Integer memberId;
    private String name;
}
