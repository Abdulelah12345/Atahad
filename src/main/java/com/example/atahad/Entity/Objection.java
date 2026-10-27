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
public class Objection {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Size(max = 1000, message = "AI reason must be 1000 characters max")
    @Column(columnDefinition = "VARCHAR(1000)")
    private String aiReason;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt; // Must be within 48 hours of the decision

    @Pattern(regexp = "^(PENDING|ACCEPTED|REJECTED)$", message = "Status must be PENDING, ACCEPTED or REJECTED")
    @Column(columnDefinition = "VARCHAR(8)")
    private String status; // PENDING by default

    // once the admin starts, the member can't edit it
    @Column(columnDefinition = "DATETIME")
    private LocalDateTime reviewStartedAt;

    @NotBlank(message = "Reason cannot be empty")
    @Size(max = 1000, message = "Reason must be 1000 characters max")
    @Column(columnDefinition = "VARCHAR(1000) NOT NULL")
    private String reason;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Admin admin; // The admin who decided

    @OneToOne
    @JoinColumn
    @JsonIgnore
    private Proof proof; // One of proof, excuse or donation proof

    @OneToOne
    @JoinColumn
    @JsonIgnore
    private Excuse excuse;

    @OneToOne
    @JoinColumn
    @JsonIgnore
    private DonationProof donationProof; // A rejected donation proof

}