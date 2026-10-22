package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.ChatMessage;
import com.example.atahad.Entity.Group;
import com.example.atahad.Entity.GroupMember;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.ChatMessageRepository;
import com.example.atahad.Repository.GroupMemberRepository;
import com.example.atahad.Repository.GroupRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;

// the checks every group service needs, in one place
@Service
@RequiredArgsConstructor
public class GroupAccessService {
    private final GroupRepository groupRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final MemberRepository memberRepository;
    private final ChatMessageRepository chatMessageRepository;

    public static final int MIN_MEMBERS = 2;
    public static final int MAX_MEMBERS = 10;

    public Member getMember(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return member;
    }

    public Group getGroup(Integer groupId){
        Group group = groupRepository.findGroupById(groupId);
        if(group == null || "ARCHIVED".equals(group.getStatus())){
            throw new ApiException("Group not found");
        }
        return group;
    }

    public GroupMember getActiveMembership(Integer groupId, Integer memberId){
        getGroup(groupId);
        GroupMember groupMember = groupMemberRepository.findGroupMemberByGroupIdAndMemberId(groupId, memberId);
        if(groupMember == null || !"ACTIVE".equals(groupMember.getStatus())){
            throw new ApiException("You are not in this group");
        }
        return groupMember;
    }

    public GroupMember checkOwner(Integer groupId, Integer memberId){
        GroupMember groupMember = getActiveMembership(groupId, memberId);
        if(!"OWNER".equals(groupMember.getRole())){
            throw new ApiException("Only the group owner can do this");
        }
        return groupMember;
    }

    // the ladder of refusing to pay a group penalty
    public void checkNotBanned(Member member){
        if(Boolean.TRUE.equals(member.getAccountBanned())){
            throw new ApiException("This account is banned");
        }
        if(Boolean.TRUE.equals(member.getGroupBannedForever())){
            throw new ApiException("This member is banned from groups");
        }
        if(member.getGroupBanUntil() != null && !member.getGroupBanUntil().isBefore(LocalDate.now())){
            throw new ApiException("This member is banned from groups until " + member.getGroupBanUntil());
        }
    }

    public int activeMembersCount(Integer groupId){
        return groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupId, "ACTIVE").size();
    }

    // app messages inside the group chat (new goal, the weekly settlement, someone left ...)
    public void systemMessage(Group group, String content){
        ChatMessage message = new ChatMessage();
        message.setType("SYSTEM");
        message.setContent(content.length() > 1000 ? content.substring(0, 1000) : content);
        message.setSentAt(LocalDateTime.now());
        message.setGroup(group);
        chatMessageRepository.save(message);
    }

    public String nameOf(Member member){
        return member.getUser() == null ? "Member " + member.getId() : member.getUser().getName();
    }
}
