
package com.example.atahad.Service;

import com.example.atahad.AI.AiService;
import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.LuckyChallenge;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.LuckyChallengeRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class LuckyChallengeService {

    private final LuckyChallengeRepository luckyChallengeRepository;
    private final MemberRepository memberRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final AiService aiService;

    private static final int MAX_ATTEMPTS = 3;

    @Transactional
    public LuckyChallenge randomChallenge(Integer memberId, String difficulty){

        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }

        if(difficulty == null || !List.of("EASY", "MEDIUM", "HARD").contains(difficulty)){
            throw new ApiException("Invalid challenge difficulty");
        }

        LocalDate today = LocalDate.now();

        LuckyChallenge challenge = luckyChallengeRepository.findLuckyChallengeByMemberIdAndChallengeDate(memberId, today);

        if(challenge == null){
            challenge = new LuckyChallenge();
            challenge.setMember(member);
            challenge.setChallengeDate(today);
            challenge.setAttempts(0);
            challenge.setStatus("OFFERED");
            challenge.setDifficulty(difficulty);
            challenge.setPoints(getPoints(difficulty));
        }else{
            if(!"OFFERED".equals(challenge.getStatus())){
                throw new ApiException("You cannot change this challenge");
            }

            if(challenge.getAttempts() >= MAX_ATTEMPTS){
                throw new ApiException("You have used all 3 attempts today");
            }

            if(challenge.getDifficulty() == null){
                challenge.setDifficulty("MEDIUM");
                challenge.setPoints(20);
            }

            if(!challenge.getDifficulty().equals(difficulty)){
                throw new ApiException("You cannot change difficulty today");
            }
        }

        String title = generateChallenge(challenge.getTitle(), challenge.getAttempts(), difficulty);

        challenge.setTitle(title);
        challenge.setAttempts(challenge.getAttempts() + 1);

        luckyChallengeRepository.save(challenge);
        return challenge;
    }

    private int getPoints(String difficulty){

        if("EASY".equals(difficulty)){
            return 10;
        }

        if("MEDIUM".equals(difficulty)){
            return 20;
        }

        return 30;
    }

    private String generateChallenge(String previousTitle, Integer attempts, String difficulty){

        List<String> fallbacks;

        String difficultyInstructions;

        if("EASY".equals(difficulty)){
            fallbacks = List.of(
                    "اكتب 3 أشياء ممتن لها وصور الورقة",
                    "ارسم شمسًا وبيتًا وشجرة وصور الرسمة",
                    "اكتب 3 أهداف بسيطة لليوم وصور الورقة"
            );

            difficultyInstructions = "Difficulty: EASY. A very simple task requiring approximately 2-5 minutes. Keep it beginner-friendly.";

        }else if("MEDIUM".equals(difficulty)){
            fallbacks = List.of(
                    "اكتب 5 أهداف لليوم وصور الورقة",
                    "ارسم رسمة تحتوي على 5 عناصر مختلفة وصورها",
                    "اكتب 5 أفكار لتطوير نفسك وصور الورقة"
            );

            difficultyInstructions = "Difficulty: MEDIUM. A moderately challenging task requiring approximately 5-15 minutes and visible effort.";

        }else{
            fallbacks = List.of(
                    "اكتب خطة أسبوعية تشمل 7 أيام ومهمة لكل يوم وصورها",
                    "صمم جدولًا يحتوي على 7 أهداف وخطوات تنفيذها وصوره",
                    "اكتب 10 أفكار لتحسين حياتك مع خطوة عملية لكل فكرة وصور الورقة"
            );

            difficultyInstructions = "Difficulty: HARD. A challenging but realistic task requiring approximately 15-30 minutes and substantial visible effort.";
        }

        String fallback = fallbacks.get(attempts % fallbacks.size());

        if(fallback.equals(previousTitle)){
            fallback = fallbacks.get((attempts + 1) % fallbacks.size());
        }

        String answer = aiService.ask(
                "You generate random daily challenges for a habit-building app. " +
                        "Suggest exactly ONE safe and useful challenge in Arabic. " +
                        difficultyInstructions +
                        " The challenge must be achievable today and verifiable from ONE photo. " +
                        "The photo must show visible evidence of the completed task. " +
                        "Do not suggest tasks requiring proof of elapsed time, exercise, walking, reading, or drinking water. " +
                        "Do not suggest dangerous, expensive, sensitive, or location-dependent tasks. " +
                        "Do not repeat the previous challenge. " +
                        "Return ONLY the challenge description in Arabic, maximum 100 characters.",
                "Previous challenge: " + (previousTitle == null ? "None" : previousTitle) +
                        "\nSelected difficulty: " + difficulty,
                fallback
        );

        String title = answer == null ? "" : answer.trim();

        if(title.isBlank() || title.length() > 100 || title.equals(previousTitle)){
            title = fallback;
        }

        return title;
    }

    @Transactional
    public void acceptChallenge(Integer memberId, Integer challengeId){

        LuckyChallenge challenge = getMemberChallenge(memberId, challengeId);

        if(!challenge.getChallengeDate().equals(LocalDate.now())){
            throw new ApiException("This challenge has expired");
        }

        if(!"OFFERED".equals(challenge.getStatus())){
            throw new ApiException("Challenge already accepted or completed");
        }

        challenge.setStatus("ACCEPTED");
        luckyChallengeRepository.save(challenge);
    }

    public LuckyChallenge getMyChallenge(Integer memberId){

        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }

        LuckyChallenge challenge = luckyChallengeRepository.findLuckyChallengeByMemberIdAndChallengeDate(memberId, LocalDate.now());

        if(challenge == null){
            throw new ApiException("You have no lucky challenge today");
        }

        return challenge;
    }

    @Transactional
    public String submitProof(Integer memberId, Integer challengeId, String proofImage){

        LuckyChallenge challenge = getMemberChallenge(memberId, challengeId);

        if(!challenge.getChallengeDate().equals(LocalDate.now())){
            throw new ApiException("This challenge has expired");
        }

        if(!"ACCEPTED".equals(challenge.getStatus())){
            throw new ApiException("Challenge must be accepted first");
        }

        if(proofImage == null || proofImage.isBlank()){
            throw new ApiException("Proof image is required");
        }

        String answer = aiService.askWithImages(
                "You are an AI image verification system for a daily challenge application. " +
                        "Your task is to determine whether the provided image clearly proves completion of the challenge. " +
                        "Evaluate ONLY what is visible in the image. " +
                        "Do not assume that the user completed something that is not visible. " +
                        "For writing challenges, check that the required number of items is actually written. " +
                        "For drawing challenges, check that a drawing is visible. " +
                        "If the image clearly proves the challenge, return ACCEPTED. " +
                        "If the image clearly does not meet the challenge, return REJECTED. " +
                        "If the image is unclear or there is not enough visual evidence, return ESCALATED. " +
                        "Return exactly two lines in this format:\n" +
                        "DECISION: ACCEPTED or REJECTED or ESCALATED\n" +
                        "REASON: short explanation in Arabic",
                "Challenge: " + challenge.getTitle() +
                        "\nAnalyze the attached image and determine if the challenge was completed.",
                List.of(proofImage),
                "DECISION: ESCALATED\nREASON: تعذر التحقق من الصورة حاليًا"
        );

        String decision = aiService.decision(answer);
        String reason = aiService.field(answer, "REASON");

        if(reason == null || reason.isBlank()){
            reason = "تعذر التحقق من الصورة حاليًا";
        }

        if("ACCEPTED".equals(decision)){
            challenge.setStatus("COMPLETED");
            luckyChallengeRepository.save(challenge);

            int points = challenge.getDifficulty() == null ? 20 : getPoints(challenge.getDifficulty());

            commitmentWeekService.addPoints(
                    challenge.getMember(),
                    points,
                    "LUCKY_CHALLENGE"
            );

        }else if("REJECTED".equals(decision)){
            challenge.setStatus("REJECTED");
            luckyChallengeRepository.save(challenge);

        }else{
            challenge.setStatus("ESCALATED");
            luckyChallengeRepository.save(challenge);
        }

        return reason;
    }

    private LuckyChallenge getMemberChallenge(Integer memberId, Integer challengeId){

        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }

        LuckyChallenge challenge = luckyChallengeRepository.findLuckyChallengeById(challengeId);

        if(challenge == null){
            throw new ApiException("Challenge not found");
        }

        if(!challenge.getMember().getId().equals(memberId)){
            throw new ApiException("This challenge does not belong to the member");
        }

        return challenge;
    }
}
