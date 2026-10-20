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
public class GraceDay {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Source cannot be empty")
    @Pattern(regexp = "^(EARNED|ADMIN_GRANTED)$", message = "Source must be EARNED or ADMIN_GRANTED")
    @Column(columnDefinition = "VARCHAR(13) NOT NULL")
    private String source;

    @Size(max = 255, message = "Grant reason must be 255 characters max")
    @Column(columnDefinition = "VARCHAR(255)")
    private String grantReason; // Only when an admin grants it

    @Column(columnDefinition = "DATE")
    private LocalDate earnedAt;

    @Column(columnDefinition = "DATE")
    private LocalDate expiresAt; // 4 weeks after earning

    @Column(columnDefinition = "DATE")
    private LocalDate usedAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Admin admin; // Null when earned

    @OneToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek; // The week it was used in
}
