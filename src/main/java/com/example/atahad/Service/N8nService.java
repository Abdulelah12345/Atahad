
package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.TodayTaskResponse;
import com.example.atahad.Dto.Out.WhatsAppOutResponse;
import com.example.atahad.Dto.Out.WeeklyReportResponse;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.Goal;
import com.example.atahad.Entity.GoalTask;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.WhatsAppMessage;
import com.example.atahad.Repository.CommitmentRepository;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GoalTaskRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.time.temporal.TemporalAdjusters;
import java.util.*;

// what n8n calls: the daily automation, the reminders, and the WhatsApp queue
// every call must have the header X-N8N-KEY with the key from application-local.properties
@Service
@RequiredArgsConstructor
public class N8nService {

    private final CommitmentRepository commitmentRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final WhatsAppService whatsAppService;

    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final AiService aiService;

    @Value("${n8n.key:}")
    private String n8nKey;

    public void checkKey(String key){
        if(n8nKey == null || n8nKey.isBlank() || !n8nKey.equals(key)){
            throw new ApiException("Wrong n8n key");
        }
    }

    // one reminder for every member who must do something today (MUST_TODAY), once a day
    @Transactional
    public int createReminders(){
        Map<Integer, Member> members = new LinkedHashMap<>();
        for(Commitment commitment : commitmentRepository.findCommitmentsByStatus("ACTIVE")){
            members.put(commitment.getMember().getId(), commitment.getMember());
        }
        int count = 0;
        for(Member member : members.values()){
            if(whatsAppService.sentTodayAlready(member, "REMINDER")){
                continue;
            }
            List<String> lines = new ArrayList<>();
            for(TodayTaskResponse item : commitmentWeekService.getToday(member.getId())){
                if("MUST_TODAY".equals(item.getTrackStatus()) && item.getRemaining() > 0){
                    lines.add("*" + item.getTitle() + "*  (باقي " + item.getRemaining() + " • " + item.getAmountPerTime().stripTrailingZeros().toPlainString() + " ريال للمرة)");
                }
            }
            if(!lines.isEmpty()){
                whatsAppService.reminderMessage(member, lines);
                count++;
            }
        }
        return count;
    }

    public List<WhatsAppOutResponse> getPending(){
        List<WhatsAppOutResponse> list = new ArrayList<>();
        for(WhatsAppMessage message : whatsAppService.getPending()){
            list.add(new WhatsAppOutResponse(message.getId(), message.getPhone(), message.getBody(), message.getType()));
        }
        return list;
    }

