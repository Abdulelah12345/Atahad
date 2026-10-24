package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// A goal of the group: PROPOSED (suggested by the AI or a member, the members vote), then the owner confirms one = ACTIVE,
// every member gets a commitment on it, and at the end ENDED. The other proposals become REJECTED
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GroupGoal {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 100, message = "Title must be 100 characters max")
    @Column(columnDefinition = "VARCHAR(100) NOT NULL")
    private String title;

    @Size(max = 500, message = "Details must be 500 characters max")
    @Column(columnDefinition = "VARCHAR(500)")
    private String details; // the idea of a proposal

    @Pattern(regexp = "^(AI|MEMBER)$", message = "Suggested by must be AI or MEMBER")
    @Column(columnDefinition = "VARCHAR(6)")
    private String suggestedBy; // proposals only

    // the next 4 are empty while it is a proposal, the owner sets them when he confirms it (GroupGoalRequest checks them)
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|TIMER)$", message = "Proof method must be LOCATION, PHOTO, QUIZ or TIMER")
    @Column(columnDefinition = "VARCHAR(8)")
    private String proofMethod;

    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    @Column(columnDefinition = "INTEGER")
    private Integer timesPerWeek;

    @DecimalMin(value = "5.00", message = "Amount per time must be at least 5")
    @Column(columnDefinition = "DECIMAL(10,2)")
    private BigDecimal amountPerTime;

    @Min(value = 1, message = "Total weeks must be at least 1")
    @Max(value = 52, message = "Total weeks must be at most 52")
    @Column(columnDefinition = "INTEGER")
    private Integer totalWeeks;

    @Min(value = 1, message = "Minutes must be at least 1")
    @Max(value = 600, message = "Minutes must be at most 600")
    @Column(columnDefinition = "INTEGER")
    private Integer targetMinutes; // TIMER only, the place of LOCATION is set by every member for himself

    @Column(columnDefinition = "DATE")
    private LocalDate startDate;

    @Column(columnDefinition = "DATE")
    private LocalDate endDate;

    @Pattern(regexp = "^(PROPOSED|REJECTED|ACTIVE|ENDED)$", message = "Status must be PROPOSED, REJECTED, ACTIVE or ENDED")
    @Column(columnDefinition = "VARCHAR(8)")
    private String status = "ACTIVE";

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Group group;

    @OneToMany(mappedBy = "groupGoal")
    @JsonIgnore
    private Set<Commitment> commitments; // one for every member

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "groupGoal")
    @JsonIgnore
    private Set<GroupSettlement> settlements;
}
