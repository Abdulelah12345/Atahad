package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

// personal points are added in CommitmentWeekService, the group points are here
@Service
@RequiredArgsConstructor
public class PointLogService {
    private final PointLogRepository pointLogRepository;
    private final GroupRepository groupRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final GraceDayRepository graceDayRepository;
    private final MemberRepository memberRepository;

    public static final int GOLDEN_WEEK_POINTS = 50;          // every member finished the week
    public static final int MATCH_ALL_DONE_POINTS = 30;       // every member finished the match week
    public static final int MATCH_WIN_POINTS = 100;
    public static final int LEAST_PROCRASTINATION_POINTS = 50;

    public List<PointLog> getMyPointLogs(Integer memberId){
        if(memberRepository.findMemberById(memberId) == null){
            throw new ApiException("Member not found");
        }
        return pointLogRepository.findPointLogsByMemberIdOrderByCreatedAtDesc(memberId);
    }

    public List<PointLog> getGroupPointLogs(Integer groupId, Integer memberId){
        GroupMember groupMember = groupMemberRepository.findGroupMemberByGroupIdAndMemberId(groupId, memberId);
        if(groupMember == null || !"ACTIVE".equals(groupMember.getStatus())){
            throw new ApiException("You are not in this group");
        }
        return pointLogRepository.findPointLogsByGroupIdOrderByCreatedAtDesc(groupId);
    }

    // when the group reaches its points (300), every active member gets a grace day,
    // even if he already has the max number of grace days, because it is a reward for the whole group
    @Transactional
    public void addGroupPoints(Group group, int points, String reason){
        group.setPoints((group.getPoints() == null ? 0 : group.getPoints()) + points);
        saveLog(group, points, reason);

        int needed = group.getPointsForGraceDay() == null ? 300 : group.getPointsForGraceDay();
        while(group.getPoints() >= needed){
            group.setPoints(group.getPoints() - needed);
            saveLog(group, -needed, "GRACE_DAY_REDEEMED");

            for(GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupIdAndStatus(group.getId(), "ACTIVE")){
                GraceDay graceDay = new GraceDay();
                graceDay.setSource("GROUP_POINTS");
                graceDay.setGrantReason("Group reward: " + group.getName());
                graceDay.setEarnedAt(LocalDate.now());
                graceDay.setExpiresAt(LocalDate.now().plusWeeks(4));
                graceDay.setMember(groupMember.getMember());
                graceDayRepository.save(graceDay);
            }
        }
        groupRepository.save(group);
    }

    private void saveLog(Group group, int points, String reason){
        PointLog log = new PointLog();
        log.setPoints(points);
        log.setReason(reason);
        log.setCreatedAt(LocalDateTime.now());
        log.setGroup(group);
        pointLogRepository.save(log);
    }
}
