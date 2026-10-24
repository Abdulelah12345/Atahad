package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.ChatMessageRequest;
import com.example.atahad.Service.ChatMessageService;
import jakarta.validation.Valid;
import com.example.atahad.Entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/chat-message")
@RequiredArgsConstructor
public class ChatMessageController {
    private final ChatMessageService chatMessageService;

    @PostMapping("/send/{groupId}")
    public ResponseEntity<?> send(@AuthenticationPrincipal User user, @PathVariable Integer groupId, @RequestBody @Valid ChatMessageRequest dto){
        chatMessageService.send(groupId, user.getId(), dto);
        return ResponseEntity.status(200).body(new ApiResponse("Message sent"));
    }

    @GetMapping("/get/{groupId}")
    public ResponseEntity<?> getMessages(@AuthenticationPrincipal User user, @PathVariable Integer groupId){
        return ResponseEntity.status(200).body(chatMessageService.getMessages(groupId, user.getId()));
    }

    @DeleteMapping("/delete/{messageId}")
    public ResponseEntity<?> delete(@AuthenticationPrincipal User user, @PathVariable Integer messageId){
        chatMessageService.delete(user.getId(), messageId);
        return ResponseEntity.status(200).body(new ApiResponse("Message deleted"));
    }
}
