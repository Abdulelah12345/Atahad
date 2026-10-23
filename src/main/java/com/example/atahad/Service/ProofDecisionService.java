package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.ProofRequest;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.ExcuseRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.PlaceVisitRepository;
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
    private final QuizService quizService;
    private final ProofChallengeService proofChallengeService;
    private final PlaceVisitRepository placeVisitRepository;

    public static final int DEFAULT_RADIUS = 150;
    public static final double VISIT_SHARE = 0.5; // a visit counts with half of the minutes

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
        if("LOCATION".equals(commitment.getProofMethod()) && commitment.getTargetLatitude() == null){
            throw new ApiException("Set the place of this commitment first (/commitment/target)");
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
    // every proof is checked by the method of its commitment only:
    // LOCATION -> distance from the place, TIMER -> the minutes, QUIZ -> the answers, PHOTO and PLATFORM -> the AI looks at the image
    @Transactional
    public void decide(Proof proof){
        proof.setProcessingStatus("PROCESSING");
        proofRepository.save(proof);

        Commitment commitment = proof.getCommitmentWeek().getCommitment();
        switch(proof.getType()){
            case "LOCATION" -> decideLocation(proof, commitment);
            case "TIMER" -> decideTimer(proof, commitment);
            case "QUIZ" -> {
                String failed = quizService.grade(proof);
                applyDecision(proof, failed == null ? "ACCEPTED" : "REJECTED", failed == null ? "جاوب الاختبار صح" : failed);
            }
            default -> decideImage(proof, commitment); // PHOTO and PLATFORM
        }
    }

    // evidence = "visit:ID" made by the geofencing (PlaceVisitService), or "latitude,longitude" from the phone GPS
    // accepted inside the radius of the place (150 m by default)
    private void decideLocation(Proof proof, Commitment commitment){
        if(proof.getEvidenceData() != null && proof.getEvidenceData().trim().startsWith("visit:")){
            decideVisit(proof, commitment);
            return;
        }
        if(commitment.getTargetMinutes() != null){
            applyDecision(proof, "REJECTED", "هذا الالتزام له مدة، الإثبات ينحسب من دخولك وطلوعك من المكان");
            return;
        }
        if(commitment.getTargetLatitude() == null || commitment.getTargetLongitude() == null){
            applyDecision(proof, "ESCALATED", "ما فيه مكان محدد لهالالتزام، بيراجعه الأدمن");
            return;
        }
        double[] point = parsePoint(proof.getEvidenceData());
        if(point == null){
            applyDecision(proof, "REJECTED", "الموقع لازم يكون مثل 24.7136,46.6753");
            return;
        }
        int radius = commitment.getTargetRadiusMeters() == null ? DEFAULT_RADIUS : commitment.getTargetRadiusMeters();
        long distance = Math.round(distanceMeters(point[0], point[1], commitment.getTargetLatitude(), commitment.getTargetLongitude()));
        String place = commitment.getTargetPlaceName() == null ? "المكان" : commitment.getTargetPlaceName();
        if(distance <= radius){
            applyDecision(proof, "ACCEPTED", "كان في " + place + " (" + distance + " متر)");
        }else{
            applyDecision(proof, "REJECTED", "بعيد عن " + place + " بـ " + distance + " متر، المسموح " + radius + " متر");
        }
    }

    // a visit is accepted with half of the minutes or more, a visit closed by itself (the phone was off) is counted
    private void decideVisit(Proof proof, Commitment commitment){
        PlaceVisit visit = null;
        try{
            visit = placeVisitRepository.findPlaceVisitById(Integer.valueOf(proof.getEvidenceData().trim().substring(6).trim()));
        }catch(NumberFormatException ignored){
        }
        if(visit == null || !visit.getCommitmentWeek().getId().equals(proof.getCommitmentWeek().getId())){
            applyDecision(proof, "REJECTED", "الزيارة مو لهالأسبوع");
            return;
        }
        boolean sameTask = visit.getGoalTask() == null ? proof.getGoalTask() == null
                : proof.getGoalTask() != null && visit.getGoalTask().getId().equals(proof.getGoalTask().getId());
        if(!sameTask){
            applyDecision(proof, "REJECTED", "الزيارة مو لهالمهمة");
            return;
        }
        if("OPEN".equals(visit.getStatus())){
            applyDecision(proof, "REJECTED", "الزيارة للحين ما خلصت");
            return;
        }
        if(visit.getUsedAt() != null){
            applyDecision(proof, "REJECTED", "الزيارة مستخدمة قبل");
            return;
        }
        visit.setUsedAt(LocalDateTime.now(ZoneId.of("Asia/Riyadh")));
        visit.setProofId(proof.getId());
        placeVisitRepository.save(visit);

        String place = commitment.getTargetPlaceName() == null ? "المكان" : commitment.getTargetPlaceName();
        Integer target = commitment.getTargetMinutes();
        if("AUTO_CLOSED".equals(visit.getStatus())){
            applyDecision(proof, "ACCEPTED", "دخلت " + place + " والجوال ما أرسل الطلوع، انحسبت لك");
            return;
        }
        if(target == null){
            applyDecision(proof, "ACCEPTED", "دخلت " + place + " (" + visit.getMinutes() + " دقيقة)");
            return;
        }
        int needed = (int) Math.ceil(target * VISIT_SHARE);
        if(visit.getMinutes() >= needed){
            applyDecision(proof, "ACCEPTED", "جلست " + visit.getMinutes() + " دقيقة في " + place);
        }else{
            applyDecision(proof, "REJECTED", "جلست " + visit.getMinutes() + " دقيقة بس، أقل شي " + needed + " دقيقة (نص " + target + ")");
        }
    }

    // evidence = the minutes from the app timer, like "45"
    private void decideTimer(Proof proof, Commitment commitment){
        if(commitment.getTargetMinutes() == null){
            applyDecision(proof, "ESCALATED", "ما فيه مدة محددة لهالالتزام، بيراجعه الأدمن");
            return;
        }
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile("(\\d+)").matcher(proof.getEvidenceData() == null ? "" : proof.getEvidenceData());
        if(!matcher.find()){
            applyDecision(proof, "REJECTED", "المدة لازم تكون بالدقايق، مثل 45");
            return;
        }
        int minutes = Integer.parseInt(matcher.group(1));
        if(minutes >= commitment.getTargetMinutes()){
            applyDecision(proof, "ACCEPTED", minutes + " دقيقة من " + commitment.getTargetMinutes());
        }else{
            applyDecision(proof, "REJECTED", minutes + " دقيقة بس، المطلوب " + commitment.getTargetMinutes());
        }
    }

    // PHOTO: a camera photo or a live clip of the activity, PLATFORM: a screenshot from the app or website of the activity
    private void decideImage(Proof proof, Commitment commitment){
        String task = proof.getGoalTask() == null ? commitment.getTitle() : commitment.getTitle() + " - " + proof.getGoalTask().getTitle();
        boolean platform = "PLATFORM".equals(proof.getType());
        if(!platform){
            ProofChallengeService.Checked checked = proofChallengeService.check(proof);
            if(checked != null){
                decideClip(proof, task, checked);
                return;
            }
        }
        String rules = platform
                ? "The image is a screenshot from an app or a website (like Duolingo, LeetCode, a reading app, a fitness app). "
                  + "ACCEPTED when it shows the task was done on the activity date. REJECTED when it shows another activity, another day, or looks edited. "
                : "The image is a camera photo of the person doing the task. "
                  + "REJECTED when it clearly does not match the task, or it is a screenshot, from the internet, or of another day. ";
        String answer = aiService.askWithImages(
                "You check proofs in a commitment app. " + rules
                        + "ESCALATED when you are not sure. Answer only with two lines:\n"
                        + "DECISION: ACCEPTED or REJECTED or ESCALATED\nREASON: one short sentence in Arabic",
                "Task: " + task + "\nProof type: " + proof.getType() + "\nActivity time: " + proof.getActivityTime()
                        + "\nThe image is attached.",
                List.of(proof.getEvidenceData()),
                "DECISION: ESCALATED\nREASON: الذكاء الاصطناعي غير متاح الحين، بيراجعه الأدمن");
        applyDecision(proof, aiService.decision(answer), aiService.field(answer, "REASON"));
    }

    // a live clip (or photo) from the app camera with a challenge: the AI checks the activity and the challenge
    private void decideClip(Proof proof, String task, ProofChallengeService.Checked checked){
        if(checked.error() != null){
            applyDecision(proof, "REJECTED", checked.error());
            return;
        }
        String answer = aiService.askWithMedia(
                "You check proofs in a commitment app. The file is a short live clip (or a photo) from the app camera. "
                        + "The person must be doing the task in it, and must do this challenge in the same clip: \"" + checked.challenge() + "\". "
                        + "If the challenge is to say a number, listen to the sound. "
                        + "ACCEPTED only when the task and the challenge are both clear. REJECTED when the challenge is missing or wrong, "
                        + "or the clip is not of the task, or looks like a recording of a screen. ESCALATED when you are not sure. "
                        + "Answer only with two lines:\n"
                        + "DECISION: ACCEPTED or REJECTED or ESCALATED\nREASON: one short sentence in Arabic",
                "Task: " + task + "\nChallenge: " + checked.challenge() + "\nThe file is attached.",
                checked.mediaUrl(),
                "DECISION: ESCALATED\nREASON: الذكاء الاصطناعي غير متاح الحين، بيراجعه الأدمن");
        applyDecision(proof, aiService.decision(answer), aiService.field(answer, "REASON"));
    }

    private double[] parsePoint(String text){
        if(text == null){
            return null;
        }
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile("(-?\\d+(?:\\.\\d+)?)\\s*,\\s*(-?\\d+(?:\\.\\d+)?)").matcher(text);
        if(!matcher.find()){
            return null;
        }
        double lat = Double.parseDouble(matcher.group(1));
        double lng = Double.parseDouble(matcher.group(2));
        if(Math.abs(lat) > 90 || Math.abs(lng) > 180){
            return null;
        }
        return new double[]{lat, lng};
    }

    // haversine: the distance on the earth between two points
    public static double distanceMeters(double lat1, double lng1, double lat2, double lng2){
        double earth = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return earth * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
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
