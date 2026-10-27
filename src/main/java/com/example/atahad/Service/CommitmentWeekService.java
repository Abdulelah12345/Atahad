package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.TodayTaskResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.hibernate.Hibernate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.*;

// weeks are created by the app, not by the user
// a week is Sunday 00:00 to Saturday 23:59:59, the first week of a commitment starts the moment it starts
@Service
@RequiredArgsConstructor
public class CommitmentWeekService {

    private final CommitmentWeekRepository commitmentWeekRepository;
    private final CommitmentRepository commitmentRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final PenaltyRepository penaltyRepository;
    private final GraceDayRepository graceDayRepository;
    private final PointLogRepository pointLogRepository;
    private final MemberRepository memberRepository;
    private final LockService lockService;
    private final WhatsAppService whatsAppService;
    private final ProofRepository proofRepository;

    public static final int TASK_POINTS = 10;
    public static final int FULL_WEEK_POINTS = 30;
    public static final int POINTS_FOR_GRACE_DAY = 150;

    public static final List<String> LEVELS = List.of("BEGINNER", "COMMITTED", "PERSEVERING", "IRON");
    public static final List<Integer> LEVEL_WEEKS = List.of(0, 4, 8, 12); // consecutive full weeks for every level

    // ================= read =================

    // shared with the other services
    public CommitmentWeek getWeekById(Integer id){
        CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(id);
        if(week == null){
            throw new ApiException("Week not found");
        }
        return week;
    }

    // same as getWeekById but only for the owner of the week
    public CommitmentWeek getMyWeek(Integer memberId, Integer id){
        CommitmentWeek week = getWeekById(id);
        getMyCommitment(memberId, week.getCommitment().getId());
        return week;
    }

    public List<CommitmentWeek> getHistory(Integer memberId, Integer commitmentId){
        Commitment commitment = getMyCommitment(memberId, commitmentId);
        return commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(commitment);
    }

    public CommitmentWeek getCurrentWeek(Integer memberId, Integer commitmentId){
        Commitment commitment = getMyCommitment(memberId, commitmentId);
        CommitmentWeek week = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
        if(week == null || week.getWeekEnd().isBefore(LocalDateTime.now())){
            throw new ApiException("This commitment has no running week");
        }
        return week;
    }

