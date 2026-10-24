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
    @Pattern(regexp = "^(LOCATION|PHOTO|QUIZ|TIMER)$", message = "Type must be LOCATION, PHOTO, QUIZ or TIMER")
    @Column(columnDefinition = "VARCHAR(8) NOT NULL")
    private String type;
//ممكن يحتوي رابط او موقع ، عشان بعدين نشيك عليه
    @NotBlank(message = "Evidence data cannot be empty")
    @Column(columnDefinition = "TEXT NOT NULL")
    private String evidenceData;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime submittedAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime activityTime; // When the activity happened (must be inside the same week, before Sat 23:59)

    @Pattern(regexp = "^(PENDING|ACCEPTED|REJECTED|ESCALATED)$", message = "Result must be PENDING, ACCEPTED, REJECTED or ESCALATED")
    @Column(columnDefinition = "VARCHAR(9)")
    private String result; // PENDING by default, ESCALATED = the AI was not sure, an admin decides

    // حالة معالجة الإثبات، مستقلة عن نتيجة القبول أو الرفض.
    @NotBlank(message = "Processing status cannot be empty")
    @Pattern(regexp = "^(WAITING|PROCESSING|FINISHED)$", message = "Invalid processing status")
    @Column(columnDefinition = "VARCHAR(10) NOT NULL")
    private String processingStatus;

    @Size(max = 500, message = "Rejection reason must be 500 characters max")
    @Column(columnDefinition = "VARCHAR(500)")
    private String rejectionReason;

    // وقت صدور قرار الذكاء، وتبدأ منه مهلة تقديم الاعتراض البالغة 48 ساعة.
    // يبقى فارغا عند الإضافة ويعبئه النظام عند إصدار القرار.
    @Column(columnDefinition = "DATETIME")
    private LocalDateTime decidedAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private CommitmentWeek commitmentWeek;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "proof")
    @JsonIgnore
    private Objection objection;


    // المهمة التي ينتمي إليها الإثبات.
// تكون فارغة عندما يكون الإثبات لعادة.
    @ManyToOne
    @JoinColumn(name = "goal_task_id")
    @JsonIgnore
    private GoalTask goalTask;
}