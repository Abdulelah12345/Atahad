package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GroupCreateRequest;
import com.example.atahad.Dto.In.GroupUpdateRequest;
import com.example.atahad.Dto.Out.GroupInviteResponse;
import com.example.atahad.Dto.Out.GroupResponse;
import com.example.atahad.Entity.Group;
import com.example.atahad.Entity.GroupGoal;
import com.example.atahad.Entity.GroupMember;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.GroupGoalRepository;
import com.example.atahad.Repository.GroupMemberRepository;
import com.example.atahad.Repository.GroupRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class GroupService {

    private final GroupRepository groupRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final GroupGoalRepository groupGoalRepository;
    private final GroupAccessService groupAccessService;

    // admin
    public List<GroupResponse> getAllGroups() {
        List<Group> groups = groupRepository.findAll();
        List<GroupResponse> groupResponses = new ArrayList<>();
        for (int i = 0; i < groups.size(); i++) {
            groupResponses.add(convertToDTO(groups.get(i)));
        }
        return groupResponses;
    }

    public GroupResponse getGroupById(Integer id) {
        Group group = groupRepository.findGroupById(id);
        if (group == null) {
            throw new ApiException("Group not found");
        }
        return convertToDTO(group);
    }

    @Transactional
    public GroupResponse addGroup(Integer memberId, GroupCreateRequest dto) {
        Member member = groupAccessService.getMember(memberId);
        groupAccessService.checkNotBanned(member);

        Group group = new Group();
        group.setName(dto.getName());
        group.setDescription(dto.getDescription());
        group.setCreatedAt(LocalDateTime.now());
        group.setPoints(0);
        group.setPointsForGraceDay(300);
        group.setStatus("ACTIVE");

        String inviteCode;
        do {
            inviteCode = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        } while (groupRepository.findGroupByInviteCode(inviteCode) != null);
        group.setInviteCode(inviteCode);
        groupRepository.save(group);

        GroupMember groupMember = new GroupMember();
        groupMember.setGroup(group);
        groupMember.setMember(member);
        groupMember.setRole("OWNER");
        groupMember.setPoints(0);
        groupMember.setFailureCount(0);
        groupMember.setStatus("ACTIVE");
        groupMember.setJoinedAt(LocalDateTime.now());
        groupMemberRepository.save(groupMember);
        return convertToDTO(group);
    }

    public void updateGroup(Integer groupId, Integer memberId, GroupUpdateRequest dto) {
        GroupMember owner = groupAccessService.checkOwner(groupId, memberId);
        Group group = owner.getGroup();
        group.setName(dto.getName());
        group.setDescription(dto.getDescription());
        groupRepository.save(group);
    }

    // the code is shared as text or as a QR code that the app draws
    public GroupInviteResponse getInvite(Integer groupId, Integer memberId) {
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        String code = groupMember.getGroup().getInviteCode();
        return new GroupInviteResponse(code, "atahad://join/" + code);
    }

    // a new code, the old one stops working
    public GroupInviteResponse resetInviteCode(Integer groupId, Integer memberId) {
        GroupMember owner = groupAccessService.checkOwner(groupId, memberId);
        Group group = owner.getGroup();
        String inviteCode;
        do {
            inviteCode = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        } while (groupRepository.findGroupByInviteCode(inviteCode) != null);
        group.setInviteCode(inviteCode);
        groupRepository.save(group);
        return new GroupInviteResponse(inviteCode, "atahad://join/" + inviteCode);
    }

    // the group is archived and not deleted, its settlements and penalties stay in the history
    @Transactional
    public void deleteGroup(Integer groupId, Integer memberId) {
        GroupMember owner = groupAccessService.checkOwner(groupId, memberId);
        Group group = owner.getGroup();
        if (groupGoalRepository.findGroupGoalByGroupIdAndStatus(groupId, "ACTIVE") != null) {
            throw new ApiException("The group has a running goal, wait until it ends");
        }
        for (GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupId, "ACTIVE")) {
            groupMember.setStatus("LEFT");
            groupMemberRepository.save(groupMember);
        }
        group.setStatus("ARCHIVED");
        group.setInviteCode(null);
        groupRepository.save(group);
    }

    public GroupResponse convertToDTO(Group group) {
        GroupGoal goal = groupGoalRepository.findGroupGoalByGroupIdAndStatus(group.getId(), "ACTIVE");
        return new GroupResponse(
                group.getId(),
                group.getName(),
                group.getDescription(),
                group.getInviteCode(),
                group.getCreatedAt(),
                groupMemberRepository.findGroupMembersByGroupIdAndStatus(group.getId(), "ACTIVE").size(),
                group.getPoints(),
                group.getPointsForGraceDay(),
                group.getStatus(),
                goal == null ? null : goal.getTitle()
        );
    }
}
