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
public class Penalty {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull(message = "Amount cannot be empty")
    @PositiveOrZero(message = "Amount must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2) NOT NULL")
    private BigDecimal amount;

    @NotEmpty(message = "Method cannot be empty")
    @Pattern(regexp = "^(CAPTURE|PAYMENT_LINK)$", message = "Method must be CAPTURE or PAYMENT_LINK")
    @Column(columnDefinition = "VARCHAR(12) NOT NULL")
    private String method;

    @Column(columnDefinition = "VARCHAR(100)")
    private String paymentLinkId; // Only for PAYMENT_LINK

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime capturedAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime finalAt; // After the objection window closes

    @Pattern(regexp = "^(PENDING|CAPTURED|PAID|REFUNDED|CANCELLED)$", message = "Status must be PENDING, CAPTURED, PAID, REFUNDED or CANCELLED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String status;

    //Relations
    @OneToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private DonationBatch donationBatch;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "penalty")
    private Objection objection;
}
