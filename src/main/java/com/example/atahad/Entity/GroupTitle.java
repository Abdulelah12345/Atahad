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
public class GroupTitle {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "DATE")
    private LocalDate weekStart;

    @NotEmpty(message = "Title cannot be empty")
    @Pattern(regexp = "^(IRON|TOP_DONOR|ROCKET|OWL|ALARMIST|COMEBACK|EXCUSE_KING)$", message = "Title must be IRON, TOP_DONOR, ROCKET, OWL, ALARMIST, COMEBACK or EXCUSE_KING")
    @Column(columnDefinition = "VARCHAR(11) NOT NULL")
    private String title;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Group group;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GroupMember groupMember;
}
