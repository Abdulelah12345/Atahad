package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

// one item in the admin list: a proof, an excuse, an objection or a donation proof the AI was not sure about
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ReviewItemResponse {
    private String kind; // PROOF, EXCUSE, OBJECTION, DONATION
    private Integer id;
    private Integer memberId;
    private String memberName;
    private String about; // the commitment, or the amount of the donation
    private String details;
    private List<String> evidence; // image links or data
    private String aiNote;
    private LocalDateTime createdAt;
}
