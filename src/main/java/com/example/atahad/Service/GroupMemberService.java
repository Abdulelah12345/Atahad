package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.GroupMemberResponse;
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

@Service
@RequiredArgsConstructor
public class GroupMemberService {

    private final GroupMemberRepository groupMemberRepository;
    private final GroupRepository groupRepository;
    private final GroupGoalRepository groupGoalRepository;
    private final GroupAccessService groupAccessService;
    private final GroupGoalService groupGoalService;

    public List<GroupMemberResponse> getGroupMembers(Integer groupId) {
        groupAccessService.getGroup(groupId);
        List<GroupMemberResponse> list = new ArrayList<>();
        for (GroupMember groupMember : groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupId, "ACTIVE")) {
            list.add(convertToDTO(groupMember));
        }
        return list;
    }

    public List<GroupMemberResponse> getMemberGroups(Integer memberId) {
        groupAccessService.getMember(memberId);
        List<GroupMemberResponse> list = new ArrayList<>();
        for (GroupMember groupMember : groupMemberRepository.findGroupMembersByMemberIdAndStatus(memberId, "ACTIVE")) {
            list.add(convertToDTO(groupMember));
        }
        return list;
    }

    // by the invite code or the QR code
    @Transactional
    public void joinGroup(Integer memberId, String inviteCode) {
        Group group = groupRepository.findGroupByInviteCode(inviteCode);
        if (group == null || "ARCHIVED".equals(group.getStatus())) {
            throw new ApiException("Invalid invite code");
        }
        addToGroup(group, groupAccessService.getMember(memberId));
    }

    // the owner adds a member directly
    @Transactional
    public void addMemberDirectly(Integer groupId, Integer ownerId, Integer memberId) {
        GroupMember owner = groupAccessService.checkOwner(groupId, ownerId);
        addToGroup(owner.getGroup(), groupAccessService.getMember(memberId));
    }

    // if the group has a goal now, the new member starts it from today
    private void addToGroup(Group group, Member member) {
        groupAccessService.checkNotBanned(member);
        GroupMember groupMember = groupMemberRepository.findGroupMemberByGroupIdAndMemberId(group.getId(), member.getId());
        if (groupMember != null && "ACTIVE".equals(groupMember.getStatus())) {
            throw new ApiException("Member already joined this group");
        }
        if (groupMember != null && "KICKED".equals(groupMember.getStatus())) {
            throw new ApiException("This member was removed from this group and cannot join it again");
        }
        if (groupAccessService.activeMembersCount(group.getId()) >= GroupAccessService.MAX_MEMBERS) {
            throw new ApiException("Group is full, maximum " + GroupAccessService.MAX_MEMBERS + " members");
        }

        if (groupMember == null) { // LEFT before -> the same row comes back
            groupMember = new GroupMember();
            groupMember.setGroup(group);
            groupMember.setMember(member);
            groupMember.setPoints(0);
            groupMember.setFailureCount(0);
        }
        groupMember.setRole("MEMBER");
        groupMember.setStatus("ACTIVE");
        groupMember.setJoinedAt(LocalDateTime.now());
        groupMemberRepository.save(groupMember);

        GroupGoal goal = groupGoalRepository.findGroupGoalByGroupIdAndStatus(group.getId(), "ACTIVE");
        if (goal != null) {
            groupGoalService.addMemberCommitment(goal, member);
        }
        groupAccessService.systemMessage(group, groupAccessService.nameOf(member) + " joined the group");
    }

    // leaving in the middle of a goal is like a withdrawal: the times left this week become penalties
    @Transactional
    public void leaveGroup(Integer groupId, Integer memberId) {
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        if ("OWNER".equals(groupMember.getRole())) {
            throw new ApiException("Group owner cannot leave the group, archive it instead");
        }
        groupMember.setStatus("LEFT");
        groupMemberRepository.save(groupMember);
        groupGoalService.removeMemberCommitment(groupMember.getGroup(), groupMember.getMember(), true);
        groupAccessService.systemMessage(groupMember.getGroup(), groupAccessService.nameOf(groupMember.getMember()) + " left the group");
    }

    // used by the settlement (second failure) and the refusal ladder
    @Transactional
    public void kick(GroupMember groupMember, String reason) {
        removeFromGroup(groupMember, "KICKED");
        groupAccessService.systemMessage(groupMember.getGroup(), groupAccessService.nameOf(groupMember.getMember()) + " was removed: " + reason);
    }

    // the member deactivated his account: he leaves without penalties, an empty group is archived
    @Transactional
    public void leaveBecauseDeactivated(GroupMember groupMember) {
        removeFromGroup(groupMember, "LEFT");
        Group group = groupMember.getGroup();
        if (groupAccessService.activeMembersCount(group.getId()) == 0) {
            GroupGoal goal = groupGoalRepository.findGroupGoalByGroupIdAndStatus(group.getId(), "ACTIVE");
            if (goal != null) {
                groupGoalService.endGoal(goal);
            }
            group.setStatus("ARCHIVED");
            group.setInviteCode(null);
            groupRepository.save(group);
        } else {
            groupAccessService.systemMessage(group, groupAccessService.nameOf(groupMember.getMember()) + " left the group");
        }
    }

    // when the owner goes out, the oldest member becomes the owner
    private void removeFromGroup(GroupMember groupMember, String status) {
        boolean wasOwner = "OWNER".equals(groupMember.getRole());
        groupMember.setStatus(status);
        groupMember.setRole("MEMBER");
        groupMemberRepository.save(groupMember);
        if (wasOwner) {
            GroupMember next = null;
            for (GroupMember other : groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupMember.getGroup().getId(), "ACTIVE")) {
                if (next == null || other.getJoinedAt().isBefore(next.getJoinedAt())) {
                    next = other;
                }
            }
            if (next != null) {
                next.setRole("OWNER");
                groupMemberRepository.save(next);
            }
        }
        groupGoalService.removeMemberCommitment(groupMember.getGroup(), groupMember.getMember(), false);
    }

    public GroupMemberResponse convertToDTO(GroupMember groupMember) {
        return new GroupMemberResponse(
                groupMember.getGroup().getId(),
                groupMember.getGroup().getName(),
                groupMember.getMember().getId(),
                groupAccessService.nameOf(groupMember.getMember()),
                groupMember.getPoints(),
                groupMember.getRole(),
                groupMember.getJoinedAt(),
                groupMember.getStatus(),
                groupMember.getFailureCount()
        );
    }
}
