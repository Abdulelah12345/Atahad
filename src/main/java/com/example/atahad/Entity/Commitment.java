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

    @DecimalMin(value = "5.00", message = "Base amount must be at least 5")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal baseAmount; // Fixed amount per time for habits, 5 SAR minimum. Goals use the amount of each task

    @DecimalMin(value = "5.00", message = "Pending base amount must be at least 5")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal pendingBaseAmount; // New amount, applied when the next week starts

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean noHold = false;

    @Pattern(regexp = "^(DRAFT|ACTIVE|WITHDRAWN|ENDED)$", message = "Status must be DRAFT, ACTIVE, WITHDRAWN or ENDED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String status; // DRAFT until the first hold succeeds, then ACTIVE

    @Column(columnDefinition = "DATE")
    private LocalDate effectiveFrom; // Edits start from the next week

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitment")
    private Set<CommitmentWeek> weeks;
}
