package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// reads the bank emails of the member with Gmail API (read only), after he links his Gmail with Google OAuth
// an email counts only when Gmail says its DKIM signature passed and the signing domain is a Saudi bank,
// so a fake email that was written by the member himself is not accepted
@Service
@RequiredArgsConstructor
public class GmailService {
    private final MemberRepository memberRepository;

    @Value("${google.client-id:}")
    private String clientId;

    @Value("${google.client-secret:}")
    private String clientSecret;

    @Value("${google.redirect-uri:http://localhost:8080/api/v1/donation-proof/gmail/callback}")
    private String redirectUri;

    @Value("${donation.bank-domains:alrajhibank.com.sa,alahli.com,riyadbank.com,sab.com,alinma.com,bankalbilad.com,anb.com.sa,bsf.sa,saib.com.sa,aljazirabank.com.sa,stcbank.com.sa,d360.com}")
    private String bankDomains;

    private final RestClient restClient = RestClient.create();

    public record BankEmail(String domain, String subject, String text, LocalDateTime receivedAt) {}

    // step 1: the app opens this link, the member allows reading his emails
    public String connectLink(Integer memberId){
        checkConfigured();
        return "https://accounts.google.com/o/oauth2/v2/auth"
                + "?client_id=" + encode(clientId)
                + "&redirect_uri=" + encode(redirectUri)
                + "&response_type=code"
                + "&scope=" + encode("https://www.googleapis.com/auth/gmail.readonly")
                + "&access_type=offline&prompt=consent"
                + "&state=" + memberId;
    }

    // step 2: Google sends the member back here with a code, we keep the refresh token
    public void finishConnect(String code, Integer memberId){
        checkConfigured();
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("code", code);
        form.add("client_id", clientId);
        form.add("client_secret", clientSecret);
        form.add("redirect_uri", redirectUri);
        form.add("grant_type", "authorization_code");
        Map<?, ?> token = restClient.post().uri("https://oauth2.googleapis.com/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form).retrieve().body(Map.class);
        if(token == null || token.get("refresh_token") == null){
            throw new ApiException("Google did not give access, try again");
        }
        Map<?, ?> profile = restClient.get().uri("https://gmail.googleapis.com/gmail/v1/users/me/profile")
                .header("Authorization", "Bearer " + token.get("access_token")).retrieve().body(Map.class);

        member.setGmailRefreshToken(String.valueOf(token.get("refresh_token")));
        member.setLinkedEmail(profile == null ? null : String.valueOf(profile.get("emailAddress")));
        member.setEmailLinked(true);
        memberRepository.save(member);
    }

    // the bank emails that arrived after the given time, only the ones signed by a bank
    public List<BankEmail> findBankEmails(Member member, LocalDateTime after){
        checkConfigured();
        if(!Boolean.TRUE.equals(member.getEmailLinked()) || member.getGmailRefreshToken() == null){
            throw new ApiException("Link your Gmail first");
        }
        String accessToken = accessToken(member);
        long afterSeconds = after.atZone(ZoneId.of("Asia/Riyadh")).toEpochSecond();

        Map<?, ?> list = restClient.get()
                .uri("https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=15&q={query}", "after:" + afterSeconds)
                .header("Authorization", "Bearer " + accessToken).retrieve().body(Map.class);
        List<BankEmail> emails = new ArrayList<>();
        if(list == null || list.get("messages") == null){
            return emails;
        }
        for(Object item : (List<?>) list.get("messages")){
            String id = String.valueOf(((Map<?, ?>) item).get("id"));
            Map<?, ?> message = restClient.get()
                    .uri("https://gmail.googleapis.com/gmail/v1/users/me/messages/" + id + "?format=full")
                    .header("Authorization", "Bearer " + accessToken).retrieve().body(Map.class);
            BankEmail email = toBankEmail(message);
            if(email != null){
                emails.add(email);
            }
        }
        return emails;
    }

    private BankEmail toBankEmail(Map<?, ?> message){
        if(message == null){
            return null;
        }
        Map<?, ?> payload = (Map<?, ?>) message.get("payload");
        String authResults = "";
        String subject = "";
        for(Object h : (List<?>) payload.get("headers")){
            Map<?, ?> header = (Map<?, ?>) h;
            String name = String.valueOf(header.get("name"));
            if(name.equalsIgnoreCase("Authentication-Results")){
                authResults += " " + header.get("value");
            }
            if(name.equalsIgnoreCase("Subject")){
                subject = String.valueOf(header.get("value"));
            }
        }
        String domain = signedBankDomain(authResults);
        if(domain == null){
            return null; // not signed by a bank, ignored
        }
        StringBuilder text = new StringBuilder(String.valueOf(message.get("snippet"))).append("\n");
        collectText(payload, text);
        long millis = Long.parseLong(String.valueOf(message.get("internalDate")));
        LocalDateTime received = LocalDateTime.ofInstant(Instant.ofEpochMilli(millis), ZoneId.of("Asia/Riyadh"));
        String body = text.length() > 4000 ? text.substring(0, 4000) : text.toString();
        return new BankEmail(domain, subject, body, received);
    }

    // "dkim=pass header.d=alrajhibank.com.sa" or "header.i=@alrajhibank.com.sa"
    private String signedBankDomain(String authResults){
        Matcher matcher = Pattern.compile("dkim=pass[^;]*?header\\.(?:d|i)=@?([A-Za-z0-9.-]+)").matcher(authResults);
        List<String> banks = Arrays.stream(bankDomains.split(",")).map(String::trim).map(String::toLowerCase).toList();
        while(matcher.find()){
            String domain = matcher.group(1).toLowerCase();
            for(String bank : banks){
                if(domain.equals(bank) || domain.endsWith("." + bank)){
                    return domain;
                }
            }
        }
        return null;
    }

    private void collectText(Map<?, ?> part, StringBuilder text){
        String mime = String.valueOf(part.get("mimeType"));
        Map<?, ?> body = (Map<?, ?>) part.get("body");
        if(body != null && body.get("data") != null && (mime.startsWith("text/plain") || mime.startsWith("text/html"))){
            String decoded = new String(Base64.getUrlDecoder().decode(String.valueOf(body.get("data"))), StandardCharsets.UTF_8);
            text.append(decoded.replaceAll("<[^>]+>", " ").replaceAll("\\s+", " ")).append("\n");
        }
        if(part.get("parts") != null){
            for(Object child : (List<?>) part.get("parts")){
                collectText((Map<?, ?>) child, text);
            }
        }
    }

    private String accessToken(Member member){
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("client_id", clientId);
        form.add("client_secret", clientSecret);
        form.add("refresh_token", member.getGmailRefreshToken());
        form.add("grant_type", "refresh_token");
        Map<?, ?> token = restClient.post().uri("https://oauth2.googleapis.com/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form).retrieve().body(Map.class);
        if(token == null || token.get("access_token") == null){
            throw new ApiException("Gmail access ended, link your Gmail again");
        }
        return String.valueOf(token.get("access_token"));
    }

    private void checkConfigured(){
        if(clientId == null || clientId.isBlank() || clientSecret == null || clientSecret.isBlank()){
            throw new ApiException("Gmail is not set up yet, use the screenshot instead");
        }
    }

    private String encode(String value){
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
