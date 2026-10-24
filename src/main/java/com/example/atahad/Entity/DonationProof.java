package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// Proof that the member donated to Ehsan, from his bank email or a screenshot
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class DonationProof {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Method cannot be empty")
    @Pattern(regexp = "^(EMAIL|SCREENSHOT)$", message = "Method must be EMAIL or SCREENSHOT")
    @Column(columnDefinition = "VARCHAR(10) NOT NULL")
    private String method;

    @Column(columnDefinition = "VARCHAR(50)")
    private String bankName;

    @PositiveOrZero(message = "Amount must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal amount; // read by the AI

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime transactionTime;

    @Column(columnDefinition = "VARCHAR(100) UNIQUE")
    private String transactionReference; // never accepted twice

    @Column(columnDefinition = "VARCHAR(100)")
    private String recipient; // must be Ehsan

    @Column(columnDefinition = "VARCHAR(100)")
    private String dkimDomain; // EMAIL only, the bank domain that signed the email

    @Column(columnDefinition = "VARCHAR(500)")
    private String bankMessageImageUrl; // SCREENSHOT only

    @Column(columnDefinition = "VARCHAR(500)")
    private String ehsanMessageImageUrl; // SCREENSHOT only

    @Column(columnDefinition = "VARCHAR(1000)")
    private String aiResult;

    @Pattern(regexp = "^(PENDING|ACCEPTED|REJECTED|ESCALATED)$", message = "Status must be PENDING, ACCEPTED, REJECTED or ESCALATED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String status = "PENDING";

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Admin admin; // Null unless it was escalated

    @OneToMany(mappedBy = "donationProof")
    @JsonIgnore
    private Set<Penalty> penalties; // one donation can pay many penalties

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "donationProof")
    @JsonIgnore
    private Objection objection;
}
