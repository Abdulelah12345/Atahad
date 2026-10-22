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
public class Admin {

    //Variables
    @Id
    private Integer id; // same id as the user (MapsId)

    @Size(max = 50, message = "Job title must be 50 characters max")
    @Column(columnDefinition = "VARCHAR(50)")
    private String jobTitle;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime lastLoginAt;

    @Min(value = 0, message = "Reviewed count must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer reviewedCount = 0;

    //Relations
    @OneToOne
    @MapsId
    @JsonIgnore
    private User user;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "admin")
    private Set<Objection> decidedObjections;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "admin")
    private Set<Excuse> reviewedExcuses;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "admin")
    private Set<GraceDay> grantedGraceDays;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "admin")
    private Set<DonationProof> reviewedDonationProofs;
}
