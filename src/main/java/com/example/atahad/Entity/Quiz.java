package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

// a short quiz made by the AI for a QUIZ commitment, the member answers it and sends the answers as the proof
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Quiz {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Size(max = 200, message = "Topic must be 200 characters max")
    @Column(columnDefinition = "VARCHAR(200)")
    private String topic;

    @Column(columnDefinition = "VARCHAR(3000)")
    private String questions; // the questions and their options, as the AI wrote them

    @JsonIgnore
    @Column(columnDefinition = "VARCHAR(10)")
    private String correctAnswers; // like BCA, never sent to the member

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime usedAt; // a quiz is used once

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
