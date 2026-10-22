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
public class Habit extends Commitment {

    //Variables
    @NotNull(message = "Times per week cannot be empty")
    @Min(value = 1, message = "Times per week must be at least 1")
    @Max(value = 7, message = "Times per week must be at most 7")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer timesPerWeek;

    @Min(value = 1, message = "Pending times per week must be at least 1")
    @Max(value = 7, message = "Pending times per week must be at most 7")
    @Column(columnDefinition = "INTEGER")
    private Integer pendingTimesPerWeek; // New value, applied when the next week starts

    @ElementCollection
    private Set<@Pattern(regexp = "^(SUN|MON|TUE|WED|THU|FRI|SAT)$",
            message = "Planned day must be SUN, MON, TUE, WED, THU, FRI or SAT")
            String> plannedDays; // Only for reminders, never for deductions
}
