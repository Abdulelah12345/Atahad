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
public class PaymentHold {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "VARCHAR(100)")
    private String moyasarId; // Payment id from Moyasar

    @NotNull(message = "Amount cannot be empty")
    @PositiveOrZero(message = "Amount must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2) NOT NULL")
    private BigDecimal amount;

    @Pattern(regexp = "^(AUTHORIZED|CAPTURED|VOIDED|FAILED|EXPIRED)$", message = "Status must be AUTHORIZED, CAPTURED, VOIDED, FAILED or EXPIRED")
    @Column(columnDefinition = "VARCHAR(10)")
    private String status;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime expiresAt; // About 7 days after the hold

    //Relations
    @OneToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;
}
