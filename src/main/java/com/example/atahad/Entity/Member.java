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

    @Pattern(regexp = "^(BEGINNER|COMMITTED|PERSEVERING|IRON)$", message = "Level must be BEGINNER, COMMITTED, PERSEVERING or IRON")
    @Column(columnDefinition = "VARCHAR(11)")
    private String level; // BEGINNER by default

    @Min(value = 0, message = "Consecutive weeks must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer consecutiveWeeks = 0;

    @Min(value = 0, message = "Points must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer points = 0; // 150 personal points = one grace day

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean isLocked = false; // true while the member has unpaid penalties

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean emailLinked = false; // Gmail linked to check bank emails

    @Email(message = "Linked email must be in a valid form")
    @Column(columnDefinition = "VARCHAR(100)")
    private String linkedEmail;

    // Google App Password, used to read bank emails from Gmail with IMAP
    @Column(columnDefinition = "VARCHAR(30)")
    @JsonIgnore
    private String gmailAppPassword;

    // Firebase token of the member phone, used for the push notifications (the group alert)
    @Column(columnDefinition = "VARCHAR(512)")
    @JsonIgnore
    private String deviceToken;

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean screenshotBanned = false; // a fake screenshot was found, email only from now

    @Min(value = 0, message = "Group refusal count must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer groupRefusalCount = 0; // times he refused to pay a group penalty

    @Column(columnDefinition = "DATE")
    private LocalDate groupBanUntil; // first refusal: banned from groups for a month

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean groupBannedForever = false; // second refusal

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean accountBanned = false; // third refusal

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
    @JsonIgnore
    private Set<Commitment> commitments;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    @JsonIgnore
    private Set<GraceDay> graceDays;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    @JsonIgnore
    private Set<Objection> objections;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    @JsonIgnore
    private Set<Penalty> penalties;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    @JsonIgnore
    private Set<DonationProof> donationProofs;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    @JsonIgnore
    private Set<PointLog> pointLogs;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    @JsonIgnore
    private Set<Moment> moments;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "member")
    @JsonIgnore
    private Set<MonthlyWrapped> monthlyWrappeds;
}
