package com.example.atahad.Entity;

import jakarta.persistence.*;
import lombok.*;

// a proof method the admin controls: the built-in ones can be turned off,
// and a custom one is a photo proof with its own rule for the AI ("the photo shows the book page")
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
    private String code; // PHOTO, TIMER, QUIZ, LOCATION, STEPS or CUSTOM_<id>

    @Column(columnDefinition = "VARCHAR(40) NOT NULL")
    private String nameAr;

    @Column(columnDefinition = "VARCHAR(300)")
    private String hint; // custom only: what the photo must show

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean builtIn = false;

    @Column(columnDefinition = "BOOLEAN DEFAULT true")
    private Boolean enabled = true;
}