    // weekly AI performance reports for the last completed week
    @Transactional(readOnly = true)
    public List<WeeklyReportResponse> generateWeeklyReports(String key){

        checkKey(key);

        LocalDate today = LocalDate.now(ZoneId.of("Asia/Riyadh"));

        LocalDate currentSunday = today.with(
                TemporalAdjusters.previousOrSame(DayOfWeek.SUNDAY)
        );

        LocalDate start = currentSunday.minusWeeks(1);
        LocalDate end = currentSunday.minusDays(1);

        List<CommitmentWeek> weeks =
                commitmentWeekRepository
                        .findCommitmentWeeksByWeekStartGreaterThanEqualAndWeekStartLessThan(
                                start.atStartOfDay(),
                                currentSunday.atStartOfDay()
                        );

        Map<Integer, List<CommitmentWeek>> memberWeeks = new LinkedHashMap<>();

        for(CommitmentWeek week : weeks){

            if(week.getCommitment() == null ||
                    week.getCommitment().getMember() == null){
                continue;
            }

            Integer memberId = week.getCommitment().getMember().getId();

            memberWeeks.computeIfAbsent(
                    memberId, id -> new ArrayList<>()
            ).add(week);
        }

        List<WeeklyReportResponse> reports = new ArrayList<>();

        for(List<CommitmentWeek> memberHistory : memberWeeks.values()){

            Member member = memberHistory.get(0).getCommitment().getMember();

            if(member.getUser() == null ||
                    member.getUser().getEmail() == null ||
                    member.getUser().getEmail().isBlank()){
                continue;
            }

            int totalRequired = 0;
            int totalCompleted = 0;
            int totalExcused = 0;

            List<WeeklyReportResponse.CommitmentResult> results =
                    new ArrayList<>();

            for(CommitmentWeek week : memberHistory){

                Commitment commitment = week.getCommitment();

                if(commitment instanceof Goal goal){

                    List<GoalTask> tasks =
                            goalTaskRepository.findGoalTasksByGoalAndWeekNumber(
                                    goal, week.getWeekNumber()
                            );

                    for(GoalTask task : tasks){

                        int required = number(task.getTimesPerWeek());
                        int completed = Math.min(
                                required, number(task.getCompletedCount())
                        );
                        int excused = Math.min(
                                required - completed,
                                number(task.getExcusedCount())
                        );

                        totalRequired += required;
                        totalCompleted += completed;
                        totalExcused += excused;

                        results.add(
                                new WeeklyReportResponse.CommitmentResult(
                                        goal.getTitle() + " - " + task.getTitle(),
                                        required,
                                        completed,
                                        excused
                                )
                        );
                    }

                }else{

                    int required = number(week.getRequired());
                    int completed = Math.min(
                            required, number(week.getCompleted())
                    );
                    int excused = Math.min(
                            required - completed,
                            number(week.getExcusedDays())
                    );

                    totalRequired += required;
                    totalCompleted += completed;
                    totalExcused += excused;

                    results.add(
                            new WeeklyReportResponse.CommitmentResult(
                                    commitment.getTitle(),
                                    required,
                                    completed,
                                    excused
                            )
                    );
                }
            }

            if(totalRequired == 0){
                continue;
            }

            int actualRequired = totalRequired - totalExcused;

            int percentage = actualRequired == 0
                    ? 100
                    : (int)Math.round(
                    totalCompleted * 100.0 / actualRequired
            );

            StringBuilder summary = new StringBuilder();

            for(WeeklyReportResponse.CommitmentResult item : results){
                summary.append(item.title())
                        .append(": ")
                        .append(item.completed())
                        .append("/")
                        .append(item.required())
                        .append(" | excused: ")
                        .append(item.excused())
                        .append("\n");
            }

            String instructions = """
                    You are the weekly performance coach for Atahad.

                    Write a short personalized weekly report in Arabic.

                    Rules:
                    1. Be encouraging, natural and professional.
                    2. Use only the provided performance data.
                    3. Do not invent achievements or numbers.
                    4. Mention one strength and one practical improvement.
                    5. Give a useful suggestion for next week.
                    6. Do not shame the member for missed commitments.
                    7. Do not mention financial penalties.
                    8. Return plain Arabic text only.
                    9. Keep the response under 100 Arabic words.
                    """;

            String prompt = """
                    Member weekly performance:

                    Completion percentage: %d%%
                    Required: %d
                    Completed: %d
                    Excused: %d

                    Commitments:
                    %s
                    """.formatted(
                    percentage,
                    totalRequired,
                    totalCompleted,
                    totalExcused,
                    summary
            );

            String fallback =
                    "أنجزت " + totalCompleted + " من أصل " +
                            actualRequired + " مرات مطلوبة بعد استبعاد الأعذار. " +
                            "استمر في متابعة تعهداتك، وحدد أوقاتًا مناسبة للأسبوع القادم.";

            String analysis = aiService.ask(
                    instructions + "\n" + aiService.tone(),
                    prompt,
                    fallback
            );

            reports.add(
                    new WeeklyReportResponse(
                            member.getId(),
                            member.getUser().getName(),
                            member.getUser().getEmail(),
                            start,
                            end,
                            totalRequired,
                            totalCompleted,
                            totalExcused,
                            percentage,
                            results,
                            analysis
                    )
            );
        }

        return reports;
    }

    private int number(Integer value){
        return value == null ? 0 : Math.max(0, value);
    }
}
