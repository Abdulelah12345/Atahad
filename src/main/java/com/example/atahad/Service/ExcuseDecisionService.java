package com.example.atahad.Service;

import com.example.atahad.AI.AiService;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.ExcuseRequest;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.ExcuseRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.ProofRepository;
import com.example.atahad.Repository.ObjectionRepository;
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
    private final AuthenticatedUserService authenticatedUserService;
    private final ProofAttachmentService proofAttachmentService;
    private final ExcuseRepository excuseRepository;
    private final ProofRepository proofRepository;
    private final ObjectionRepository objectionRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final MemberRepository memberRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final LockService lockService;
    private final AiService aiService;
    private final AcceptanceGuardService acceptanceGuardService;

    @Transactional
    public Excuse addHabitExcuse(Integer memberId, Integer weekId, ExcuseRequest request){
        // the id in the path must be the logged in member
        authenticatedUserService.checkMember(memberId);
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
        for (Proof proof : proofRepository.findProofsByCommitmentWeekId(weekId)) {

            if (proof.getActivityTime() == null) {
                throw new ApiException("Proof activity time is missing");
            }

            LocalDate proofDate = proof.getActivityTime().toLocalDate();
            boolean isSameDay = proofDate.equals(day);

            if (isSameDay) {

                String result = proof.getResult();

                if (result == null) {
                    throw new ApiException("Proof result is missing");
                }

                // a day with an accepted proof needs no excuse
                boolean isAccepted = result.equals("ACCEPTED");

                if (isAccepted) {
                    throw new ApiException(
                            "This day already has an accepted proof"
                    );
                }

                // wait for the proof of that day first
                boolean isPending = result.equals("PENDING");

                if (isPending) {
                    throw new ApiException(
                            "Wait until the proof for this day is processed"
                    );
                }

                boolean isEscalated = result.equals("ESCALATED");

                if (isEscalated) {
                    throw new ApiException(
                            "Wait until the admin reviews the proof for this day"
                    );
                }
            }
        }

        // [day start, next day start)
        LocalDateTime dayStart = day.atStartOfDay();

        LocalDateTime nextDayStart = day.plusDays(1).atStartOfDay();

        Integer goalTaskId = null;

        // not while an objection on that day is open
        boolean hasPendingProofObjection =
                objectionRepository.existsPendingProofObjection(
                        weekId,
                        goalTaskId,
                        dayStart,
                        nextDayStart
                );

        if (hasPendingProofObjection) {
            throw new ApiException(
                    "Wait until the proof objection for this day is resolved"
            );
        }

        boolean hasPendingExcuseObjection =
                objectionRepository.existsPendingExcuseObjection(
                        weekId,
                        goalTaskId,
                        day
                );

        if (hasPendingExcuseObjection) {
            throw new ApiException(
                    "Wait until the excuse objection for this day is resolved"
            );
        }

        Excuse excuse = new Excuse();
        excuse.setType(request.getType());
        // the attachment must be his
        proofAttachmentService.requireExcuseDocument(memberId, request.getEvidenceUrl());
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
                List.of(proofAttachmentService.resolve(commitment.getMember().getId(), excuse.getEvidenceUrl())),
                "DECISION: ESCALATED\nREASON: الذكاء الاصطناعي غير متاح الحين، بيراجعه الأدمن");
        applyDecision(excuse, aiService.decision(answer), aiService.field(answer, "REASON"), null);
    }

    // shared with the admin review and the objection
    @Transactional
    public void applyDecision(Excuse excuse, String decision, String reason, Admin admin){
        if (decision == null) {
            throw new ApiException("Decision is required");
        }

        boolean isAccepted = decision.equals("ACCEPTED");
        if (isAccepted) {
            Integer goalTaskId = null;
            if (excuse.getGoalTask() != null) {
                goalTaskId = excuse.getGoalTask().getId();
            }

            // lock the week so the day is never counted twice
            acceptanceGuardService.lockAndCheck(
                    excuse.getCommitmentWeek().getId(),
                    goalTaskId,
                    excuse.getExcuseDate(),
                    null,
                    excuse.getId()
            );
        }

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
