package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.GroupAlertResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.GroupAlertRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// the loud alert (siren) a member sends to a friend who did not do his task yet
// rules: one alert a day from the same sender to the same friend, nothing after midnight,
// two alerts or more on the same day become a collective alert, no alerts for a friend who sent an excuse
@Service
@RequiredArgsConstructor
public class GroupAlertService {
    private final GroupAlertRepository groupAlertRepository;
    private final GroupAccessService groupAccessService;
    private final GroupGoalService groupGoalService;
    private final CommitmentWeekService commitmentWeekService;
    private final AiService aiService;

    public static final int QUIET_UNTIL_HOUR = 7; // from 00:00 to 06:59 no alerts

    @Transactional
    public GroupAlertResponse send(Integer groupId, Integer senderId, Integer receiverId){
        if(senderId.equals(receiverId)){
            throw new ApiException("You cannot alert yourself");
        }
        GroupMember sender = groupAccessService.getActiveMembership(groupId, senderId);
        GroupMember receiver = groupAccessService.getActiveMembership(groupId, receiverId);
        Group group = sender.getGroup();

        LocalDateTime now = LocalDateTime.now();
        if(now.getHour() < QUIET_UNTIL_HOUR){
            throw new ApiException("No alerts after midnight, try again after " + QUIET_UNTIL_HOUR + " AM");
        }

        GroupGoal goal = groupGoalService.getActiveGoal(groupId, senderId);
        CommitmentWeek week = groupGoalService.currentWeek(goal, receiver.getMember());
        if(week == null || commitmentWeekService.remainingTimes(week) == 0){
            throw new ApiException("Your friend already finished this week");
        }
        if(groupGoalService.hasExcuse(week)){
            throw new ApiException("Your friend sent an excuse, alerts are stopped");
        }

        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        if(!groupAlertRepository.findGroupAlertsBySenderIdAndReceiverIdAndSentAtAfter(sender.getId(), receiver.getId(), startOfDay).isEmpty()){
            throw new ApiException("You already alerted this friend today");
        }

        List<GroupAlert> today = groupAlertRepository.findGroupAlertsByReceiverIdAndSentAtAfterOrderBySentAtDesc(receiver.getId(), startOfDay);
        boolean collective = !today.isEmpty();
        if(collective){
            for(GroupAlert old : today){
                old.setIsCollective(true);
                groupAlertRepository.save(old);
            }
        }

        int remaining = commitmentWeekService.remainingTimes(week);
        int daysLeft = commitmentWeekService.daysLeftOf(week, LocalDate.now());
        String receiverName = groupAccessService.nameOf(receiver.getMember());
        String senderName = groupAccessService.nameOf(sender.getMember());
        String fallback = collective
                ? (today.size() + 1) + " من الشلة ينبهونك يا " + receiverName + "! باقي لك " + remaining + " مرات في " + goal.getTitle()
                : senderName + " ينبهك يا " + receiverName + ": باقي لك " + remaining + " مرات في " + goal.getTitle() + " وباقي " + daysLeft + " أيام";

        String text = aiService.ask(
                "You write one short push notification (max 20 words) that wakes up a friend to do his task. "
                        + aiService.tone(group.getHumorLevel()),
                "Friend: " + receiverName + "\nSent by: " + senderName + (collective ? " and " + today.size() + " other friends" : "")
                        + "\nTask: " + goal.getTitle() + "\nTimes left this week: " + remaining + "\nDays left: " + daysLeft,
                fallback);

        GroupAlert alert = new GroupAlert();
        alert.setMessage(text.length() > 500 ? text.substring(0, 500) : text);
        alert.setIsCollective(collective);
        alert.setSentAt(now);
        alert.setSender(sender);
        alert.setReceiver(receiver);
        groupAlertRepository.save(alert);
        // TODO: send it with Firebase Cloud Messaging and the siren sound
        return toResponse(alert);
    }

    // the alerts the member got today in this group
    public List<GroupAlertResponse> getMyAlertsToday(Integer memberId, Integer groupId){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        List<GroupAlertResponse> list = new ArrayList<>();
        for(GroupAlert alert : groupAlertRepository.findGroupAlertsByReceiverIdAndSentAtAfterOrderBySentAtDesc(groupMember.getId(), LocalDate.now().atStartOfDay())){
            list.add(toResponse(alert));
        }
        return list;
    }

    private GroupAlertResponse toResponse(GroupAlert alert){
        return new GroupAlertResponse(alert.getId(), alert.getSender().getGroup().getName(),
                groupAccessService.nameOf(alert.getSender().getMember()), alert.getMessage(),
                alert.getIsCollective(), alert.getSentAt());
    }
}
