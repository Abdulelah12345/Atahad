package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.ChatMessageRequest;
import com.example.atahad.Service.ChatMessageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/chat-message")
@RequiredArgsConstructor
public class ChatMessageController {
    private final ChatMessageService chatMessageService;

    @PostMapping("/send/{groupId}/{memberId}")
    public ResponseEntity<?> send(@PathVariable Integer groupId, @PathVariable Integer memberId, @RequestBody @Valid ChatMessageRequest dto){
        chatMessageService.send(groupId, memberId, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Message sent"));
    }

    @GetMapping("/get/{groupId}/{memberId}")
    public ResponseEntity<?> getMessages(@PathVariable Integer groupId, @PathVariable Integer memberId){
        return ResponseEntity.status(200).body(chatMessageService.getMessages(groupId, memberId));
    }

    @DeleteMapping("/delete/{memberId}/{messageId}")
    public ResponseEntity<?> delete(@PathVariable Integer memberId, @PathVariable Integer messageId){
        chatMessageService.delete(memberId, messageId);
        return ResponseEntity.status(200).body(new ApiResponse("Message deleted"));
    }
}
