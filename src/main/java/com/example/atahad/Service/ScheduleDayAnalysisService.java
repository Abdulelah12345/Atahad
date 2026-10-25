
package com.example.atahad.Service;

import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Proof;
import org.springframework.stereotype.Service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class ScheduleDayAnalysisService {

    public List<String> getBestDays(List<CommitmentWeek> previousWeeks) {

        Map<String, Integer> plannedCount = new HashMap<>();
        Map<String, Integer> completedCount = new HashMap<>();

        for (CommitmentWeek week : previousWeeks) {

            if (week.getPlannedDays() == null ||
                    week.getPlannedDays().isEmpty()) {
                continue;
            }

            if (week.getWeekEnd() == null ||
                    !week.getWeekEnd().toLocalDate().isBefore(LocalDate.now())) {
                continue;
            }

            Set<String> completedDays = new HashSet<>();

            if (week.getProofs() != null) {
                for (Proof proof : week.getProofs()) {

                    if (!"ACCEPTED".equals(proof.getResult()) ||
                            proof.getActivityTime() == null) {
                        continue;
                    }

                    LocalDate activityDate =
                            proof.getActivityTime().toLocalDate();

                    if (week.getWeekStart() == null ||
                            activityDate.isBefore(week.getWeekStart().toLocalDate()) ||
                            activityDate.isAfter(week.getWeekEnd().toLocalDate())) {
                        continue;
                    }

                    completedDays.add(
                            toDayCode(activityDate.getDayOfWeek())
                    );
                }
            }

            for (String day : week.getPlannedDays()) {

                plannedCount.put(
                        day,
                        plannedCount.getOrDefault(day, 0) + 1
                );

                if (completedDays.contains(day)) {
                    completedCount.put(
                            day,
                            completedCount.getOrDefault(day, 0) + 1
                    );
                }
            }
        }

        List<String> bestDays = new ArrayList<>(plannedCount.keySet());

        bestDays.sort(
                Comparator.comparingDouble(
                        (String day) -> (double) completedCount.getOrDefault(day, 0)
                                / plannedCount.get(day)
                ).reversed()
        );

        return bestDays;
    }

    private String toDayCode(DayOfWeek day) {

        return switch (day) {
            case SUNDAY -> "SUN";
            case MONDAY -> "MON";
            case TUESDAY -> "TUE";
            case WEDNESDAY -> "WED";
            case THURSDAY -> "THU";
            case FRIDAY -> "FRI";
            case SATURDAY -> "SAT";
        };
    }
}
