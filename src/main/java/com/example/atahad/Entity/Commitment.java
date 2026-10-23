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

    @Pattern(regexp = "^(ACTIVE|WITHDRAWN|ENDED)$", message = "Status must be ACTIVE, WITHDRAWN or ENDED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String status; // ACTIVE from the moment it is created

    @Column(columnDefinition = "DATE")
    private LocalDate effectiveFrom; // Edits start from the next week

    // LOCATION only: the place of the commitment (the gym, the mosque ...), a proof counts inside the radius
    @DecimalMin(value = "-90.0", message = "Latitude must be between -90 and 90")
    @DecimalMax(value = "90.0", message = "Latitude must be between -90 and 90")
    @Column(columnDefinition = "DOUBLE")
    private Double targetLatitude;

    @DecimalMin(value = "-180.0", message = "Longitude must be between -180 and 180")
    @DecimalMax(value = "180.0", message = "Longitude must be between -180 and 180")
    @Column(columnDefinition = "DOUBLE")
    private Double targetLongitude;

    @Min(value = 50, message = "Radius must be at least 50 meters")
    @Max(value = 2000, message = "Radius must be at most 2000 meters")
    @Column(columnDefinition = "INTEGER")
    private Integer targetRadiusMeters; // 150 meters when it is empty

    @Size(max = 100, message = "Place name must be 100 characters max")
    @Column(columnDefinition = "VARCHAR(100)")
    private String targetPlaceName;

    // TIMER only: the minutes of one time
    @Min(value = 1, message = "Minutes must be at least 1")
    @Max(value = 600, message = "Minutes must be at most 600")
    @Column(columnDefinition = "INTEGER")
    private Integer targetMinutes;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitment")
    private Set<CommitmentWeek> weeks;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GroupGoal groupGoal; // Null for a personal commitment
}
