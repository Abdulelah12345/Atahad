package com.example.atahad.Entity;

import jakarta.persistence.*;
import lombok.*;

// a proof method the admin can turn off (new commitments can't pick it)
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class ProofMethodOption {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "VARCHAR(20) NOT NULL UNIQUE")
    private String code; // PHOTO, TIMER, QUIZ, LOCATION or STEPS

    @Column(columnDefinition = "VARCHAR(40) NOT NULL")
    private String nameAr;

    @Column(columnDefinition = "BOOLEAN DEFAULT true")
    private Boolean enabled = true;
}
