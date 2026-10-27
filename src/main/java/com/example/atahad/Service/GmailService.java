package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GmailConnectRequest;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.MemberRepository;
import jakarta.mail.*;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.search.ComparisonTerm;
import jakarta.mail.search.ReceivedDateTerm;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// reads the bank emails of the member from his Gmail with IMAP and a Google App Password (read only)
// an email counts only when Gmail says its DKIM signature passed (the sender is real, not written by the member),
// and the signer is not a free email service (anyone can send from gmail.com or outlook.com)
// the AI then reads the content and decides if it is a bank transfer to Ehsan
@Service
@RequiredArgsConstructor
public class GmailService {
    private final AuthenticatedUserService authenticatedUserService;
    private final MemberRepository memberRepository;

    private static final String IMAP_HOST = "imap.gmail.com";
    private static final int MAX_EMAILS = 100; // the newest emails since the day of the donation, the bank email can be under many others
    private static final List<String> FREE_MAIL = List.of("gmail.com", "googlemail.com", "outlook.com", "hotmail.com", "live.com",
            "yahoo.com", "icloud.com", "me.com", "aol.com", "proton.me", "protonmail.com", "gmx.com", "mail.com", "yandex.com");

    public record BankEmail(String domain, String subject, String text, LocalDateTime receivedAt) {}

    // the member links his Gmail once with an App Password (Google account > Security > App passwords)
    public void connect(Integer memberId, GmailConnectRequest dto){
        authenticatedUserService.checkMember(memberId);
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        String gmail = dto.getGmailAddress().trim().toLowerCase();
        String appPassword = dto.getAppPassword().replace(" ", ""); // Google shows it with spaces

        // try to log in first, so a wrong address or password is not saved
        Store store = null;
        try{
            store = open(gmail, appPassword);
        }catch(MessagingException e){
            throw new ApiException("Could not connect to Gmail, check the email and the App Password");
        }finally{
            close(store);
        }
        member.setLinkedEmail(gmail);
        member.setGmailAppPassword(appPassword);
        member.setEmailLinked(true);
        memberRepository.save(member);
    }

    public void disconnect(Integer memberId){
        authenticatedUserService.checkMember(memberId);
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        member.setGmailAppPassword(null);
        member.setEmailLinked(false);
        memberRepository.save(member);
    }

    // the emails that arrived after the given time and are signed by their sender (DKIM), the newest first
    public List<BankEmail> findBankEmails(Member member, LocalDateTime after){
        if(!Boolean.TRUE.equals(member.getEmailLinked()) || member.getGmailAppPassword() == null){
            throw new ApiException("Link your Gmail first");
        }
        Date since = Date.from(after.atZone(ZoneId.of("Asia/Riyadh")).toInstant());
        List<BankEmail> emails = new ArrayList<>();
        Store store = null;
        try{
            store = open(member.getLinkedEmail(), member.getGmailAppPassword());
            Folder inbox = store.getFolder("INBOX");
            inbox.open(Folder.READ_ONLY);
            // IMAP searches by day only, the exact time is checked below
            Message[] messages = inbox.search(new ReceivedDateTerm(ComparisonTerm.GE, since));
            int start = Math.max(0, messages.length - MAX_EMAILS);
            for(int i = messages.length - 1; i >= start; i--){
                try{
                    BankEmail email = toBankEmail(messages[i], since);
                    if(email != null){
                        emails.add(email);
                    }
                }catch(Exception e){
                    // one bad email does not stop the others
                }
            }
            inbox.close(false);
        }catch(AuthenticationFailedException e){
            throw new ApiException("Gmail access ended, link your Gmail again with a new App Password");
        }catch(MessagingException e){
            throw new ApiException("Could not read Gmail, try again later");
        }finally{
            close(store);
        }
        return emails;
    }

    private BankEmail toBankEmail(Message message, Date since) throws Exception {
        Date received = message.getReceivedDate();
        if(received == null || received.before(since)){
            return null;
        }
        String[] results = message.getHeader("Authentication-Results");
        String domain = signedDomain(results == null ? "" : String.join(" ", results));
        if(domain == null){
            return null; // not signed, or sent from a free email service
        }
        String subject = message.getSubject() == null ? "" : message.getSubject();
        String from = "";
        if(message.getFrom() != null && message.getFrom().length > 0){
            Address address = message.getFrom()[0];
            from = address instanceof InternetAddress internet ? internet.toUnicodeString() : address.toString();
        }
        StringBuilder text = new StringBuilder();
        collectText(message, text);
        // only emails about Ehsan or a charity go to the AI (احسان / إحسان / Ehsan / جمعية / خيرية / charity)
        String all = (subject + " " + text).toLowerCase();
        if(!all.contains("حسان") && !all.contains("ehsan") && !all.contains("جمعي") && !all.contains("خيري")
                && !all.contains("charity") && !all.contains("charitable")){
            return null;
        }
        String body = "From: " + from + "\n" + text;
        body = body.length() > 4000 ? body.substring(0, 4000) : body;
        return new BankEmail(domain, subject, body, LocalDateTime.ofInstant(received.toInstant(), ZoneId.of("Asia/Riyadh")));
    }

    // "dkim=pass header.d=alrajhibank.com.sa" or "header.i=@alrajhibank.com.sa"
    private String signedDomain(String authResults){
        Matcher matcher = Pattern.compile("dkim=pass[^;]*?header\\.(?:d|i)=@?([A-Za-z0-9.-]+)").matcher(authResults);
        while(matcher.find()){
            String domain = matcher.group(1).toLowerCase();
            boolean free = FREE_MAIL.stream().anyMatch(f -> domain.equals(f) || domain.endsWith("." + f));
            if(!free){
                return domain;
            }
        }
        return null;
    }

    private void collectText(Part part, StringBuilder text) throws Exception {
        if(part.isMimeType("text/plain") || part.isMimeType("text/html")){
            String content = String.valueOf(part.getContent());
            text.append(content.replaceAll("(?s)<style.*?</style>", " ").replaceAll("<[^>]+>", " ")
                    .replace("&nbsp;", " ").replaceAll("\\s+", " ")).append("\n");
        }else if(part.isMimeType("multipart/*")){
            Multipart multipart = (Multipart) part.getContent();
            for(int i = 0; i < multipart.getCount(); i++){
                collectText(multipart.getBodyPart(i), text);
            }
        }
    }

    private Store open(String gmail, String appPassword) throws MessagingException {
        Properties props = new Properties();
        props.put("mail.store.protocol", "imaps");
        props.put("mail.imaps.connectiontimeout", "10000");
        props.put("mail.imaps.timeout", "20000");
        Store store = Session.getInstance(props).getStore("imaps");
        store.connect(IMAP_HOST, gmail, appPassword);
        return store;
    }

    private void close(Store store){
        try{
            if(store != null){
                store.close();
            }
        }catch(MessagingException ignored){
        }
    }
}
