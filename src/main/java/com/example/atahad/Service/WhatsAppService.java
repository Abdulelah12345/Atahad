package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.WhatsAppMessage;
import com.example.atahad.Repository.WhatsAppMessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

// the app only writes the messages here, n8n takes the PENDING ones and sends them with UltraMsg
// WhatsApp formatting: *bold*  _italic_  and new lines
@Service
@RequiredArgsConstructor
public class WhatsAppService {
    private final WhatsAppMessageRepository whatsAppMessageRepository;

    private static final String LINE = "━━━━━━━━━━━━━━";

    // ================= the messages =================

    // a time was lost (or the member withdrew), the app is locked now
    public void lockMessage(Member member, String commitmentTitle, int times, BigDecimal amountPerTime, BigDecimal totalToDonate, boolean withdrawal){
        String reason = withdrawal
                ? "انسحبت من *" + commitmentTitle + "*، والمرات المتبقية هذا الأسبوع تحوّلت إلى تبرّع"
                : "فاتتك " + (times == 1 ? "مرة" : times == 2 ? "مرتان" : times + " مرات") + " في *" + commitmentTitle + "*، والأيام المتبقية لا تكفي";
        String body = "*أتعهّد | تم قفل التطبيق* 🔒\n"
                + LINE + "\n\n"
                + "مرحباً " + name(member) + "،\n"
                + reason + ".\n\n"
                + "*المبلغ المطلوب:* " + money(totalToDonate) + " ريال\n"
                + "(" + times + " × " + money(amountPerTime) + " ريال)\n\n"
                + "*لإعادة فتح التطبيق:*\n"
                + "1. تبرّع بالمبلغ عبر منصة *إحسان*\n"
                + "2. افتح أتعهّد واضغط *تبرّعت*\n\n"
                + "أو أدخِل العذر.\n\n"
                + LINE + "\n"
                + "_الالتزام يُبنى بالاستمرار، وتبرّعك أجرٌ لك بإذن الله._";
        enqueue(member, "LOCK", body);
    }

    // the donation was accepted, the app is open again
    public void unlockMessage(Member member, BigDecimal donated){
        String body = "*أتعهّد | تم فتح التطبيق*\n"
                + LINE + "\n\n"
                + "شكراً " + name(member) + "،\n"
                + "تأكدنا من تبرّعك بمبلغ *" + money(donated) + " ريال* لمنصة إحسان.\n\n"
                + "التطبيق متاح لك الآن، واصل التزامك.\n\n"
                + LINE + "\n"
                + "_جزاك الله خيراً._";
        enqueue(member, "UNLOCK", body);
    }

    // MUST_TODAY: what must be done today so nothing is lost
    public void reminderMessage(Member member, List<String> lines){
        StringBuilder items = new StringBuilder();
        for(String line : lines){
            items.append("• ").append(line).append("\n");
        }
        String body = "*أتعهّد | تذكير اليوم* ⏰\n"
                + LINE + "\n\n"
                + "مرحباً " + name(member) + "،\n"
                + "عليك اليوم:\n\n"
                + items
                + "\nاليوم هو آخر يوم متاح لإنجازها هذا الأسبوع، وفي حال فاتتك سيُقفل التطبيق حتى إتمام التبرّع.\n"
                + "ارفع الإثبات قبل *11:59 مساءً*.\n\n"
                + LINE + "\n"
                + "_بالتوفيق._";
        enqueue(member, "REMINDER", body);
    }

    // the weekly settlement of a group, sent to every member with his own amount
    public void settlementMessage(Member member, String groupName, String goalTitle, String settlementText,
                                  List<String> board, BigDecimal myAmount){
        StringBuilder table = new StringBuilder();
        for(String row : board){
            table.append(row).append("\n");
        }
        String mine = myAmount.signum() == 0
                ? "*لا يوجد عليك مبلغ هذا الأسبوع.*"
                : "*المطلوب منك:* " + money(myAmount) + " ريال لمنصة إحسان\n"
                + "بعد التبرّع افتح أتعهّد واضغط *تبرّعت*.";
        String body = "*أتعهّد | تسوية الأسبوع*\n"
                + groupName + " — " + goalTitle + "\n"
                + LINE + "\n\n"
                + table
                + "\n" + settlementText + "\n\n"
                + LINE + "\n"
                + mine;
        enqueue(member, "SETTLEMENT", body);
    }

    // ================= the queue (used by n8n) =================

    public void enqueue(Member member, String type, String body){
        if(member.getUser() == null || member.getUser().getPhone() == null){
            return;
        }
        WhatsAppMessage message = new WhatsAppMessage();
        message.setPhone(member.getUser().getPhone());
        message.setBody(body.length() > 2000 ? body.substring(0, 2000) : body);
        message.setType(type);
        message.setStatus("PENDING");
        message.setCreatedAt(LocalDateTime.now());
        message.setMember(member);
        whatsAppMessageRepository.save(message);
    }

    public List<WhatsAppMessage> getPending(){
        return whatsAppMessageRepository.findTop50ByStatusOrderByCreatedAtAsc("PENDING");
    }

    public void markSent(Integer id){
        WhatsAppMessage message = getMessage(id);
        message.setStatus("SENT");
        message.setSentAt(LocalDateTime.now());
        message.setError(null);
        whatsAppMessageRepository.save(message);
    }

    public void markFailed(Integer id, String error){
        WhatsAppMessage message = getMessage(id);
        message.setStatus("FAILED");
        message.setError(error == null ? null : (error.length() > 255 ? error.substring(0, 255) : error));
        whatsAppMessageRepository.save(message);
    }

    public boolean sentTodayAlready(Member member, String type){
        return !whatsAppMessageRepository.findWhatsAppMessagesByMemberIdAndTypeAndCreatedAtAfter(
                member.getId(), type, LocalDate.now().atStartOfDay()).isEmpty();
    }

    private WhatsAppMessage getMessage(Integer id){
        WhatsAppMessage message = whatsAppMessageRepository.findWhatsAppMessageById(id);
        if(message == null){
            throw new ApiException("Message not found");
        }
        return message;
    }

    private String name(Member member){
        return member.getUser() == null ? "" : member.getUser().getName();
    }

    private String money(BigDecimal amount){
        return amount == null ? "0" : amount.stripTrailingZeros().toPlainString();
    }
}
