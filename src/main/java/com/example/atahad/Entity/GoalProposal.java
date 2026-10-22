package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// A suggested next goal for the group, from the AI or a member
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GoalProposal {

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
    private String details;

    @Pattern(regexp = "^(AI|MEMBER)$", message = "Suggested by must be AI or MEMBER")
    @Column(columnDefinition = "VARCHAR(6)")
    private String suggestedBy;

    @Pattern(regexp = "^(OPEN|CHOSEN|REJECTED)$", message = "Status must be OPEN, CHOSEN or REJECTED")
    @Column(columnDefinition = "VARCHAR(8)")
    private String status = "OPEN";

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Group group;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "goalProposal")
    private Set<GoalVote> votes;
}
