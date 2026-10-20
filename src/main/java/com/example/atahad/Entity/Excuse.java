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
public class Excuse {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Type cannot be empty")
    @Pattern(regexp = "^(SICK|TRAVEL|EMERGENCY|OTHER)$", message = "Type must be SICK, TRAVEL, EMERGENCY or OTHER")
    @Column(columnDefinition = "VARCHAR(9) NOT NULL")
    private String type;

    @Column(columnDefinition = "VARCHAR(500)")
    private String evidenceUrl;

    @NotNull(message = "Excuse date cannot be empty")
    @Column(columnDefinition = "DATE NOT NULL")
    private LocalDate excuseDate;

    @Size(max = 1000, message = "AI assessment must be 1000 characters max")
    @Column(columnDefinition = "VARCHAR(1000)")
    private String aiAssessment;

    @Pattern(regexp = "^(PENDING|ACCEPTED|REJECTED|ESCALATED)$", message = "Status must be PENDING, ACCEPTED, REJECTED or ESCALATED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String status; // PENDING by default

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean forwardedToAdmin = false;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Admin admin; // Null unless it was escalated

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "excuse")
    private Objection objection;
}
