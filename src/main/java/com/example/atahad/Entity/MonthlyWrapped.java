package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// The monthly summary card, like Spotify Wrapped
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class MonthlyWrapped {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Month cannot be empty")
    @Pattern(regexp = "^20\\d{2}-(0[1-9]|1[0-2])$", message = "Month must be like 2026-10")
    @Column(columnDefinition = "VARCHAR(7) NOT NULL")
    private String month;

    @Column(columnDefinition = "VARCHAR(2000)")
    private String summary; // written by the AI

    @Column(columnDefinition = "VARCHAR(500)")
    private String cardImageUrl;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;
}
