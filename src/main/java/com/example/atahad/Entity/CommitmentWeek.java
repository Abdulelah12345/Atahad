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
public class CommitmentWeek {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Min(value = 1, message = "Week number must be at least 1")
    @Column(columnDefinition = "INTEGER")
    private Integer weekNumber;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime weekStart; // Sunday 00:00:00

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime weekEnd; // Saturday 23:59:59

    @Min(value = 0, message = "Required must be at least 0")
    @Column(columnDefinition = "INTEGER")
    private Integer required;

    @Min(value = 0, message = "Completed must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer completed = 0;

    @Min(value = 0, message = "Excused days must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer excusedDays = 0;

    @PositiveOrZero(message = "Amount per day must be zero or more")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal amountPerDay; // Habits only, copied from the commitment when the week starts

    @Pattern(regexp = "^(SAFE|MUST_TODAY|LOST_DAY|SETTLED)$", message = "Track status must be SAFE, MUST_TODAY, LOST_DAY or SETTLED")
    @Column(columnDefinition = "VARCHAR(10)")
    private String trackStatus;

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean isFullWeek = false;

    // Step weeks remain open for delayed daily totals until Monday 00:00 Riyadh.
    private Boolean stepsSettlementPending = false;

    @ElementCollection
    private Set<@Pattern(regexp = "^(SUN|MON|TUE|WED|THU|FRI|SAT)$",
            message = "Planned day must be SUN, MON, TUE, WED, THU, FRI or SAT")
            String> plannedDays; // This week plan, postponing changes it without touching the habit default

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Commitment commitment;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    @JsonIgnore
    private Set<Proof> proofs;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    @JsonIgnore
    private Set<Excuse> excuses;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    @JsonIgnore
    private Set<Penalty> penalties; // One for every lost time

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    @JsonIgnore
    private GraceDay graceDay; // Null if no grace day was used

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "commitmentWeek")
    @JsonIgnore
    private Set<Moment> moments;
}
