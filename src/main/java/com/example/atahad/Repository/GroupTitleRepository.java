package com.example.atahad.Repository;

import com.example.atahad.Entity.GroupTitle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface GroupTitleRepository extends JpaRepository<GroupTitle, Integer> {
    GroupTitle findGroupTitleById(Integer id);

    List<GroupTitle> findGroupTitlesByGroupIdAndWeekStart(Integer groupId, LocalDate weekStart);

    List<GroupTitle> findGroupTitlesByGroupIdOrderByWeekStartDesc(Integer groupId);

    List<GroupTitle> findGroupTitlesByGroupMemberMemberIdAndWeekStartBetween(Integer memberId, LocalDate from, LocalDate to);
}
