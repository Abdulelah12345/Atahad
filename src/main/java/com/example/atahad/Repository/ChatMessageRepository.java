package com.example.atahad.Repository;

import com.example.atahad.Entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ChatMessageRepository extends JpaRepository<ChatMessage, Integer> {
    ChatMessage findChatMessageById(Integer id);

    List<ChatMessage> findChatMessagesByGroupIdOrderBySentAtAsc(Integer groupId);
}
