package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// Parent of Habit and Goal, never created by itself
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
@Inheritance(strategy = InheritanceType.JOINED)
public abstract class Commitment {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 100, message = "Title must be 100 characters max")
    @Column(columnDefinition = "VARCHAR(100) NOT NULL")
    private String title;

    @NotEmpty(message = "Proof method cannot be empty")
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|PLATFORM|TIMER)$", message = "Proof method must be LOCATION, PHOTO, QUIZ, PLATFORM or TIMER")
    @Column(columnDefinition = "VARCHAR(8) NOT NULL")
    private String proofMethod;

    @NotEmpty(message = "Amount type cannot be empty")
    @Pattern(regexp = "^(FIXED|ESCALATING)$", message = "Amount type must be FIXED or ESCALATING")
    @Column(columnDefinition = "VARCHAR(10) NOT NULL")
    private String amountType;

    @NotNull(message = "Base amount cannot be empty")
    @DecimalMin(value = "5.00", message = "Base amount must be at least 5")
    @Column(columnDefinition = "DECIMAL(10,2) NOT NULL")
    private BigDecimal baseAmount; // Amount per day, 5 SAR minimum

    @PositiveOrZero(message = "Current amount must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal currentAmount; // Changes with escalation

    @PositiveOrZero(message = "Escalation step must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal escalationStep; // Only for ESCALATING

    @PositiveOrZero(message = "Escalation cap must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal escalationCap; // Only for ESCALATING

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean noHold = false;

    @Pattern(regexp = "^(ACTIVE|PAUSED|WITHDRAWN|ENDED)$", message = "Status must be ACTIVE, PAUSED, WITHDRAWN or ENDED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String status; // ACTIVE by default

    @Column(columnDefinition = "DATE")
    private LocalDate effectiveFrom; // Edits and withdrawals start from the next week

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitment")
    private Set<CommitmentWeek> weeks;
}
