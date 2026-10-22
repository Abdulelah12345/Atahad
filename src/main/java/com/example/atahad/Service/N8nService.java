package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.TodayTaskResponse;
import com.example.atahad.Dto.Out.WhatsAppOutResponse;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.WhatsAppMessage;
import com.example.atahad.Repository.CommitmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

// what n8n calls: the daily automation, the reminders, and the WhatsApp queue
// every call must have the header X-N8N-KEY with the key from application-local.properties
@Service
@RequiredArgsConstructor
public class N8nService {
    private final CommitmentRepository commitmentRepository;
    private final CommitmentWeekService commitmentWeekService;
    private final WhatsAppService whatsAppService;

    @Value("${n8n.key:}")
    private String n8nKey;

    public void checkKey(String key){
        if(n8nKey == null || n8nKey.isBlank() || !n8nKey.equals(key)){
            throw new ApiException("Wrong n8n key");
        }
    }

    // one reminder for every member who must do something today (MUST_TODAY), once a day
    @Transactional
    public int createReminders(){
        Map<Integer, Member> members = new LinkedHashMap<>();
        for(Commitment commitment : commitmentRepository.findCommitmentsByStatus("ACTIVE")){
            members.put(commitment.getMember().getId(), commitment.getMember());
        }
        int count = 0;
        for(Member member : members.values()){
            if(whatsAppService.sentTodayAlready(member, "REMINDER")){
                continue;
            }
            List<String> lines = new ArrayList<>();
            for(TodayTaskResponse item : commitmentWeekService.getToday(member.getId())){
                if("MUST_TODAY".equals(item.getTrackStatus()) && item.getRemaining() > 0){
                    lines.add("*" + item.getTitle() + "*  (باقي " + item.getRemaining() + " • " + item.getAmountPerTime().stripTrailingZeros().toPlainString() + " ريال للمرة)");
                }
            }
            if(!lines.isEmpty()){
                whatsAppService.reminderMessage(member, lines);
                count++;
            }
        }
        return count;
    }

    public List<WhatsAppOutResponse> getPending(){
        List<WhatsAppOutResponse> list = new ArrayList<>();
        for(WhatsAppMessage message : whatsAppService.getPending()){
            list.add(new WhatsAppOutResponse(message.getId(), message.getPhone(), message.getBody(), message.getType()));
        }
        return list;
    }
}
