package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// Every time points are added or used, for a member or for a group
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class PointLog {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull(message = "Points cannot be empty")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer points; // negative when a grace day is redeemed

    @NotEmpty(message = "Reason cannot be empty")
    @Pattern(regexp = "^(TASK_DONE|FULL_WEEK|GOLDEN_WEEK|MATCH_ALL_DONE|MATCH_WIN|LEAST_PROCRASTINATION|GRACE_DAY_REDEEMED|LUCKY_CHALLENGE)$", message = "Reason is not valid")
    @Column(columnDefinition = "VARCHAR(21) NOT NULL")
    private String reason;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member; // Null for group points

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Group group; // Null for personal points
}
