package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// The weekly settlement of a group, it creates the group penalties
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GroupSettlement {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "DATE")
    private LocalDate weekStart;

    @Column(columnDefinition = "VARCHAR(2000)")
    private String settlementText; // written by the AI

    @Column(columnDefinition = "VARCHAR(500)")
    private String titles; // the titles of this week: TITLE=groupMemberId separated by ; like IRON=4;ROCKET=7

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GroupGoal groupGoal;

    @OneToMany(mappedBy = "groupSettlement")
    @JsonIgnore
    private Set<Penalty> penalties;
}
