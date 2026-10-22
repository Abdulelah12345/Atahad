package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.ChatMessageRequest;
import com.example.atahad.Dto.Out.ChatMessageResponse;
import com.example.atahad.Entity.ChatMessage;
import com.example.atahad.Entity.GroupMember;
import com.example.atahad.Repository.ChatMessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// the group chat, the app also writes SYSTEM messages in it
@Service
@RequiredArgsConstructor
public class ChatMessageService {
    private final ChatMessageRepository chatMessageRepository;
    private final GroupAccessService groupAccessService;

    public void send(Integer groupId, Integer memberId, ChatMessageRequest dto){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        ChatMessage message = new ChatMessage();
        message.setType("TEXT");
        message.setContent(dto.getContent());
        message.setSentAt(LocalDateTime.now());
        message.setGroup(groupMember.getGroup());
        message.setSender(groupMember);
        chatMessageRepository.save(message);
    }

    public List<ChatMessageResponse> getMessages(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        List<ChatMessageResponse> list = new ArrayList<>();
        for(ChatMessage message : chatMessageRepository.findChatMessagesByGroupIdOrderBySentAtAsc(groupId)){
            GroupMember sender = message.getSender();
            list.add(new ChatMessageResponse(message.getId(), message.getType(), message.getContent(),
                    sender == null ? null : sender.getMember().getId(),
                    sender == null ? "Atahad" : groupAccessService.nameOf(sender.getMember()),
                    message.getSentAt()));
        }
        return list;
    }

    // only the sender deletes his message
    public void delete(Integer memberId, Integer messageId){
        ChatMessage message = chatMessageRepository.findChatMessageById(messageId);
        if(message == null || message.getSender() == null || !message.getSender().getMember().getId().equals(memberId)){
            throw new ApiException("You can only delete your own message");
        }
        chatMessageRepository.delete(message);
    }
}
