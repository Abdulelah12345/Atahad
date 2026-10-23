package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.PlaceVisitRequest;
import com.example.atahad.Dto.In.ProofRequest;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.hibernate.Hibernate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

// geofencing: the phone tells us when the member enters and leaves the place of a LOCATION commitment
// the entry must be inside the place, the times are the server times, and the minutes are counted here
// on the exit the proof is made by itself ("visit:ID") and ProofDecisionService decides it (half of the minutes or more)
@Service
@RequiredArgsConstructor
public class PlaceVisitService {
    private final PlaceVisitRepository placeVisitRepository;
    private final MemberRepository memberRepository;
    private final CommitmentRepository commitmentRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final LockService lockService;
    private final ProofDecisionService proofDecisionService;
    private final ProofService proofService;

    public static final int AUTO_CLOSE_HOURS = 4;

    public PlaceVisit enter(Integer memberId, Integer commitmentId, Integer goalTaskId, PlaceVisitRequest request){
        Member member = getMember(memberId);
        lockService.checkCanAct(member);
        Commitment commitment = commitmentRepository.findCommitmentById(commitmentId);
        if(commitment == null || !commitment.getMember().getId().equals(memberId)){
            throw new ApiException("Commitment not found");
        }
        if(!"ACTIVE".equals(commitment.getStatus())){
            throw new ApiException("This commitment is not active");
        }
        if(commitment.getTargetLatitude() == null || commitment.getTargetLongitude() == null){
            throw new ApiException("Set the place of this commitment first (/commitment/target)");
        }

        // the phone may send the entry twice, the open visit is returned
        PlaceVisit open = placeVisitRepository.findFirstByMemberIdAndCommitmentIdAndStatus(memberId, commitmentId, "OPEN");
        if(open != null){
            return open;
        }

        LocalDateTime now = now();
        CommitmentWeek week = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
        if(week == null || now.isBefore(week.getWeekStart()) || now.isAfter(week.getWeekEnd())){
            throw new ApiException("This commitment has no running week");
        }
        GoalTask task = null;
        if(Hibernate.unproxy(commitment) instanceof Goal goal){
            task = findTask(goal, week, goalTaskId);
        }else if(!"LOCATION".equals(commitment.getProofMethod())){
            throw new ApiException("This commitment is not proved with the location");
        }

        int radius = commitment.getTargetRadiusMeters() == null ? ProofDecisionService.DEFAULT_RADIUS : commitment.getTargetRadiusMeters();
        long distance = Math.round(ProofDecisionService.distanceMeters(request.getLatitude(), request.getLongitude(),
                commitment.getTargetLatitude(), commitment.getTargetLongitude()));
        if(distance > radius){
            throw new ApiException("You are " + distance + " meters from the place, the allowed is " + radius);
        }

        PlaceVisit visit = new PlaceVisit();
        visit.setEnteredAt(now);
        visit.setStatus("OPEN");
        visit.setMember(member);
        visit.setCommitment(commitment);
        visit.setCommitmentWeek(week);
        visit.setGoalTask(task);
        placeVisitRepository.save(visit);
        return visit;
    }

    public PlaceVisit exit(Integer memberId, Integer commitmentId){
        getMember(memberId);
        PlaceVisit visit = placeVisitRepository.findFirstByMemberIdAndCommitmentIdAndStatus(memberId, commitmentId, "OPEN");
        if(visit == null){
            throw new ApiException("No open visit for this commitment");
        }
        LocalDateTime end = now();
        LocalDateTime deadline = deadline(visit);
        close(visit, end.isAfter(deadline) ? deadline : end, end.isAfter(deadline) ? "AUTO_CLOSED" : "CLOSED");
        return visit;
    }

    // every 5 minutes: a visit with no exit (the phone was off) is closed and counted
    @Scheduled(cron = "0 */5 * * * *", zone = "Asia/Riyadh")
    public void autoClose(){
        LocalDateTime now = now();
        for(PlaceVisit visit : placeVisitRepository.findPlaceVisitsByStatus("OPEN")){
            LocalDateTime deadline = deadline(visit);
            if(!now.isBefore(deadline)){
                close(visit, deadline, "AUTO_CLOSED");
            }
        }
    }

    public List<PlaceVisit> getMyVisits(Integer memberId){
        getMember(memberId);
        return placeVisitRepository.findPlaceVisitsByMemberIdOrderByEnteredAtDesc(memberId);
    }

    // ================= helpers =================

    // 4 hours after the entry, or 23:50 of the same day so it is counted before the daily check at 00:00
    private LocalDateTime deadline(PlaceVisit visit){
        LocalDateTime hours = visit.getEnteredAt().plusHours(AUTO_CLOSE_HOURS);
        LocalDateTime dayEnd = visit.getEnteredAt().toLocalDate().atTime(23, 50);
        return hours.isBefore(dayEnd) ? hours : dayEnd;
    }

    private void close(PlaceVisit visit, LocalDateTime exitedAt, String status){
        if(exitedAt.isBefore(visit.getEnteredAt())){
            exitedAt = visit.getEnteredAt();
        }
        visit.setExitedAt(exitedAt);
        visit.setMinutes((int) Duration.between(visit.getEnteredAt(), exitedAt).toMinutes());
        visit.setStatus(status);
        placeVisitRepository.save(visit);

        // the proof, with the same rules as a proof sent by the member (one a day, inside the week, not locked ...)
        ProofRequest request = new ProofRequest();
        request.setType("LOCATION");
        request.setActivityTime(visit.getEnteredAt());
        request.setEvidenceData("visit:" + visit.getId());
        try{
            if(visit.getGoalTask() == null){
                proofDecisionService.addHabitProof(visit.getMember().getId(), visit.getCommitmentWeek().getId(), request);
            }else{
                proofService.addGoalTaskProof(visit.getMember().getUser().getId(), visit.getGoalTask().getId(),
                        visit.getCommitmentWeek().getId(), request);
            }
        }catch(ApiException e){
            PlaceVisit saved = placeVisitRepository.findPlaceVisitById(visit.getId());
            if(saved != null){
                visit = saved;
            }
            visit.setNote(e.getMessage() == null ? null : (e.getMessage().length() > 255 ? e.getMessage().substring(0, 255) : e.getMessage()));
            placeVisitRepository.save(visit);
        }
    }

    // the LOCATION task of this week: the one sent, or the only one with times left
    private GoalTask findTask(Goal goal, CommitmentWeek week, Integer goalTaskId){
        if(goalTaskId != null){
            GoalTask task = goalTaskRepository.findGoalTaskById(goalTaskId);
            if(task == null || !task.getGoal().getId().equals(goal.getId()) || !task.getWeekNumber().equals(week.getWeekNumber())){
                throw new ApiException("This task is not in this week");
            }
            if(!"LOCATION".equals(task.getProofMethod())){
                throw new ApiException("This task is not proved with the location");
            }
            return task;
        }
        GoalTask found = null;
        for(GoalTask task : goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, week.getWeekNumber())){
            boolean timesLeft = task.getTimesPerWeek() - task.getCompletedCount() - task.getExcusedCount() > 0;
            if("LOCATION".equals(task.getProofMethod()) && timesLeft){
                if(found != null){
                    throw new ApiException("This week has more than one location task, send goalTaskId");
                }
                found = task;
            }
        }
        if(found == null){
            throw new ApiException("No location task left this week");
        }
        return found;
    }

    private Member getMember(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return member;
    }

    private LocalDateTime now(){
        return LocalDateTime.now(ZoneId.of("Asia/Riyadh"));
    }
}
