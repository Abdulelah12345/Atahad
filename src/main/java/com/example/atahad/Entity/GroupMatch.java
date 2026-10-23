package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// An optional competition between two groups with similar goals
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GroupMatch {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Pattern(regexp = "^(PENDING|ACTIVE|FINISHED|DECLINED)$", message = "Status must be PENDING, ACTIVE, FINISHED or DECLINED")
    @Column(columnDefinition = "VARCHAR(8)")
    private String status = "PENDING";

    @Column(columnDefinition = "DATE")
    private LocalDate startDate;

    @Column(columnDefinition = "DATE")
    private LocalDate endDate;

    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer challengerScore = 0;

    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer opponentScore = 0;

    //Relations
    @ManyToOne
    @JoinColumn(name = "challenger_id")
    @JsonIgnore
    private Group challenger;

    @ManyToOne
    @JoinColumn(name = "opponent_id")
    @JsonIgnore
    private Group opponent;

    @ManyToOne
    @JoinColumn(name = "winner_id")
    @JsonIgnore
    private Group winner; // Null until it finishes, or when it is a draw

    @ManyToOne
    @JoinColumn(name = "least_procrastinating_id")
    @JsonIgnore
    private Group leastProcrastinating;

    @ManyToOne
    @JoinColumn(name = "challenger_goal_id")
    @JsonIgnore
    private GroupGoal challengerGoal;

    @ManyToOne
    @JoinColumn(name = "opponent_goal_id")
    @JsonIgnore
    private GroupGoal opponentGoal;
}
