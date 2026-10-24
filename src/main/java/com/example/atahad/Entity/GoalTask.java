package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.Set;

// One task of a goal in one week, the user sets its times and amount
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GoalTask {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull(message = "Week number cannot be empty")
    @Min(value = 1, message = "Week number must be at least 1")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer weekNumber;

    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 100, message = "Title must be 100 characters max")
    @Column(columnDefinition = "VARCHAR(100) NOT NULL")
    private String title;

    @NotNull(message = "Times per week cannot be empty")
    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer timesPerWeek;

    @NotNull(message = "Amount per time cannot be empty")
    @DecimalMin(value = "5.00", message = "Amount per time must be at least 5")
    @Column(columnDefinition = "DECIMAL(10,2) NOT NULL")
    private BigDecimal amountPerTime;

    @Min(value = 0, message = "Completed count must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer completedCount = 0;

    @Min(value = 0, message = "Excused count must be at least 0")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer excusedCount = 0;

    @Pattern(regexp = "^(SAFE|MUST_TODAY|LOST_DAY|SETTLED)$", message = "Track status must be SAFE, MUST_TODAY, LOST_DAY or SETTLED")
    @Column(columnDefinition = "VARCHAR(10)")
    private String trackStatus;

    @ElementCollection
    private Set<@Pattern(regexp = "^(SUN|MON|TUE|WED|THU|FRI|SAT)$",
            message = "Planned day must be SUN, MON, TUE, WED, THU, FRI or SAT")
            String> plannedDays; // Only for reminders, never for deductions

///////////////احتاجها في البروف
    @NotBlank(message = "Proof method cannot be empty")
    @Pattern(
            regexp = "^(LOCATION|PHOTO|QUIZ|TIMER)$",
            message = "Proof method must be LOCATION, PHOTO, QUIZ or TIMER"
    )
    @Column(columnDefinition = "VARCHAR(8) NOT NULL")
    private String proofMethod;






    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Goal goal;
}