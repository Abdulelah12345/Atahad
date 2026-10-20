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
public class CommitmentWeek {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Min(value = 1, message = "Week number must be at least 1")
    @Column(columnDefinition = "INTEGER")
    private Integer weekNumber;

    @Column(columnDefinition = "DATE")
    private LocalDate weekStart;

    @Column(columnDefinition = "DATE")
    private LocalDate weekEnd;

    @Size(max = 255, message = "Weekly target must be 255 characters max")
    @Column(columnDefinition = "VARCHAR(255)")
    private String weeklyTarget; // What is needed this week, mostly for goals

    @Min(value = 0, message = "Required must be at least 0")
    @Column(columnDefinition = "INTEGER")
    private Integer required;

    @Min(value = 0, message = "Completed must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer completed = 0;

    @Min(value = 0, message = "Excused days must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer excusedDays = 0;

    @PositiveOrZero(message = "Amount per day must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal amountPerDay; // Copied from the commitment when the week starts

    @Min(value = 0, message = "Extended days must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer extendedDays = 0;

    @Pattern(regexp = "^(SAFE|MUST_TODAY|LOST_DAY|SETTLED)$", message = "Track status must be SAFE, MUST_TODAY, LOST_DAY or SETTLED")
    @Column(columnDefinition = "VARCHAR(10)")
    private String trackStatus;

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean isFullWeek = false;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Commitment commitment;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    private PaymentHold paymentHold;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    private Set<Proof> proofs;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    private Set<Excuse> excuses;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    private Penalty penalty;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    private GraceDay graceDay; // Null if no grace day was used
}
