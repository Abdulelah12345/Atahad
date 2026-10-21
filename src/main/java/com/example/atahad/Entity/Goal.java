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
public class Goal extends Commitment {

    //Variables
    @Size(max = 500, message = "Description must be 500 characters max")
    @Column(columnDefinition = "VARCHAR(500)")
    private String description;

    @NotNull(message = "Total weeks cannot be empty")
    @Min(value = 1, message = "Total weeks must be at least 1")
    @Max(value = 52, message = "Total weeks must be at most 52")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer totalWeeks; // Chosen by the user

    @Column(columnDefinition = "DATE")
    private LocalDate endDate; // Calculated in service from the start and total weeks

    //Relations
    @OneToMany(cascade = CascadeType.ALL, mappedBy = "goal")
    private Set<GoalTask> tasks; // Tasks of every week of the goal
}
