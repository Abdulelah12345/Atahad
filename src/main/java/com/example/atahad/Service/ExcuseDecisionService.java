package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.ExcuseRequest;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.ExcuseRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.ProofRepository;
import lombok.RequiredArgsConstructor;
import org.hibernate.Hibernate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

// the AI decision on an excuse: ACCEPTED (one excused time: a lost time not paid is cancelled,
// a paid one gives a compensation grace day), REJECTED, or ESCALATED (an admin decides, the app opens until then)
// Also the excuses of habits (the goal tasks are in ExcuseService). An excuse can be sent while the app is locked
@Service
@RequiredArgsConstructor
public class ExcuseDecisionService {
    private final ExcuseRepository excuseRepository;
    private final ProofRepository proofRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final MemberRepository memberRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final LockService lockService;
    private final AiService aiService;

    @Transactional
    public Excuse addHabitExcuse(Integer memberId, Integer weekId, ExcuseRequest request){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        String blocked = lockService.blockReason(member, "POST", "/api/v1/excuse");
        if(blocked != null){
            throw new ApiException(blocked);
        }
        CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(weekId);
        if(week == null || !week.getCommitment().getMember().getId().equals(memberId)){
            throw new ApiException("Week not found");
        }
        if(!(Hibernate.unproxy(week.getCommitment()) instanceof Habit)){
            throw new ApiException("This week is a goal week, send the excuse to its task");
        }

        // until saturday 23:59:59, and the day must be inside the week
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if(now.isAfter(week.getWeekEnd())){
            throw new ApiException("Excuse submission time has ended");
        }
        LocalDate day = request.getExcuseDate();
        if(day.isBefore(week.getWeekStart().toLocalDate()) || day.isAfter(week.getWeekEnd().toLocalDate())){
            throw new ApiException("Excuse date must be inside this week");
        }
        for(Excuse old : excuseRepository.findExcusesByCommitmentWeekId(weekId)){
            if(day.equals(old.getExcuseDate()) && !"REJECTED".equals(old.getStatus())){
                throw new ApiException("This day already has an excuse");
            }
        }
        for(Proof proof : proofRepository.findProofsByCommitmentWeekId(weekId)){
            boolean sameDay = proof.getActivityTime() != null && proof.getActivityTime().toLocalDate().equals(day);
            if(sameDay && "ACCEPTED".equals(proof.getResult())){
                throw new ApiException("This day already has an accepted proof");
            }
        }

        Excuse excuse = new Excuse();
        excuse.setType(request.getType());
        excuse.setEvidenceUrl(request.getEvidenceUrl());
        excuse.setExcuseDate(day);
        excuse.setStatus("PENDING");
        excuse.setProcessingStatus("WAITING");
        excuse.setForwardedToAdmin(false);
        excuse.setCommitmentWeek(week);
        excuseRepository.save(excuse);

        decide(excuse);
        return excuse;
    }

    // called right after an excuse is saved (habits here, goal tasks from ExcuseService)
    @Transactional
    public void decide(Excuse excuse){
        excuse.setProcessingStatus("PROCESSING");
        excuseRepository.save(excuse);

        if(excuse.getEvidenceUrl() == null || excuse.getEvidenceUrl().isBlank()){
            applyDecision(excuse, "ESCALATED", "ما فيه دليل مرفق، بيراجعه الأدمن", null);
            return;
        }
        Commitment commitment = excuse.getCommitmentWeek().getCommitment();
        String answer = aiService.askWithImages(
                "You check excuses in a commitment app. The person could not do the task on a day and sent evidence "
                        + "(a sick leave, a hospital paper, a travel ticket ...). Decide if the evidence is real and matches the excuse type and the date. "
                        + "ESCALATED when you are not sure. Answer only with two lines:\n"
                        + "DECISION: ACCEPTED or REJECTED or ESCALATED\nREASON: one short sentence in Arabic",
                "Task: " + commitment.getTitle() + "\nExcuse type: " + excuse.getType() + "\nExcuse date: " + excuse.getExcuseDate()
                        + "\nThe evidence is attached.",
                List.of(excuse.getEvidenceUrl()),
                "DECISION: ESCALATED\nREASON: الذكاء الاصطناعي غير متاح الحين، بيراجعه الأدمن");
        applyDecision(excuse, aiService.decision(answer), aiService.field(answer, "REASON"), null);
    }

    // shared with the admin review and the objection
    @Transactional
    public void applyDecision(Excuse excuse, String decision, String reason, Admin admin){
        boolean wasAccepted = "ACCEPTED".equals(excuse.getStatus());
        excuse.setStatus(decision);
        excuse.setAiAssessment(reason == null ? null : (reason.length() > 1000 ? reason.substring(0, 1000) : reason));
        excuse.setProcessingStatus("FINISHED");
        excuse.setDecidedAt(LocalDateTime.now());
        excuse.setForwardedToAdmin("ESCALATED".equals(decision) || admin != null);
        if(admin != null){
            excuse.setAdmin(admin);
        }
        excuseRepository.save(excuse);

        if("ACCEPTED".equals(decision) && !wasAccepted){
            Integer taskId = excuse.getGoalTask() == null ? null : excuse.getGoalTask().getId();
            commitmentWeekService.recordExcuse(excuse.getCommitmentWeek().getId(), taskId);
        }
        // ESCALATED opens the app until the admin decides, REJECTED locks it again if something is still owed
        lockService.refresh(excuse.getCommitmentWeek().getCommitment().getMember());
    }

    public List<Excuse> getEscalated(){
        return excuseRepository.findExcusesByStatus("ESCALATED");
    }
}
