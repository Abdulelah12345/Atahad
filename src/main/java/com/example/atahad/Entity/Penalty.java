package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

// A donation the member owes, the app is locked until it is paid to Ehsan
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

    @NotEmpty(message = "Reason cannot be empty")
    @Pattern(regexp = "^(LOST_DAY|WITHDRAWAL|GROUP_COLLECTIVE|GROUP_EXTRA)$", message = "Reason must be LOST_DAY, WITHDRAWAL, GROUP_COLLECTIVE or GROUP_EXTRA")
    @Column(columnDefinition = "VARCHAR(16) NOT NULL")
    private String reason;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    @Pattern(regexp = "^(PENDING|PAID|CANCELLED)$", message = "Status must be PENDING, PAID or CANCELLED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String status = "PENDING";

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime paidAt;

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean refusalCounted = false; // a group penalty not paid in 7 days, counted once in the refusal ladder

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GoalTask goalTask; // Only for goals

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private DonationProof donationProof; // The donation that paid it

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GroupSettlement groupSettlement; // Only for group penalties
}
