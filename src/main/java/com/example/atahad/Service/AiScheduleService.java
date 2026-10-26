
package com.example.atahad.Service;

import com.example.atahad.AI.AiService;
import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.AiScheduleResponse;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Entity.Habit;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.Proof;
import com.example.atahad.Repository.CommitmentRepository;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class AiScheduleService {

    private final AiService aiService;
    private final MemberRepository memberRepository;
    private final CommitmentRepository commitmentRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final ScheduleDayAnalysisService dayAnalysisService;

    private final ZoneId zone = ZoneId.of("Asia/Riyadh");

    @Transactional(readOnly = true)
    public List<AiScheduleResponse> generate(Integer userId) {

        Member member = memberRepository.findMemberById(userId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        List<Commitment> commitments =
                commitmentRepository.findCommitmentsByMemberAndStatus(member, "ACTIVE");

        List<AiScheduleResponse> schedules = new ArrayList<>();
        List<LocalDateTime[]> reservedTimes = new ArrayList<>();

        LocalDateTime now = LocalDateTime.now(zone);

        for (Commitment commitment : commitments) {

            List<CommitmentWeek> weeks =
                    commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(commitment);

            CommitmentWeek currentWeek = null;
            List<CommitmentWeek> previousWeeks = new ArrayList<>();

            for (CommitmentWeek week : weeks) {

                if (week.getWeekStart() == null || week.getWeekEnd() == null) {
                    continue;
                }

                if (!now.isBefore(week.getWeekStart()) &&
                        !now.isAfter(week.getWeekEnd())) {
                    currentWeek = week;
                }

                if (week.getWeekEnd().isBefore(now)) {
                    previousWeeks.add(week);
                }
            }

            if (currentWeek == null ||
                    "SETTLED".equals(currentWeek.getTrackStatus())) {
                continue;
            }

            if (commitment instanceof Habit habit) {

                int required = currentWeek.getRequired() == null
                        ? habit.getTimesPerWeek()
                        : currentWeek.getRequired();

                int completed = currentWeek.getCompleted() == null
                        ? 0 : currentWeek.getCompleted();

                int excused = currentWeek.getExcusedDays() == null
                        ? 0 : currentWeek.getExcusedDays();

                int remaining = Math.max(0, required - completed - excused);

                if (remaining == 0) {
                    continue;
                }

                Set<String> plannedDays = currentWeek.getPlannedDays();

                if (plannedDays == null || plannedDays.isEmpty()) {
                    plannedDays = habit.getPlannedDays();
                }

                Set<String> completedDates =
                        getCompletedDates(currentWeek, null);

                List<String> bestDays =
                        dayAnalysisService.getBestDays(previousWeeks);

                int duration = habit.getTargetMinutes() == null
                        ? 30 : habit.getTargetMinutes();

                AiScheduleResponse schedule = generateSchedule(
                        habit.getTitle(),
                        remaining,
                        duration,
                        plannedDays,
                        bestDays,
                        completedDates,
                        currentWeek,
                        reservedTimes,
                        now
                );

                schedules.add(schedule);
            }

            if (commitment instanceof Goal goal) {

                if (goal.getTasks() == null) {
                    continue;
                }

                for (GoalTask task : goal.getTasks()) {

                    if (task.getWeekNumber() == null ||
                            !task.getWeekNumber().equals(currentWeek.getWeekNumber())) {
                        continue;
                    }

                    if ("SETTLED".equals(task.getTrackStatus())) {
                        continue;
                    }

                    int completed = task.getCompletedCount() == null
                            ? 0 : task.getCompletedCount();

                    int excused = task.getExcusedCount() == null
                            ? 0 : task.getExcusedCount();

                    int remaining = Math.max(
                            0, task.getTimesPerWeek() - completed - excused
                    );

                    if (remaining == 0) {
                        continue;
                    }

                    Set<String> completedDates =
                            getCompletedDates(currentWeek, task);

                    int duration = goal.getTargetMinutes() == null
                            ? 30 : goal.getTargetMinutes();

                    AiScheduleResponse schedule = generateSchedule(
                            goal.getTitle() + " - " + task.getTitle(),
                            remaining,
                            duration,
                            task.getPlannedDays(),
                            List.of(),
                            completedDates,
                            currentWeek,
                            reservedTimes,
                            now
                    );

                    schedules.add(schedule);
                }
            }
        }

        return schedules;
    }

    private AiScheduleResponse generateSchedule(
            String title,
            int remaining,
            int duration,
            Set<String> plannedDays,
            List<String> bestDays,
            Set<String> completedDates,
            CommitmentWeek week,
            List<LocalDateTime[]> reservedTimes,
            LocalDateTime now) {

        List<String> availableDates = new ArrayList<>();

        for (LocalDate date = now.toLocalDate();
             !date.isAfter(week.getWeekEnd().toLocalDate());
             date = date.plusDays(1)) {

            String day = toDayCode(date.getDayOfWeek());

            if (plannedDays != null && !plannedDays.isEmpty()
                    && !plannedDays.contains(day)) {
                continue;
            }

            if (completedDates.contains(date.toString())) {
                continue;
            }

            availableDates.add(date.toString());
        }

        // every time needs its own day, so the days left in this week (only the planned days, without the days already done)
        // must be at least the times left
        if (availableDates.size() < remaining) {
            String days = availableDates.isEmpty()
                    ? "ما باقي ولا يوم من أيامك المحددة هالأسبوع"
                    : "باقي " + availableDates.size() + (availableDates.size() == 1 ? " يوم" : " أيام") + " بس من أيامك المحددة هالأسبوع";
            throw new ApiException(
                    "ما نقدر نجدول «" + title + "»: باقي عليك " + remaining + " مرات و" + days
                            + "، وكل مرة تحتاج يوم لحالها. سجّل اللي تقدر عليه، أو قدّم عذر عن الأيام اللي فاتت."
            );
        }

        String instructions = """
                You are an AI scheduling assistant for Atahad.

                Generate a realistic schedule for the user's commitment.

                Mandatory rules:
                1. Use only the allowed dates.
                2. Return exactly the requested number of suggestions.
                3. Never repeat a date for the same task.
                4. Prioritize successful weekdays when history exists.
                5. Respect the planned weekdays.
                6. Use Asia/Riyadh timezone.
                7. Respect the requested duration.
                8. Never suggest a past time.
                9. Avoid reserved time intervals.
                10. Prefer balanced scheduling when possible.
                11. Return only valid JSON without markdown.

                JSON format:
                {
                  "title": "Commitment title",
                  "durationMinutes": 30,
                  "suggestions": [
                    {
                      "date": "YYYY-MM-DD",
                      "startTime": "HH:mm",
                      "endTime": "HH:mm"
                    }
                  ]
                }
                """;

        String prompt =
                "Commitment: " + title
                        + "\nCurrent Riyadh time: " + now
                        + "\nRemaining sessions: " + remaining
                        + "\nDuration minutes: " + duration
                        + "\nAllowed dates: " + availableDates
                        + "\nHistorically successful weekdays: " + bestDays
                        + "\nReserved intervals: " + formatReservedTimes(reservedTimes);

        for (int attempt = 0; attempt < 3; attempt++) {

            String answer = aiService.ask(instructions, prompt, "");

            if (answer == null || answer.isBlank()) {
                throw new ApiException("AI scheduling is unavailable");
            }

            try {
                ObjectMapper mapper = new ObjectMapper();
                AiScheduleResponse response =
                        mapper.readValue(answer, AiScheduleResponse.class);

                validateSchedule(
                        response,
                        availableDates,
                        remaining,
                        duration,
                        reservedTimes,
                        now
                );

                response.setTitle(title);
                response.setDurationMinutes(duration);

                for (AiScheduleResponse.ScheduleSuggestion suggestion
                        : response.getSuggestions()) {

                    LocalDate date = LocalDate.parse(suggestion.getDate());

                    LocalDateTime start = date.atTime(
                            LocalTime.parse(suggestion.getStartTime())
                    );

                    LocalDateTime end = date.atTime(
                            LocalTime.parse(suggestion.getEndTime())
                    );

                    reservedTimes.add(new LocalDateTime[]{start, end});
                }

                return response;

            } catch (Exception e) {
                prompt += "\nPrevious proposal was invalid. "
                        + "Regenerate all suggestions and strictly follow every rule.";
            }
        }

        throw new ApiException(
                "AI could not generate a valid schedule for " + title
        );
    }

    private Set<String> getCompletedDates(
            CommitmentWeek week, GoalTask task) {

        Set<String> completedDates = new HashSet<>();

        if (week.getProofs() == null) {
            return completedDates;
        }

        for (Proof proof : week.getProofs()) {

            if (!"ACCEPTED".equals(proof.getResult()) ||
                    proof.getActivityTime() == null) {
                continue;
            }

            if (task == null && proof.getGoalTask() != null) {
                continue;
            }

            if (task != null && (proof.getGoalTask() == null ||
                    !task.getId().equals(proof.getGoalTask().getId()))) {
                continue;
            }

            completedDates.add(
                    proof.getActivityTime().toLocalDate().toString()
            );
        }

        return completedDates;
    }

    private void validateSchedule(
            AiScheduleResponse response,
            List<String> availableDates,
            int remaining,
            int duration,
            List<LocalDateTime[]> reservedTimes,
            LocalDateTime now) {

        if (response == null ||
                response.getSuggestions() == null ||
                response.getSuggestions().size() != remaining) {
            throw new ApiException("Invalid number of schedule suggestions");
        }

        Set<String> usedDates = new HashSet<>();
        List<LocalDateTime[]> proposedTimes = new ArrayList<>();

        for (AiScheduleResponse.ScheduleSuggestion suggestion
                : response.getSuggestions()) {

            if (suggestion == null ||
                    suggestion.getDate() == null ||
                    suggestion.getStartTime() == null ||
                    suggestion.getEndTime() == null) {
                throw new ApiException("Invalid schedule suggestion");
            }

            LocalDate date;
            LocalTime startTime;
            LocalTime endTime;

            try {
                date = LocalDate.parse(suggestion.getDate());
                startTime = LocalTime.parse(suggestion.getStartTime());
                endTime = LocalTime.parse(suggestion.getEndTime());
            } catch (Exception e) {
                throw new ApiException("Invalid schedule date or time");
            }

            if (!availableDates.contains(date.toString())) {
                throw new ApiException("AI selected an unavailable day");
            }

            if (!usedDates.add(date.toString())) {
                throw new ApiException("AI repeated a day");
            }

            LocalDateTime start = date.atTime(startTime);
            LocalDateTime end = date.atTime(endTime);

            if (!start.isAfter(now) || !end.isAfter(start)) {
                throw new ApiException("Invalid schedule time");
            }

            if (Duration.between(start, end).toMinutes() != duration) {
                throw new ApiException("Invalid schedule duration");
            }

            for (LocalDateTime[] reserved : reservedTimes) {
                if (overlaps(start, end, reserved[0], reserved[1])) {
                    throw new ApiException("Schedule time conflict");
                }
            }

            for (LocalDateTime[] proposed : proposedTimes) {
                if (overlaps(start, end, proposed[0], proposed[1])) {
                    throw new ApiException("Schedule time conflict");
                }
            }

            proposedTimes.add(new LocalDateTime[]{start, end});
        }
    }

    private boolean overlaps(
            LocalDateTime start1,
            LocalDateTime end1,
            LocalDateTime start2,
            LocalDateTime end2) {

        return start1.isBefore(end2) && end1.isAfter(start2);
    }

    private String formatReservedTimes(List<LocalDateTime[]> reservedTimes) {

        List<String> intervals = new ArrayList<>();

        for (LocalDateTime[] reserved : reservedTimes) {
            intervals.add(reserved[0] + " to " + reserved[1]);
        }

        return intervals.toString();
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