    // the home screen: every habit and every goal task of this week with what is left
    public List<TodayTaskResponse> getToday(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        LocalDate today = LocalDate.now();
        String todayName = today.getDayOfWeek().name().substring(0, 3); // SUN, MON ...
        List<TodayTaskResponse> list = new ArrayList<>();

        for(Commitment commitment : commitmentRepository.findCommitmentsByMemberAndStatus(member, "ACTIVE")){
            CommitmentWeek week = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
            if(week == null || !isRunning(week, today)){
                continue; // a goal that did not start yet
            }
            int daysLeft = daysLeft(week, today);
            Object real = Hibernate.unproxy(commitment);
            List<Proof> proofsToday = proofsOn(week, today);

            if(real instanceof Goal goal){
                for(GoalTask task : goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, week.getWeekNumber())){
                    int required = taskRequired(task, week);
                    int remaining = Math.max(0, required - task.getCompletedCount() - task.getExcusedCount() - lostPenalties(week, task).size());
                    boolean hasPlan = task.getPlannedDays() != null && !task.getPlannedDays().isEmpty();
                    boolean planned = hasPlan && task.getPlannedDays().contains(todayName);
                    boolean doneToday = proofsToday.stream().anyMatch(p -> p.getGoalTask() != null && p.getGoalTask().getId().equals(task.getId()));
                    list.add(new TodayTaskResponse(goal.getId(), week.getId(), task.getId(), "GOAL",
                            (goal.getTitle().trim().equals(task.getTitle().trim()) ? task.getTitle() : goal.getTitle() + " - " + task.getTitle()), task.getProofMethod(), required,
                            task.getCompletedCount(), task.getExcusedCount(), remaining, daysLeft,
                            task.getTrackStatus(), task.getAmountPerTime(), goal.getTitle(), task.getTitle(), planned, hasPlan, doneToday));
                }
            }else{
                int remaining = Math.max(0, week.getRequired() - week.getCompleted() - week.getExcusedDays() - lostPenalties(week, null).size());
                boolean hasPlan = week.getPlannedDays() != null && !week.getPlannedDays().isEmpty();
                boolean planned = hasPlan && week.getPlannedDays().contains(todayName);
                boolean doneToday = proofsToday.stream().anyMatch(p -> p.getGoalTask() == null);
                list.add(new TodayTaskResponse(commitment.getId(), week.getId(), null, "HABIT",
                        commitment.getTitle(), commitment.getProofMethod(), week.getRequired(),
                        week.getCompleted(), week.getExcusedDays(), remaining, daysLeft,
                        week.getTrackStatus(), week.getAmountPerDay(), null, null, planned, hasPlan, doneToday));
            }
        }
        return list;
    }

    // ================= starting weeks =================

    // the first week starts now and ends this saturday, so it needs min(times, days left)
    @Transactional
    public CommitmentWeek startFirstWeek(Commitment commitment){
        if(commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment) != null){
            throw new ApiException("This commitment already started");
        }
        LocalDateTime now = LocalDateTime.now();
        return createWeek(commitment, 1, now, endOfWeek(now.toLocalDate()));
    }

    private CommitmentWeek createWeek(Commitment commitment, int weekNumber, LocalDateTime start, LocalDateTime end){
        CommitmentWeek week = new CommitmentWeek();
        week.setCommitment(commitment);
        week.setWeekNumber(weekNumber);
        week.setWeekStart(start);
        week.setWeekEnd(end);
        week.setCompleted(0);
        week.setExcusedDays(0);
        week.setIsFullWeek(false);
        week.setStepsSettlementPending("STEPS".equals(commitment.getProofMethod()));

        int days = daysBetween(start.toLocalDate(), end.toLocalDate());
        Object real = Hibernate.unproxy(commitment);

        if(real instanceof Goal goal){
            int required = 0;
            for(GoalTask task : goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, weekNumber)){
                task.setCompletedCount(0);
                task.setExcusedCount(0);
                task.setTrackStatus("SAFE");
                goalTaskRepository.save(task);
                required += Math.min(task.getTimesPerWeek(), days);
            }
            week.setRequired(required);
            week.setAmountPerDay(null); // goals use the amount of each task
            week.setPlannedDays(new HashSet<>());
        }else if(real instanceof Habit habit){
            week.setRequired(Math.min(habit.getTimesPerWeek(), days));
            week.setAmountPerDay(habit.getBaseAmount());
            week.setPlannedDays(habit.getPlannedDays() == null ? new HashSet<>() : new HashSet<>(habit.getPlannedDays()));
        }
        week.setTrackStatus(week.getRequired() == 0 ? "SETTLED" : "SAFE");
        commitmentWeekRepository.save(week);

        evaluateWeek(week, start.toLocalDate()); // a week that starts on saturday is MUST_TODAY right away
        return week;
    }

    // ================= the daily check =================

    // called every day at 00:00 by the AutomationService, on sunday it also closes the old weeks and opens the new ones
    @Transactional
    public void runDaily(LocalDate today){
        closeDelayedStepWeeks(today);
        if(today.getDayOfWeek() == DayOfWeek.SUNDAY){
            closeWeeksAndStartNew(today);
        }
        for(Commitment commitment : commitmentRepository.findCommitmentsByStatus("ACTIVE")){
            CommitmentWeek week = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
            if(week != null && isRunning(week, today)){
                evaluateWeek(week, today);
            }
        }
    }

    // SAFE, MUST_TODAY or LOST_DAY, the lost times become penalties right away and the app is locked
    @Transactional
    public void evaluateWeek(CommitmentWeek week, LocalDate today){
        Object real = Hibernate.unproxy(week.getCommitment());
        if(real instanceof Goal goal){
            String weekStatus = "SETTLED";
            for(GoalTask task : goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, week.getWeekNumber())){
                weekStatus = worse(weekStatus, evaluateUnit(week, task, today));
            }
            week.setTrackStatus(weekStatus);
        }else{
            week.setTrackStatus(evaluateUnit(week, null, today));
        }
        commitmentWeekRepository.save(week);
    }

    // a unit is the habit week itself, or one task of the goal week
    private String evaluateUnit(CommitmentWeek week, GoalTask task, LocalDate today){
        int missing = missing(week, task);
        String status;

        if(missing <= 0){
            status = "SETTLED";
        }else{
            // One additional day for health-data synchronization, including Saturday's total.
            LocalDate evaluationDay="STEPS".equals(week.getCommitment().getProofMethod()) ? today.minusDays(1) : today;
            int daysLeft = daysLeft(week, evaluationDay);
            if("STEPS".equals(week.getCommitment().getProofMethod())) {
                daysLeft+=proofRepository.countPendingStepReviews(week.getId(),evaluationDay.atStartOfDay());
            }
            if(missing > daysLeft){
                // not enough days left for the times left
                int newLost = missing - daysLeft;
                if(useGraceDay(week, task, today)){
                    newLost--;
                }
                if(newLost > 0){
                    createPenalties(week, task, newLost, "LOST_DAY");
                    status = "LOST_DAY";
                }else{
                    status = daysLeft == 0 ? "SETTLED" : "MUST_TODAY";
                }
            }else if(missing == daysLeft){
                status = "MUST_TODAY";
            }else{
                status = "SAFE";
            }
        }

        if(task != null){
            task.setTrackStatus(status);
            goalTaskRepository.save(task);
        }
        return status;
    }

    // ================= closing the week (sunday 00:00) =================

    private void closeWeeksAndStartNew(LocalDate sunday){
        Map<Integer, Member> members = new HashMap<>();
        Map<Integer, Boolean> allFull = new HashMap<>(); // member id -> every week of the member was full

        for(Commitment commitment : commitmentRepository.findCommitmentsByStatus("ACTIVE")){
            CommitmentWeek last = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
            if(last == null || !last.getWeekEnd().toLocalDate().isBefore(sunday)){
                continue; // not started, or already opened this week
            }
            boolean waitingForSteps=Boolean.TRUE.equals(last.getStepsSettlementPending());
            boolean full = waitingForSteps ? false : closeWeek(last, sunday);
            Member member = commitment.getMember();
            members.put(member.getId(), member);
            allFull.put(member.getId(), allFull.getOrDefault(member.getId(), true) && full);

            startNextWeek(commitment, last, sunday);
        }

        for(Integer memberId : allFull.keySet()){
            // A member with a delayed step week receives one combined level update on Monday.
            boolean waiting=commitmentWeekRepository.findCommitmentWeeksByCommitmentMember(members.get(memberId)).stream()
                    .anyMatch(w->Boolean.TRUE.equals(w.getStepsSettlementPending())
                            && w.getWeekEnd().toLocalDate().equals(sunday.minusDays(1)));
            if(waiting) { continue; }
            updateLevel(members.get(memberId), allFull.get(memberId));
        }
    }

    private void closeDelayedStepWeeks(LocalDate today) {
        Map<String,List<CommitmentWeek>> groups=new LinkedHashMap<>();
        var pending=commitmentWeekRepository.findByStepsSettlementPendingTrueAndWeekEndBefore(today.minusDays(1).atStartOfDay());
        pending.stream().sorted(Comparator.comparing(CommitmentWeek::getWeekEnd)).forEach(w->
                groups.computeIfAbsent(w.getCommitment().getMember().getId()+":"+w.getWeekEnd().toLocalDate(),k->new ArrayList<>()).add(w));
        Set<Integer> blocked=new HashSet<>();
        for(List<CommitmentWeek> group:groups.values()) {
            CommitmentWeek sample=group.get(0);
            Member member=sample.getCommitment().getMember();
            if(blocked.contains(member.getId()) || group.stream().anyMatch(w->
                    proofRepository.countPendingStepReviews(w.getId(),w.getWeekEnd().plusSeconds(1))>0)) {
                blocked.add(member.getId());continue;
            }
            for(CommitmentWeek week:group) {
                closeWeek(week,today);week.setStepsSettlementPending(false);commitmentWeekRepository.save(week);
            }
            boolean full=commitmentWeekRepository.findCommitmentWeeksByCommitmentMember(member).stream()
                    .filter(w->w.getWeekEnd().toLocalDate().equals(sample.getWeekEnd().toLocalDate()))
                    .allMatch(w->Boolean.TRUE.equals(w.getIsFullWeek()));
            updateLevel(member,full);
        }
    }

    // the last chance: the times still missing become penalties, then the week is marked full or not
    private boolean closeWeek(CommitmentWeek week, LocalDate sunday){
        evaluateWeek(week, sunday); // after the end, no days are left

        int lost = lostPenalties(week, null).size();
        Object real = Hibernate.unproxy(week.getCommitment());
        if(real instanceof Goal goal){
            for(GoalTask task : goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, week.getWeekNumber())){
                lost += lostPenalties(week, task).size();
            }
        }
        boolean full = lost == 0 && week.getCompleted() + week.getExcusedDays() >= week.getRequired();
        boolean isGroup = week.getCommitment().getGroupGoal() != null;
        if(isGroup){
            // group losses are not penalties yet, the weekly settlement of the group decides them
            full = full && !"LOST_DAY".equals(week.getTrackStatus());
        }

        week.setIsFullWeek(full);
        week.setTrackStatus(full ? "SETTLED" : "LOST_DAY");
        commitmentWeekRepository.save(week);

        if(full && week.getRequired() > 0){
            addPoints(week.getCommitment().getMember(), FULL_WEEK_POINTS, "FULL_WEEK");
        }
        return full;
    }

    // edits that waited are applied now, a goal ends after its last week
    private void startNextWeek(Commitment commitment, CommitmentWeek last, LocalDate sunday){
        Object real = Hibernate.unproxy(commitment);
        int nextNumber = last.getWeekNumber() + 1;

        GroupGoal groupGoal = commitment.getGroupGoal();
        if(groupGoal != null && groupGoal.getEndDate() != null && sunday.isAfter(groupGoal.getEndDate())){
            commitment.setStatus("ENDED"); // the group goal finished, the settlement ends the goal itself
            commitmentRepository.save(commitment);
            return;
        }

        if(real instanceof Goal goal){
            if(nextNumber > goal.getTotalWeeks()){
                goal.setStatus("ENDED");
                commitmentRepository.save(goal);
                return;
            }
        }else if(real instanceof Habit habit){
            if(habit.getPendingTimesPerWeek() != null){
                habit.setTimesPerWeek(habit.getPendingTimesPerWeek());
                habit.setPendingTimesPerWeek(null);
            }
            if(habit.getPendingBaseAmount() != null){
                habit.setBaseAmount(habit.getPendingBaseAmount());
                habit.setPendingBaseAmount(null);
            }
            habit.setEffectiveFrom(sunday);
            commitmentRepository.save(habit);
        }
        createWeek(commitment, nextNumber, sunday.atStartOfDay(), endOfWeek(sunday));
    }

    // a full week moves the member up, a failed week takes one level down
    private void updateLevel(Member member, boolean full){
        int index = Math.max(0, LEVELS.indexOf(member.getLevel()));
        if(full){
            int weeks = (member.getConsecutiveWeeks() == null ? 0 : member.getConsecutiveWeeks()) + 1;
            member.setConsecutiveWeeks(weeks);
            while(index + 1 < LEVELS.size() && weeks >= LEVEL_WEEKS.get(index + 1)){
                index++;
            }
        }else{
            index = Math.max(0, index - 1);
            member.setConsecutiveWeeks(LEVEL_WEEKS.get(index)); // continues from the start of the new level
        }
        member.setLevel(LEVELS.get(index));
        memberRepository.save(member);
    }

    // ================= called by the other services =================

    // the proof service calls this when a proof is ACCEPTED (goalTaskId is null for habits)
    @Transactional
    public void recordCompletion(Integer weekId, Integer goalTaskId){
        CommitmentWeek week = getWeekById(weekId);
        GoalTask task = getTaskOfWeek(week, goalTaskId);

        week.setCompleted(week.getCompleted() + 1);
        if(task != null){
            task.setCompletedCount(task.getCompletedCount() + 1);
            goalTaskRepository.save(task);
        }
        commitmentWeekRepository.save(week);
        addPoints(week.getCommitment().getMember(), TASK_POINTS, "TASK_DONE");

        afterNewDoneTime(week, task);
    }

    // the excuse service (or the admin) calls this when an excuse is ACCEPTED
    @Transactional
    public void recordExcuse(Integer weekId, Integer goalTaskId){
        CommitmentWeek week = getWeekById(weekId);
        GoalTask task = getTaskOfWeek(week, goalTaskId);

        week.setExcusedDays(week.getExcusedDays() + 1);
        if(task != null){
            task.setExcusedCount(task.getExcusedCount() + 1);
            goalTaskRepository.save(task);
        }
        commitmentWeekRepository.save(week);

        afterNewDoneTime(week, task);
    }

    // if the new time covers a time that was already lost:
    // not paid yet -> the penalty is cancelled, already paid -> a compensation grace day
    private void afterNewDoneTime(CommitmentWeek week, GoalTask task){
        List<Penalty> lost = lostPenalties(week, task);
        int done = task == null ? week.getCompleted() + week.getExcusedDays()
                : task.getCompletedCount() + task.getExcusedCount();
        int required = task == null ? week.getRequired() : taskRequired(task, week);
        Member member = week.getCommitment().getMember();

        if(!lost.isEmpty() && done + lost.size() > required){
            Penalty pending = lost.stream().filter(p -> "PENDING".equals(p.getStatus())).findFirst().orElse(null);
            if(pending != null){
                pending.setStatus("CANCELLED");
                penaltyRepository.save(pending);
                unlockIfNothingPending(member);
            }else{
                for(Penalty paid : lost){
                    if("PAID".equals(paid.getStatus()) && !isCompensated(member, paid)){
                        giveCompensation(member, paid);
                        break;
                    }
                }
            }
        }

        LocalDate today = LocalDate.now();
        if(isRunning(week, today)){
            evaluateWeek(week, today);
        }
    }

    // withdrawal: every time left this week becomes a penalty and the app is locked
    @Transactional
    public int penalizeWithdrawal(Commitment commitment){
        CommitmentWeek week = commitmentWeekRepository.findTopByCommitmentOrderByWeekNumberDesc(commitment);
        LocalDate today = LocalDate.now();
        if(week == null || !isRunning(week, today)){
            return 0;
        }
        int count = 0;
        Object real = Hibernate.unproxy(commitment);
        if(real instanceof Goal goal){
            for(GoalTask task : goalTaskRepository.findGoalTasksByGoalAndWeekNumber(goal, week.getWeekNumber())){
                int missing = missing(week, task);
                if(missing > 0){
                    createPenalties(week, task, missing, "WITHDRAWAL");
                    count += missing;
                }
                task.setTrackStatus("SETTLED");
                goalTaskRepository.save(task);
            }
        }else{
            int missing = missing(week, null);
            if(missing > 0){
                createPenalties(week, null, missing, "WITHDRAWAL");
                count = missing;
            }
        }
        week.setTrackStatus("SETTLED");
        commitmentWeekRepository.save(week);
        return count;
    }

    // a habit can be deleted only if nothing happened in it yet
    public boolean hasProgress(Commitment commitment){
        for(CommitmentWeek week : commitmentWeekRepository.findCommitmentWeeksByCommitmentOrderByWeekNumberDesc(commitment)){
            if(week.getWeekNumber() > 1 || week.getCompleted() > 0 || week.getExcusedDays() > 0
                    || week.getGraceDay() != null || !penaltyRepository.findPenaltiesByCommitmentWeek(week).isEmpty()){
                return true;
            }
        }
        return false;
    }

    // postpone inside this week, it changes the reminders only
    public void changeThisWeekPlan(Integer memberId, Integer weekId, Set<String> plannedDays){
        CommitmentWeek week = getWeekById(weekId);
        if(!week.getCommitment().getMember().getId().equals(memberId)){
            throw new ApiException("You can only change your own week");
        }
        if(!isRunning(week, LocalDate.now())){
            throw new ApiException("This week is not running");
        }
        if(!(Hibernate.unproxy(week.getCommitment()) instanceof Habit)){
            throw new ApiException("Goals plan their days in every task");
        }
        if(plannedDays == null){
            plannedDays = new HashSet<>();
        }
        for(String day : plannedDays){
            if(day == null || !day.matches("^(SUN|MON|TUE|WED|THU|FRI|SAT)$")){
                throw new ApiException("Planned day must be SUN, MON, TUE, WED, THU, FRI or SAT");
            }
        }
        if(plannedDays.size() > week.getRequired()){
            throw new ApiException("You planned more days than the times of this week");
        }
        week.setPlannedDays(new HashSet<>(plannedDays));
        commitmentWeekRepository.save(week);
    }

    // ================= points and grace days =================

    // every 150 personal points become a grace day, if there is room for one
    @Transactional
    public void addPoints(Member member, int points, String reason){
        member.setPoints((member.getPoints() == null ? 0 : member.getPoints()) + points);
        savePointLog(member, points, reason);

        LocalDate today = LocalDate.now();
        while(member.getPoints() >= POINTS_FOR_GRACE_DAY
                && personalGraceDays(member, today) < graceDayCapacity(member.getLevel())){
            createPersonalGraceDay(member, today);
        }
        memberRepository.save(member);
    }

    // the member asks for the grace day himself: the automatic one did not happen because his
    // grace days were full, and now he used one and has room again
    @Transactional
    public GraceDay redeemGraceDay(Member member){
        int points = member.getPoints() == null ? 0 : member.getPoints();
        if(points < POINTS_FOR_GRACE_DAY){
            throw new ApiException("You need " + (POINTS_FOR_GRACE_DAY - points) + " more points for a grace day");
        }
        LocalDate today = LocalDate.now();
        int capacity = graceDayCapacity(member.getLevel());
        if(personalGraceDays(member, today) >= capacity){
            throw new ApiException("You already have " + capacity + " grace days, the max for your level, use one first");
        }
        GraceDay graceDay = createPersonalGraceDay(member, today);
        memberRepository.save(member);
        return graceDay;
    }

    // 150 points become one grace day that expires after 4 weeks
    private GraceDay createPersonalGraceDay(Member member, LocalDate today){
        member.setPoints(member.getPoints() - POINTS_FOR_GRACE_DAY);
        savePointLog(member, -POINTS_FOR_GRACE_DAY, "GRACE_DAY_REDEEMED");

        GraceDay graceDay = new GraceDay();
        graceDay.setSource("PERSONAL_POINTS");
        graceDay.setEarnedAt(today);
        graceDay.setExpiresAt(today.plusWeeks(4));
        graceDay.setMember(member);
        graceDayRepository.save(graceDay);
        return graceDay;
    }

    // the member uses a grace day himself on a habit week (the app also uses one by itself when a time is lost)
    @Transactional
    public void useGraceDayManually(GraceDay graceDay, CommitmentWeek week){
        if(!(Hibernate.unproxy(week.getCommitment()) instanceof Habit)){
            throw new ApiException("For goals the grace day is used by itself when a task loses a time");
        }
        LocalDate today = LocalDate.now();
        if(!isRunning(week, today)){
            throw new ApiException("This week is not running");
        }
        if(week.getGraceDay() != null || usedGraceDayThisWeek(week.getCommitment().getMember(), week)){
            throw new ApiException("Only one grace day can be used in a week");
        }
        boolean hasPendingLoss = false;
        for(Penalty penalty : lostPenalties(week, null)){
            if("PENDING".equals(penalty.getStatus())){
                hasPendingLoss = true;
            }
        }
        if(missing(week, null) <= 0 && !hasPendingLoss){
            throw new ApiException("This week does not need a grace day");
        }

        graceDay.setUsedAt(today);
        graceDay.setCommitmentWeek(week);
        graceDayRepository.save(graceDay);
        week.setGraceDay(graceDay);
        week.setExcusedDays(week.getExcusedDays() + 1);
        commitmentWeekRepository.save(week);

        afterNewDoneTime(week, null); // cancels a lost time that was not paid yet, and updates the status
    }

    private boolean usedGraceDayThisWeek(Member member, CommitmentWeek week){
        LocalDate weekEnd = week.getWeekEnd().toLocalDate();
        LocalDate weekSunday = weekEnd.minusDays(6);
        for(GraceDay graceDay : graceDayRepository.findGraceDaysByMemberId(member.getId())){
            LocalDate usedAt = graceDay.getUsedAt();
            if(usedAt != null && !usedAt.isBefore(weekSunday) && !usedAt.isAfter(weekEnd)){
                return true;
            }
        }
        return false;
    }

    // how many unused grace days a member can keep
    public int graceDayCapacity(String level){
        if("IRON".equals(level)){
            return 3;
        }
        if("PERSEVERING".equals(level)){
            return 2;
        }
        return 1; // BEGINNER and COMMITTED
    }

    // only the days earned from personal points count in the capacity,
    // group days and compensations are given even when the member is full
    public int personalGraceDays(Member member, LocalDate today){
        int count = 0;
        for(GraceDay graceDay : availableGraceDays(member, today)){
            if("PERSONAL_POINTS".equals(graceDay.getSource())){
                count++;
            }
        }
        return count;
    }

    public List<GraceDay> availableGraceDays(Member member, LocalDate today){
        List<GraceDay> list = new ArrayList<>();
        for(GraceDay graceDay : graceDayRepository.findGraceDaysByMemberId(member.getId())){
            if(graceDay.getUsedAt() == null && graceDay.getExpiresAt() != null && !graceDay.getExpiresAt().isBefore(today)){
                list.add(graceDay);
            }
        }
        list.sort(Comparator.comparing(GraceDay::getExpiresAt)); // the one that expires first is used first
        return list;
    }

    // used by itself when a time is lost, one per week at most
    private boolean useGraceDay(CommitmentWeek week, GoalTask task, LocalDate today){
        if(week.getGraceDay() != null){
            return false;
        }
        Member member = week.getCommitment().getMember();
        LocalDate weekEnd = week.getWeekEnd().toLocalDate();
        if(usedGraceDayThisWeek(member, week)){
            return false; // one grace day a week at most
        }
        List<GraceDay> available = availableGraceDays(member, today);
        if(available.isEmpty()){
            return false;
        }
        GraceDay graceDay = available.get(0);
        graceDay.setUsedAt(today.isAfter(weekEnd) ? weekEnd : today);
        graceDay.setCommitmentWeek(week);
        graceDayRepository.save(graceDay);
        week.setGraceDay(graceDay);

        week.setExcusedDays(week.getExcusedDays() + 1);
        if(task != null){
            task.setExcusedCount(task.getExcusedCount() + 1);
        }
        return true;
    }

    private boolean isCompensated(Member member, Penalty penalty){
        String reason = "Compensation for penalty " + penalty.getId();
        for(GraceDay graceDay : graceDayRepository.findGraceDaysByMemberId(member.getId())){
            if(reason.equals(graceDay.getGrantReason())){
                return true;
            }
        }
        return false;
    }

    // added even when the member already has the max number of grace days
    private void giveCompensation(Member member, Penalty penalty){
        GraceDay graceDay = new GraceDay();
        graceDay.setSource("COMPENSATION");
        graceDay.setGrantReason("Compensation for penalty " + penalty.getId());
        graceDay.setEarnedAt(LocalDate.now());
        graceDay.setExpiresAt(LocalDate.now().plusWeeks(4));
        graceDay.setMember(member);
        graceDayRepository.save(graceDay);
    }

    // ================= helpers =================

    private void createPenalties(CommitmentWeek week, GoalTask task, int count, String reason){
        Commitment commitment = week.getCommitment();
        if(commitment.getGroupGoal() != null && reason.equals("LOST_DAY")){
            return; // group losses are decided by the weekly settlement of the group
        }
        BigDecimal amount = task == null ? week.getAmountPerDay() : task.getAmountPerTime();
        Member member = commitment.getMember();
        for(int i = 0; i < count; i++){
            Penalty penalty = new Penalty();
            penalty.setAmount(amount);
            penalty.setReason(reason);
            penalty.setCreatedAt(LocalDateTime.now());
            penalty.setStatus("PENDING");
            penalty.setMember(member);
            penalty.setCommitmentWeek(week);
            penalty.setGoalTask(task);
            penaltyRepository.save(penalty);
        }
        lockService.refresh(member); // locked until the donation is verified

        BigDecimal total = BigDecimal.ZERO;
        for(Penalty pending : penaltyRepository.findPenaltiesByMemberAndStatus(member, "PENDING")){
            total = total.add(pending.getAmount());
        }
        String title = task == null ? commitment.getTitle() : commitment.getTitle() + " - " + task.getTitle();
        whatsAppService.lockMessage(member, title, count, amount, total, reason.equals("WITHDRAWAL"));
    }

    private void unlockIfNothingPending(Member member){
        lockService.refresh(member);
    }

    // times left in a habit week (used by the group board)
    public int remainingTimes(CommitmentWeek week){
        return Math.max(0, missing(week, null));
    }

    public int daysLeftOf(CommitmentWeek week, LocalDate today){
        return daysLeft(week, today);
    }

    // times still needed, after what was done, excused and already lost
    private int missing(CommitmentWeek week, GoalTask task){
        if(task == null){
            return week.getRequired() - week.getCompleted() - week.getExcusedDays() - lostPenalties(week, null).size();
        }
        return taskRequired(task, week) - task.getCompletedCount() - task.getExcusedCount() - lostPenalties(week, task).size();
    }

    // lost or withdrawn times of the unit that were not cancelled
    private List<Penalty> lostPenalties(CommitmentWeek week, GoalTask task){
        List<Penalty> list = new ArrayList<>();
        for(Penalty penalty : penaltyRepository.findPenaltiesByCommitmentWeek(week)){
            boolean sameUnit = task == null ? penalty.getGoalTask() == null
                    : penalty.getGoalTask() != null && penalty.getGoalTask().getId().equals(task.getId());
            boolean isLoss = "LOST_DAY".equals(penalty.getReason()) || "WITHDRAWAL".equals(penalty.getReason());
            if(sameUnit && isLoss && !"CANCELLED".equals(penalty.getStatus())){
                list.add(penalty);
            }
        }
        return list;
    }

    // a task of a short first week needs at most the days of that week
    private int taskRequired(GoalTask task, CommitmentWeek week){
        int days = daysBetween(week.getWeekStart().toLocalDate(), week.getWeekEnd().toLocalDate());
        return Math.min(task.getTimesPerWeek(), days);
    }

    private GoalTask getTaskOfWeek(CommitmentWeek week, Integer goalTaskId){
        if(goalTaskId == null){
            if(Hibernate.unproxy(week.getCommitment()) instanceof Goal){
                throw new ApiException("Goal task id is required for goals");
            }
            return null;
        }
        GoalTask task = goalTaskRepository.findGoalTaskById(goalTaskId);
        if(task == null){
            throw new ApiException("Task not found");
        }
        if(!task.getGoal().getId().equals(week.getCommitment().getId()) || !task.getWeekNumber().equals(week.getWeekNumber())){
            throw new ApiException("This task is not in this week");
        }
        return task;
    }

    private Commitment getMyCommitment(Integer memberId, Integer commitmentId){
        Commitment commitment = commitmentRepository.findCommitmentById(commitmentId);
        if(commitment == null){
            throw new ApiException("Commitment not found");
        }
        if(!commitment.getMember().getId().equals(memberId)){
            throw new ApiException("You can only see your own commitment");
        }
        return commitment;
    }

    private void savePointLog(Member member, int points, String reason){
        PointLog log = new PointLog();
        log.setPoints(points);
        log.setReason(reason);
        log.setCreatedAt(LocalDateTime.now());
        log.setMember(member);
        pointLogRepository.save(log);
    }

    // the proofs of this week whose activity was on that day and were not rejected (accepted or still in review)
    private List<Proof> proofsOn(CommitmentWeek week, LocalDate day){
        LocalDateTime start = day.atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        List<Proof> proofs = new ArrayList<>();
        for(Proof proof : proofRepository.findProofsByCommitmentWeekId(week.getId())){
            LocalDateTime time = proof.getActivityTime();
            if(time != null && !time.isBefore(start) && time.isBefore(end) && !"REJECTED".equals(proof.getResult())){
                proofs.add(proof);
            }
        }
        return proofs;
    }

    private boolean isRunning(CommitmentWeek week, LocalDate day){
        return !day.isBefore(week.getWeekStart().toLocalDate()) && !day.isAfter(week.getWeekEnd().toLocalDate());
    }

    // days left in the week counting today
    private int daysLeft(CommitmentWeek week, LocalDate today){
        LocalDate start = week.getWeekStart().toLocalDate();
        LocalDate end = week.getWeekEnd().toLocalDate();
        LocalDate from = today.isBefore(start) ? start : today;
        if(from.isAfter(end)){
            return 0;
        }
        return daysBetween(from, end);
    }

    // both days counted
    private int daysBetween(LocalDate from, LocalDate to){
        return (int) ChronoUnit.DAYS.between(from, to) + 1;
    }

    private LocalDateTime endOfWeek(LocalDate day){
        return day.with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY)).atTime(23, 59, 59);
    }

    // LOST_DAY > MUST_TODAY > SAFE > SETTLED
    private String worse(String a, String b){
        List<String> order = List.of("SETTLED", "SAFE", "MUST_TODAY", "LOST_DAY");
        return order.indexOf(b) > order.indexOf(a) ? b : a;
    }
}
