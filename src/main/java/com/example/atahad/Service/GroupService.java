package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GroupCreateRequest;
import com.example.atahad.Dto.In.GroupUpdateRequest;
import com.example.atahad.Dto.Out.GroupResponse;
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
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class GroupService {

    private final GroupRepository groupRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final MemberRepository memberRepository;

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

    public void addGroup(Integer memberId, GroupCreateRequest dto) {

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        Group group = new Group();
        group.setName(dto.getName());
        group.setDescription(dto.getDescription());
        group.setCreatedAt(LocalDateTime.now());

        String inviteCode;

        do {
            inviteCode = UUID.randomUUID().toString().substring(0, 8);
        } while (groupRepository.findGroupByInviteCode(inviteCode) != null);

        group.setInviteCode(inviteCode);

        groupRepository.save(group);

        GroupMember groupMember = new GroupMember();
        groupMember.setGroup(group);
        groupMember.setMember(member);
        groupMember.setRole("OWNER");
        groupMember.setPoints(0);
        groupMember.setJoinedAt(LocalDateTime.now());

        groupMemberRepository.save(groupMember);
    }


    public void updateGroup(Integer groupId, Integer memberId, GroupUpdateRequest dto) {

        Group group = groupRepository.findGroupById(groupId);

        if (group == null) {
            throw new ApiException("Group not found");
        }

        GroupMember groupMember =
                groupMemberRepository.findGroupMemberByGroupIdAndMemberId(groupId, memberId);

        if (groupMember == null) {
            throw new ApiException("Member is not in this group");
        }

        if (!groupMember.getRole().equals("OWNER")) {
            throw new ApiException("Only group owner can update the group");
        }

        group.setName(dto.getName());
        group.setDescription(dto.getDescription());

        groupRepository.save(group);
    }


    public void deleteGroup(Integer groupId, Integer memberId) {

        Group group = groupRepository.findGroupById(groupId);

        if (group == null) {
            throw new ApiException("Group not found");
        }

        GroupMember groupMember =
                groupMemberRepository.findGroupMemberByGroupIdAndMemberId(groupId, memberId);

        if (groupMember == null) {
            throw new ApiException("Member is not in this group");
        }

        if (!groupMember.getRole().equals("OWNER")) {
            throw new ApiException("Only group owner can delete the group");
        }

        List<GroupMember> members =
                groupMemberRepository.findGroupMembersByGroupId(groupId);

        groupMemberRepository.deleteAll(members);

        groupRepository.delete(group);
    }

    public GroupResponse convertToDTO(Group group) {

        List<GroupMember> members =
                groupMemberRepository.findGroupMembersByGroupId(group.getId());

        Integer membersCount = members.size();

        return new GroupResponse(
                group.getId(),
                group.getName(),
                group.getDescription(),
                group.getInviteCode(),
                group.getCreatedAt(),
                membersCount
        );
    }
}