package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.GroupMemberResponse;
import com.example.atahad.Entity.Group;
import com.example.atahad.Entity.GroupMember;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.GroupMemberRepository;
import com.example.atahad.Repository.GroupRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class GroupMemberService {

    private final GroupMemberRepository groupMemberRepository;
    private final GroupRepository groupRepository;
    private final MemberRepository memberRepository;

    public List<GroupMemberResponse> getGroupMembers(Integer groupId) {

        Group group = groupRepository.findGroupById(groupId);

        if (group == null) {
            throw new ApiException("Group not found");
        }

        List<GroupMember> groupMembers =
                groupMemberRepository.findGroupMembersByGroupId(groupId);

        List<GroupMemberResponse> groupMemberResponses = new ArrayList<>();

        for (int i = 0; i < groupMembers.size(); i++) {
            groupMemberResponses.add(convertToDTO(groupMembers.get(i)));
        }

        return groupMemberResponses;
    }

    public List<GroupMemberResponse> getMemberGroups(Integer memberId) {

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        List<GroupMember> groupMembers =
                groupMemberRepository.findGroupMembersByMemberId(memberId);

        List<GroupMemberResponse> groupMemberResponses = new ArrayList<>();

        for (int i = 0; i < groupMembers.size(); i++) {
            groupMemberResponses.add(convertToDTO(groupMembers.get(i)));
        }

        return groupMemberResponses;
    }

    public void joinGroup(Integer memberId, String inviteCode) {

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        Group group = groupRepository.findGroupByInviteCode(inviteCode);

        if (group == null) {
            throw new ApiException("Invalid invite code");
        }

        GroupMember existingMember =
                groupMemberRepository.findGroupMemberByGroupIdAndMemberId(
                        group.getId(), memberId);

        if (existingMember != null) {
            throw new ApiException("Member already joined this group");
        }

        List<GroupMember> groupMembers =
                groupMemberRepository.findGroupMembersByGroupId(group.getId());

        if (groupMembers.size() >= 10) {
            throw new ApiException("Group is full, maximum 10 members");
        }

        GroupMember groupMember = new GroupMember();
        groupMember.setGroup(group);
        groupMember.setMember(member);
        groupMember.setJoinedAt(LocalDateTime.now());
        groupMember.setPoints(0);
        groupMember.setRole("MEMBER");

        groupMemberRepository.save(groupMember);
    }


    public void leaveGroup(Integer groupId, Integer memberId) {

        GroupMember groupMember =
                groupMemberRepository.findGroupMemberByGroupIdAndMemberId(
                        groupId, memberId);

        if (groupMember == null) {
            throw new ApiException("Member is not in this group");
        }

        if ("OWNER".equals(groupMember.getRole())) {
            throw new ApiException("Group owner cannot leave the group");
        }

        groupMemberRepository.delete(groupMember);
    }

    public GroupMemberResponse convertToDTO(GroupMember groupMember) {

        return new GroupMemberResponse(
                groupMember.getGroup().getId(),
                groupMember.getGroup().getName(),
                groupMember.getMember().getId(),
                groupMember.getMember().getUser().getName(),
                groupMember.getPoints(),
                groupMember.getRole(),
                groupMember.getJoinedAt()
        );
    }
}