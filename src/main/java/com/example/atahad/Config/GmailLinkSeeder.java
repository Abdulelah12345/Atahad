package com.example.atahad.Config;

import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

// OWNER: Fai - local only: links the Gmail of the main user (seed.main-email) with the App Password in
// seed.gmail-app-password (application-local.properties, never committed), so the demo never asks for it,
// even after the database is seeded again. Saved as it is (not encrypted), like the normal linking.
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "seed.gmail-app-password")
public class GmailLinkSeeder implements ApplicationRunner {

    private final UserRepository userRepository;
    private final MemberRepository memberRepository;

    @Value("${seed.main-email}")
    private String mainEmail;
    @Value("${seed.gmail-app-password}")
    private String appPassword;

    @Override
    public void run(ApplicationArguments args) {
        User user = userRepository.findUserByEmail(mainEmail);
        Member member = user == null ? null : memberRepository.findMemberById(user.getId());
        if (member == null) {
            log.warn("Gmail link: no member with the email {}", mainEmail);
            return;
        }
        String gmail = mainEmail.trim().toLowerCase();
        String password = appPassword.replace(" ", ""); // Google shows it with spaces
        if (Boolean.TRUE.equals(member.getEmailLinked()) && gmail.equals(member.getLinkedEmail()) && password.equals(member.getGmailAppPassword())) {
            return;
        }
        member.setLinkedEmail(gmail);
        member.setGmailAppPassword(password);
        member.setEmailLinked(true);
        memberRepository.save(member);
        log.info("Gmail link: {} is linked", gmail);
    }
}
