package com.example.atahad.Service;

import com.example.atahad.AI.AiService;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// the monthly summary card (like Spotify Wrapped), the numbers come from the database and the AI writes the text
// made for everyone on the 1st of every month, and the member can make it again any time
@Service
@RequiredArgsConstructor
public class MonthlyWrappedService {
    private final MonthlyWrappedRepository monthlyWrappedRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final PenaltyRepository penaltyRepository;
    private final PointLogRepository pointLogRepository;
    private final GroupTitleService groupTitleService;
    private final MemberRepository memberRepository;
    private final GroupAccessService groupAccessService;
    private final AiService aiService;

    public List<MonthlyWrapped> getMyWrapped(Integer memberId){
        groupAccessService.getMember(memberId);
        return monthlyWrappedRepository.findMonthlyWrappedsByMemberIdOrderByMonthDesc(memberId);
    }

    // month like 2026-10
    @Transactional
    public MonthlyWrapped generate(Integer memberId, String month){
        Member member = groupAccessService.getMember(memberId);
        YearMonth yearMonth;
        try{
            yearMonth = YearMonth.parse(month);
        }catch(Exception e){
            throw new ApiException("Month must be like 2026-10");
        }
        if(yearMonth.isAfter(YearMonth.now())){
            throw new ApiException("This month did not come yet");
        }
        return build(member, yearMonth);
    }

    @Transactional
    public void generateAll(YearMonth month){
        for(Member member : memberRepository.findAll()){
            if(!commitmentWeekRepository.findCommitmentWeeksByCommitmentMember(member).isEmpty()){
                build(member, month);
            }
        }
    }

    private MonthlyWrapped build(Member member, YearMonth month){
        LocalDate first = month.atDay(1);
        LocalDate last = month.atEndOfMonth();
        LocalDateTime from = first.atStartOfDay();
        LocalDateTime to = last.atTime(23, 59, 59);

        int required = 0;
        int completed = 0;
        int fullWeeks = 0;
        int weeks = 0;
        Map<String, Integer> byCommitment = new HashMap<>();
        for(CommitmentWeek week : commitmentWeekRepository.findCommitmentWeeksByCommitmentMember(member)){
            LocalDate start = week.getWeekStart().toLocalDate();
            if(start.isBefore(first) || start.isAfter(last)){
                continue;
            }
            weeks++;
            required += week.getRequired();
            completed += week.getCompleted();
            if(Boolean.TRUE.equals(week.getIsFullWeek())){
                fullWeeks++;
            }
            byCommitment.merge(week.getCommitment().getTitle(), week.getCompleted(), Integer::sum);
        }

        String best = null;
        for(Map.Entry<String, Integer> entry : byCommitment.entrySet()){
            if(best == null || entry.getValue() > byCommitment.get(best)){
                best = entry.getKey();
            }
        }

        BigDecimal donated = BigDecimal.ZERO;
        for(Penalty penalty : penaltyRepository.findPenaltiesByMemberAndStatus(member, "PAID")){
            if(penalty.getPaidAt() != null && !penalty.getPaidAt().isBefore(from) && !penalty.getPaidAt().isAfter(to)){
                donated = donated.add(penalty.getAmount());
            }
        }

        int points = 0;
        for(PointLog log : pointLogRepository.findPointLogsByMemberIdOrderByCreatedAtDesc(member.getId())){
            if(log.getPoints() > 0 && !log.getCreatedAt().isBefore(from) && !log.getCreatedAt().isAfter(to)){
                points += log.getPoints();
            }
        }

        StringBuilder titles = new StringBuilder();
        for(String title : groupTitleService.titlesOf(member, first, last)){
            titles.append(title).append(" ");
        }

        int percent = required == 0 ? 0 : Math.min(100, completed * 100 / required);
        String name = groupAccessService.nameOf(member);
        String facts = "Name: " + name + "\nMonth: " + month
                + "\nTimes done: " + completed + " of " + required + " (" + percent + "%)"
                + "\nFull weeks: " + fullWeeks + " of " + weeks
                + "\nBest commitment: " + (best == null ? "none" : best)
                + "\nDonated to Ehsan: " + donated + " SAR"
                + "\nPoints earned: " + points
                + "\nLevel now: " + member.getLevel()
                + "\nGroup titles: " + (titles.length() == 0 ? "none" : titles.toString().trim());

        String fallback = name + "، شهر " + month + ": سويت " + completed + " من " + required + " مرة (" + percent + "%)، "
                + fullWeeks + " أسابيع كاملة، أقوى التزام عندك " + (best == null ? "-" : best)
                + "، وتبرعت لإحسان بـ " + donated + " ريال. مستواك الحين " + member.getLevel() + ".";

        String summary = aiService.ask(
                "You write a short monthly wrapped card for a commitment app (max 70 words), proud and personal, "
                        + "keep every number exactly as given. " + aiService.tone(),
                facts, fallback);

        MonthlyWrapped wrapped = monthlyWrappedRepository.findMonthlyWrappedByMemberIdAndMonth(member.getId(), month.toString());
        if(wrapped == null){
            wrapped = new MonthlyWrapped();
            wrapped.setMember(member);
            wrapped.setMonth(month.toString());
        }
        wrapped.setSummary(summary.length() > 2000 ? summary.substring(0, 2000) : summary);
        wrapped.setCreatedAt(LocalDateTime.now());
        // cardImageUrl: the app draws the card from the summary, an image can be saved here later
        monthlyWrappedRepository.save(wrapped);
        return wrapped;
    }
}
