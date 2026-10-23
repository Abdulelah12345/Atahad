package com.example.atahad.Service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;

// everything that runs by itself at 00:00 Riyadh time, in this order:
// 1) every day: the personal weeks (SAFE / MUST_TODAY / LOST_DAY), on sunday also close the old weeks and open the new ones
// 2) sunday: finish the matches, then the weekly settlement of every group
// 3) every day: group donations not paid for 7 days
// 4) the 1st of the month: the monthly wrapped of last month
@Service
@RequiredArgsConstructor
public class AutomationService {
    private final CommitmentWeekService commitmentWeekService;
    private final GroupMatchService groupMatchService;
    private final GroupSettlementService groupSettlementService;
    private final MonthlyWrappedService monthlyWrappedService;

    // false when n8n runs it (POST /api/v1/n8n/run-daily), so it does not run twice
    @Value("${automation.scheduler-enabled:true}")
    private boolean schedulerEnabled;

    @Scheduled(cron = "0 0 0 * * *", zone = "Asia/Riyadh")
    public void midnight(){
        if(schedulerEnabled){
            run(LocalDate.now());
        }
    }

    //also called from the admin endpoint to try any date in the demo
    public void run(LocalDate today){
        commitmentWeekService.runDaily(today);
        if(today.getDayOfWeek() == DayOfWeek.SUNDAY){
            groupMatchService.finishMatches(today);
            groupSettlementService.runWeekly(today);
        }
        groupSettlementService.punishRefusals(today);
        if(today.getDayOfMonth() == 1){
            monthlyWrappedService.generateAll(YearMonth.from(today.minusMonths(1)));
        }
    }
}
