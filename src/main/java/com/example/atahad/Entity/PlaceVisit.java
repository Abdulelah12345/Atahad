package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

// one visit to the place of a LOCATION commitment (the gym ...): the phone sends the entry and the exit by itself (geofencing)
// when it is closed the app makes the proof by itself: accepted with half of the minutes or more
// a visit with no exit (the phone was off) is closed by itself after 4 hours (or 23:50 of the same day) and counted
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class PlaceVisit {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "DATETIME NOT NULL")
    private LocalDateTime enteredAt; // server time

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime exitedAt;

    @Column(columnDefinition = "INT")
    private Integer minutes;

    @Pattern(regexp = "^(OPEN|CLOSED|AUTO_CLOSED)$", message = "Status must be OPEN, CLOSED or AUTO_CLOSED")
    @Column(columnDefinition = "VARCHAR(11) NOT NULL")
    private String status; // AUTO_CLOSED = no exit came from the phone

    @Column(columnDefinition = "INT")
    private Integer proofId; // the proof made from this visit

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime usedAt; // a visit makes one proof only

    @Column(columnDefinition = "VARCHAR(255)")
    private String note; // why no proof was made (locked, the day already has a proof ...)

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Commitment commitment;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GoalTask goalTask; // null for habits
}
