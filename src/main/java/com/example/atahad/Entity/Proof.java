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
public class Proof {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Type cannot be empty")
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|TIMER|STEPS)$", message = "Invalid proof type")
    @Column(columnDefinition = "VARCHAR(8) NOT NULL")
    private String type;
// a link, a location or a capture id, checked later
    @NotBlank(message = "Evidence data cannot be empty")
    @Column(columnDefinition = "MEDIUMTEXT NOT NULL")
    private String evidenceData;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime submittedAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime activityTime; // When the activity happened (must be inside the same week, before Sat 23:59)

    @Pattern(regexp = "^(PENDING|ACCEPTED|REJECTED|ESCALATED)$", message = "Result must be PENDING, ACCEPTED, REJECTED or ESCALATED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String result; // PENDING by default, ESCALATED = the AI was not sure, an admin decides

    // WAITING / PROCESSING / DONE, separate from the result
    @NotBlank(message = "Processing status cannot be empty")
    @Pattern(regexp = "^(WAITING|PROCESSING|FINISHED)$", message = "Invalid processing status")
    @Column(columnDefinition = "VARCHAR(10) NOT NULL")
    private String processingStatus;

    @Size(max = 500, message = "Rejection reason must be 500 characters max")
    @Column(columnDefinition = "VARCHAR(500)")
    private String rejectionReason;

    // the 48 hours to object start here
    @Column(columnDefinition = "DATETIME")
    private LocalDateTime decidedAt;

    // new attempts: the main proof and the extra photos have their own results, one final decision
    private LocalDateTime attemptDeadline;
    private Boolean beforeAfterEnabled = false;
    private Boolean pageReuploadRequested = false;
    private Integer primaryCaptureId;
    @OneToMany(mappedBy="proof", cascade={CascadeType.PERSIST,CascadeType.MERGE,CascadeType.REMOVE}, orphanRemoval=true)
    private java.util.List<ProofEvidence> evidences = new java.util.ArrayList<>();

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @OneToOne(fetch = FetchType.LAZY, cascade = {CascadeType.PERSIST, CascadeType.MERGE, CascadeType.REMOVE}, mappedBy = "proof")
    @JsonIgnore
    private Objection objection;

// null for a habit
    @ManyToOne
    @JoinColumn(name = "goal_task_id")
    @JsonIgnore
    private GoalTask goalTask;
}
