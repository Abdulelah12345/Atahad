package com.example.atahad.Repository;

import com.example.atahad.Entity.WhatsAppMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface WhatsAppMessageRepository extends JpaRepository<WhatsAppMessage, Integer> {
    WhatsAppMessage findWhatsAppMessageById(Integer id);

    List<WhatsAppMessage> findTop50ByStatusOrderByCreatedAtAsc(String status);

    List<WhatsAppMessage> findWhatsAppMessagesByMemberIdAndTypeAndCreatedAtAfter(Integer memberId, String type, LocalDateTime after);
}
