package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// The one goal a group is working on, every member gets a commitment on it
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GroupGoal {

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

    @NotNull(message = "Times per week cannot be empty")
    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer timesPerWeek;

    @NotNull(message = "Amount per time cannot be empty")
    @DecimalMin(value = "5.00", message = "Amount per time must be at least 5")
    @Column(columnDefinition = "DECIMAL(10,2) NOT NULL")
    private BigDecimal amountPerTime;

    @NotNull(message = "Total weeks cannot be empty")
    @Min(value = 1, message = "Total weeks must be at least 1")
    @Max(value = 52, message = "Total weeks must be at most 52")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer totalWeeks;

    @Min(value = 1, message = "Minutes must be at least 1")
    @Max(value = 600, message = "Minutes must be at most 600")
    @Column(columnDefinition = "INTEGER")
    private Integer targetMinutes; // TIMER only, the place of LOCATION is set by every member for himself

    @Column(columnDefinition = "DATE")
    private LocalDate startDate;

    @Column(columnDefinition = "DATE")
    private LocalDate endDate;

    @Pattern(regexp = "^(ACTIVE|ENDED)$", message = "Status must be ACTIVE or ENDED")
    @Column(columnDefinition = "VARCHAR(6)")
    private String status = "ACTIVE";

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Group group;

    @OneToMany(mappedBy = "groupGoal")
    @JsonIgnore
    private Set<Commitment> commitments; // one for every member

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "groupGoal")
    private Set<GroupSettlement> settlements;
}
