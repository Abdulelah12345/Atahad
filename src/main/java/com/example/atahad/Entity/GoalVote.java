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
public class GoalVote {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime votedAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GoalProposal goalProposal;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GroupMember groupMember;
}
