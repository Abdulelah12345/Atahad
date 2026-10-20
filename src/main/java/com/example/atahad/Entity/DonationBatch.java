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
public class DonationBatch {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Month cannot be empty")
    @Pattern(regexp = "^20\\d{2}-(0[1-9]|1[0-2])$", message = "Month must be like 2026-10")
    @Column(columnDefinition = "VARCHAR(7) NOT NULL UNIQUE")
    private String month;

    @PositiveOrZero(message = "Penalties total must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal penaltiesTotal;

    @PositiveOrZero(message = "Level donations total must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal levelDonationsTotal;

    @Column(columnDefinition = "VARCHAR(255)")
    private String ehsanReceipt;

    //Relations
    @OneToMany(cascade = CascadeType.ALL, mappedBy = "donationBatch")
    private Set<Penalty> penalties;
}
