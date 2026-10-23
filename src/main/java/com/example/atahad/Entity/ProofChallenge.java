package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

// a random challenge shown when the camera opens (say a number, raise a hand ...)
// the member does it in the clip, so an old video can not be used. One use, valid 10 minutes
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class ProofChallenge {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "VARCHAR(200) NOT NULL")
    private String text; // in Arabic, shown to the member

    @Column(columnDefinition = "DATETIME NOT NULL")
    private LocalDateTime createdAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime usedAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GoalTask goalTask; // null for habits
}
