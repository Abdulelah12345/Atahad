package com.example.atahad.Repository;

import com.example.atahad.Entity.GroupAlert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface GroupAlertRepository extends JpaRepository<GroupAlert, Integer> {
    GroupAlert findGroupAlertById(Integer id);

    List<GroupAlert> findGroupAlertsByReceiverIdAndSentAtAfterOrderBySentAtDesc(Integer receiverId, LocalDateTime after);

    List<GroupAlert> findGroupAlertsBySenderIdAndReceiverIdAndSentAtAfter(Integer senderId, Integer receiverId, LocalDateTime after);

    List<GroupAlert> findGroupAlertsBySenderIdAndSentAtBetween(Integer senderId, LocalDateTime from, LocalDateTime to);
}
