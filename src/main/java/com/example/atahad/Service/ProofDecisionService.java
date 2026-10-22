package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.ProofRequest;
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

// the AI decision on a proof: ACCEPTED (the time is counted), REJECTED (the member can object in 48 hours)
// or ESCALATED (the AI is not sure, an admin decides). Also the proofs of habits (the goal tasks are in ProofService)
@Service
@RequiredArgsConstructor
public class ProofDecisionService {
    private final ProofRepository proofRepository;
    private final ExcuseRepository excuseRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final MemberRepository memberRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final LockService lockService;
    private final AiService aiService;

    // a proof of a habit (personal or group): same rules as the goal tasks
    @Transactional
    public Proof addHabitProof(Integer memberId, Integer weekId, ProofRequest request){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        lockService.checkCanAct(member);
        CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(weekId);
        if(week == null || !week.getCommitment().getMember().getId().equals(memberId)){
            throw new ApiException("Week not found");
        }
        Commitment commitment = week.getCommitment();
        if(!(Hibernate.unproxy(commitment) instanceof Habit)){
            throw new ApiException("This week is a goal week, send the proof to its task");
        }
        if(!"ACTIVE".equals(commitment.getStatus())){
            throw new ApiException("This commitment is finished");
        }
        if(!commitment.getProofMethod().equals(request.getType())){
            throw new ApiException("Proof type must be " + commitment.getProofMethod());
        }

        // the submission time is what counts: until saturday 23:59:59
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
        if(now.isBefore(week.getWeekStart())){
            throw new ApiException("This week has not started");
        }
        if(now.isAfter(week.getWeekEnd())){
            throw new ApiException("Proof submission time has ended");
        }
        LocalDateTime activityTime = request.getActivityTime();
        if(activityTime.isAfter(now)){
            throw new ApiException("Activity time cannot be in the future");
        }
        if(activityTime.isBefore(week.getWeekStart()) || activityTime.isAfter(week.getWeekEnd())){
            throw new ApiException("Activity time must be inside this week");
        }

        // one proof for every day
        LocalDate day = activityTime.toLocalDate();
        for(Proof old : proofRepository.findProofsByCommitmentWeekId(weekId)){
            boolean sameDay = old.getActivityTime() != null && old.getActivityTime().toLocalDate().equals(day);
            if(sameDay && !"REJECTED".equals(old.getResult())){
                throw new ApiException("This day already has a proof");
            }
        }
        for(Excuse excuse : excuseRepository.findExcusesByCommitmentWeekId(weekId)){
            if(day.equals(excuse.getExcuseDate()) && !"REJECTED".equals(excuse.getStatus())){
                throw new ApiException("This day already has an excuse");
            }
        }
        if(commitmentWeekService.remainingTimes(week) <= 0){
            throw new ApiException("You already finished this week");
        }

        Proof proof = new Proof();
        proof.setType(request.getType());
        proof.setEvidenceData(request.getEvidenceData());
        proof.setActivityTime(activityTime);
        proof.setSubmittedAt(now);
        proof.setResult("PENDING");
        proof.setProcessingStatus("WAITING");
        proof.setCommitmentWeek(week);
        proofRepository.save(proof);

        decide(proof);
        return proof;
    }

    // called right after a proof is saved (habits here, goal tasks from ProofService)
    @Transactional
    public void decide(Proof proof){
        proof.setProcessingStatus("PROCESSING");
        proofRepository.save(proof);

        Commitment commitment = proof.getCommitmentWeek().getCommitment();
        String task = proof.getGoalTask() == null ? commitment.getTitle() : commitment.getTitle() + " - " + proof.getGoalTask().getTitle();
        boolean photo = "PHOTO".equals(proof.getType());

        String answer = aiService.askWithImages(
                "You check proofs in a commitment app. Decide if the evidence shows that the person really did the task. "
                        + "REJECTED when it clearly does not match the task, or the photo is a screenshot, from the internet, or of another day. "
                        + "ESCALATED when you are not sure. Answer only with two lines:\n"
                        + "DECISION: ACCEPTED or REJECTED or ESCALATED\nREASON: one short sentence in Arabic",
                "Task: " + task + "\nProof type: " + proof.getType()
                        + "\nActivity time: " + proof.getActivityTime()
                        + (photo ? "\nThe photo is attached." : "\nEvidence: " + proof.getEvidenceData()),
                photo ? List.of(proof.getEvidenceData()) : List.of(),
                "DECISION: ESCALATED\nREASON: الذكاء الاصطناعي غير متاح الحين، بيراجعه الأدمن");

        String reason = aiService.field(answer, "REASON");
        applyDecision(proof, aiService.decision(answer), reason);
    }

    // shared with the admin review and the objection
    @Transactional
    public void applyDecision(Proof proof, String decision, String reason){
        boolean wasAccepted = "ACCEPTED".equals(proof.getResult());
        proof.setProcessingStatus("FINISHED");
        proof.setDecidedAt(LocalDateTime.now());
        proof.setResult(decision);
        proof.setRejectionReason("ACCEPTED".equals(decision) ? null : cut(reason));
        proofRepository.save(proof);

        if("ACCEPTED".equals(decision) && !wasAccepted){
            Integer taskId = proof.getGoalTask() == null ? null : proof.getGoalTask().getId();
            commitmentWeekService.recordCompletion(proof.getCommitmentWeek().getId(), taskId);
        }
    }

    public List<Proof> getEscalated(){
        return proofRepository.findProofsByResult("ESCALATED");
    }

    private String cut(String text){
        if(text == null){
            return null;
        }
        return text.length() > 500 ? text.substring(0, 500) : text;
    }
}
