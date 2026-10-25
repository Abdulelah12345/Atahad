package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.ProofChallengeResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GoalTaskRepository;
import com.example.atahad.Repository.ProofChallengeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// PHOTO proof with a live clip: when the camera opens the member gets one random challenge,
// he does it in the clip, and the AI checks the activity and the challenge together
@Service
@RequiredArgsConstructor
public class ProofChallengeService {
    private final AuthenticatedUserService authenticatedUserService;
    private final ProofChallengeRepository proofChallengeRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GoalTaskRepository goalTaskRepository;

    public static final int VALID_MINUTES = 10;
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final List<String> MOVES = List.of(
            "ارفع يدك اليمين", "ارفع يدك اليسار", "أشّر بإصبعين", "ارفع إبهامك",
            "لوّح للكاميرا بيدك", "حط يدك على راسك");

    public ProofChallengeResponse create(Integer memberId, Integer weekId, Integer goalTaskId){
        // العضو في الرابط يجب أن يكون صاحب جلسة الدخول.
        authenticatedUserService.checkMember(memberId);
        CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(weekId);
        if(week == null || !week.getCommitment().getMember().getId().equals(memberId)){
            throw new ApiException("Week not found");
        }
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Riyadh"));
        if(today.isAfter(week.getWeekEnd().toLocalDate()) || today.isBefore(week.getWeekStart().toLocalDate())){
            throw new ApiException("This week is not running");
        }
        GoalTask task = null;
        String method = week.getCommitment().getProofMethod();
        if(goalTaskId != null){
            task = goalTaskRepository.findGoalTaskById(goalTaskId);
            if(task == null || !task.getGoal().getId().equals(week.getCommitment().getId()) || !task.getWeekNumber().equals(week.getWeekNumber())){
                throw new ApiException("This task is not in this week");
            }
            method = task.getProofMethod();
        }
        if(!"PHOTO".equals(method)){
            throw new ApiException("This commitment is not proved with the camera");
        }

        // one challenge: a number to say, or a move
        String text = RANDOM.nextBoolean()
                ? "قل الرقم " + (10 + RANDOM.nextInt(90)) + " بصوت واضح"
                : MOVES.get(RANDOM.nextInt(MOVES.size()));

        ProofChallenge challenge = new ProofChallenge();
        challenge.setText(text);
        challenge.setCreatedAt(LocalDateTime.now(ZoneId.of("Asia/Riyadh")));
        challenge.setMember(week.getCommitment().getMember());
        challenge.setCommitmentWeek(week);
        challenge.setGoalTask(task);
        proofChallengeRepository.save(challenge);

        return new ProofChallengeResponse(challenge.getId(), text, VALID_MINUTES,
                "Send a PHOTO proof with evidenceData = \"" + challenge.getId() + ":\" + the link of the clip");
    }

    // the result of reading "12:https://..." from a PHOTO proof
    public record Checked(String challenge, String mediaUrl, String error){}

    // null when the evidence has no challenge (a normal photo)
    public Checked check(Proof proof){
        Matcher matcher = Pattern.compile("^\\s*(\\d+)\\s*:\\s*(\\S.*)$").matcher(proof.getEvidenceData() == null ? "" : proof.getEvidenceData());
        if(!matcher.find()){
            return null;
        }
        String url = matcher.group(2).trim();
        ProofChallenge challenge = proofChallengeRepository.findProofChallengeById(Integer.valueOf(matcher.group(1)));
        if(challenge == null || !challenge.getCommitmentWeek().getId().equals(proof.getCommitmentWeek().getId())){
            return new Checked(null, url, "التحدي مو لهالأسبوع");
        }
        boolean sameTask = challenge.getGoalTask() == null ? proof.getGoalTask() == null
                : proof.getGoalTask() != null && challenge.getGoalTask().getId().equals(proof.getGoalTask().getId());
        if(!sameTask){
            return new Checked(null, url, "التحدي مو لهالمهمة");
        }
        if(challenge.getUsedAt() != null){
            return new Checked(null, url, "التحدي مستخدم قبل، افتح الكاميرا من جديد");
        }
        LocalDateTime sent = proof.getSubmittedAt() == null ? LocalDateTime.now(ZoneId.of("Asia/Riyadh")) : proof.getSubmittedAt();
        if(challenge.getCreatedAt().plusMinutes(VALID_MINUTES).isBefore(sent)){
            return new Checked(null, url, "انتهى وقت التحدي (" + VALID_MINUTES + " دقايق)، افتح الكاميرا من جديد");
        }
        challenge.setUsedAt(sent);
        proofChallengeRepository.save(challenge);
        return new Checked(challenge.getText(), url, null);
    }
}
