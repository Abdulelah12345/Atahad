package com.example.atahad.Repository;

import com.example.atahad.Entity.Group;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface GroupRepository extends JpaRepository<Group, Integer> {

    Group findGroupById(Integer id);

    Group findGroupByInviteCode(String inviteCode);
}