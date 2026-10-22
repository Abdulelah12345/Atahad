package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Member {

    //Variables
    @Id
    private Integer id; // same id as the user (MapsId)

//    @Pattern(regexp = "^(FREE_TRIAL|MONTHLY|FREE)$", message = "Plan must be FREE_TRIAL, MONTHLY or FREE")
//    @Column(columnDefinition = "VARCHAR(10)")
//    private String plan; // FREE_TRIAL by default

//    @Column(columnDefinition = "DATE")
//    private LocalDate trialEndsAt;

    @Column(columnDefinition = "DATE")
    private LocalDate renewsAt;

    @Column(columnDefinition = "VARCHAR(255)")
    private String moyasarToken; // Card token from Moyasar, never the card number

    @Pattern(regexp = "^(MADA|VISA|MASTERCARD)$", message = "Card type must be MADA, VISA or MASTERCARD")
    @Column(columnDefinition = "VARCHAR(10)")
    private String cardType;

    @Pattern(regexp = "^(BEGINNER|COMMITTED|PERSEVERING|IRON)$", message = "Level must be BEGINNER, COMMITTED, PERSEVERING or IRON")
    @Column(columnDefinition = "VARCHAR(11)")
    private String level; // BEGINNER by default

    @Min(value = 0, message = "Consecutive weeks must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer consecutiveWeeks = 0;

    @Min(value = 0, message = "Task points must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer taskPoints = 0;

    @Column(columnDefinition = "BOOLEAN DEFAULT true")
    private Boolean canCreateCommitment = true;

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean hasNoHoldPrivilege = false;

    @Column(columnDefinition = "VARCHAR(25)")
    private String accountStatus = "ACTIVE";

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime deactivationRequestedAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime deactivatedAt;

    //Relations
    @OneToOne
    @MapsId
    @JsonIgnore
    private User user;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    private Set<Commitment> commitments;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    private Set<GraceDay> graceDays;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    private Set<Objection> objections;
}
