package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// A photo or a short video for memories, like Locket, it is not a proof
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Moment {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Media cannot be empty")
    @Column(columnDefinition = "VARCHAR(500) NOT NULL")
    private String mediaUrl;

    @NotEmpty(message = "Media type cannot be empty")
    @Pattern(regexp = "^(PHOTO|VIDEO)$", message = "Media type must be PHOTO or VIDEO")
    @Column(columnDefinition = "VARCHAR(5) NOT NULL")
    private String mediaType; // videos are 15 seconds max

    @Size(max = 200, message = "Caption must be 200 characters max")
    @Column(columnDefinition = "VARCHAR(200)")
    private String caption;

    @Pattern(regexp = "^(PRIVATE|GROUP)$", message = "Visibility must be PRIVATE or GROUP")
    @Column(columnDefinition = "VARCHAR(7)")
    private String visibility = "PRIVATE";

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Group group; // Null when it is private

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @OneToOne
    @JoinColumn
    @JsonIgnore
    private Proof proof; // Only when a photo proof is shared as a moment
}
