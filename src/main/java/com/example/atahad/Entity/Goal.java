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

    @NotNull(message = "End date cannot be empty")
    @Column(columnDefinition = "DATE NOT NULL")
    private LocalDate endDate; // Long term goal end date
}
