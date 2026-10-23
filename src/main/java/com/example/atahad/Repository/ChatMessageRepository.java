package com.example.atahad.Repository;

import com.example.atahad.Entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface ChatMessageRepository extends JpaRepository<ChatMessage, Integer> {
    ChatMessage findChatMessageById(Integer id);

    List<ChatMessage> findChatMessagesByGroupIdAndTypeInOrderBySentAtAsc(Integer groupId, List<String> types);

    // the alerts (ALERT and COLLECTIVE)
    List<ChatMessage> findChatMessagesByTypeInAndReceiverIdAndSentAtAfterOrderBySentAtDesc(List<String> types, Integer receiverId, LocalDateTime after);

    List<ChatMessage> findChatMessagesByTypeInAndSenderIdAndReceiverIdAndSentAtAfter(List<String> types, Integer senderId, Integer receiverId, LocalDateTime after);

    List<ChatMessage> findChatMessagesByTypeInAndSenderIdAndSentAtBetween(List<String> types, Integer senderId, LocalDateTime from, LocalDateTime to);
}
