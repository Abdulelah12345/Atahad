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
                ? "انسحبت من *" + commitmentTitle + "*، والمرات الباقية هالأسبوع صارت تبرّع"
                : "فاتتك " + (times == 1 ? "مرة" : times == 2 ? "مرتين" : times + " مرات") + " في *" + commitmentTitle + "* والأيام الباقية ما تكفي";
        String body = "🔒 *أتعهّد | التطبيق انقفل*\n"
                + LINE + "\n\n"
                + "هلا " + name(member) + "،\n"
                + reason + ".\n\n"
                + "💰 *المطلوب منك:* " + money(totalToDonate) + " ريال\n"
                + "   (" + times + " × " + money(amountPerTime) + " ريال)\n\n"
                + "*عشان يرجع التطبيق:*\n"
                + "1️⃣ تبرّع بالمبلغ لمنصة *إحسان*\n"
                + "2️⃣ افتح أتعهّد واضغط *تبرّعت* 🧾\n\n"
                + "عندك عذر؟ اضغط *عندي عذر* 📝\n\n"
                + LINE + "\n"
                + "_تبرعك يروح لمحتاج، والتزامك يرجع لك_ 🤍";
        enqueue(member, "LOCK", body);
    }

    // the donation was accepted, the app is open again
    public void unlockMessage(Member member, BigDecimal donated){
        String body = "🔓 *أتعهّد | التطبيق انفتح*\n"
                + LINE + "\n\n"
                + "شكراً " + name(member) + " 🤍\n"
                + "تأكدنا من تبرعك بـ *" + money(donated) + " ريال* لإحسان.\n\n"
                + "التطبيق رجع لك، وكمّل التزامك 💪\n\n"
                + LINE + "\n"
                + "_جزاك الله خير_";
        enqueue(member, "UNLOCK", body);
    }

    // MUST_TODAY: what must be done today so nothing is lost
    public void reminderMessage(Member member, List<String> lines){
        StringBuilder items = new StringBuilder();
        for(String line : lines){
            items.append("▫️ ").append(line).append("\n");
        }
        String body = "⏰ *أتعهّد | تذكير اليوم*\n"
                + LINE + "\n\n"
                + "هلا " + name(member) + " 👋\n"
                + "اليوم لازم تسوي:\n\n"
                + items
                + "\nلو ما سويتها اليوم بتروح عليك مرة،\n"
                + "ويتقفل التطبيق لين تتبرّع 🔒\n\n"
                + "📸 ارفع الإثبات قبل *11:59 الليل*\n\n"
                + LINE + "\n"
                + "_قدها وقدود_ 💪";
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
                ? "✅ *ما عليك شي هالأسبوع*"
                : "💰 *عليك تبرّع:* " + money(myAmount) + " ريال لإحسان\n"
                + "   افتح أتعهّد واضغط *تبرّعت* بعد ما تتبرّع";
        String body = "⚖️ *أتعهّد | تسوية الأسبوع*\n"
                + "👥 " + groupName + " • " + goalTitle + "\n"
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
