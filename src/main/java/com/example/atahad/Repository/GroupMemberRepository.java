package com.example.atahad.Repository;

import com.example.atahad.Entity.GroupMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GroupMemberRepository extends JpaRepository<GroupMember, Integer> {

    GroupMember findGroupMemberByGroupIdAndMemberId(Integer groupId, Integer memberId);

    List<GroupMember> findGroupMembersByGroupId(Integer groupId);

    List<GroupMember> findGroupMembersByMemberId(Integer memberId);
}