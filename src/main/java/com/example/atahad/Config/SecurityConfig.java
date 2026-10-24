package com.example.atahad.Config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder(){
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception{
        return http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
                )
                .authorizeHttpRequests(auth -> auth
                        //admin only
                        .requestMatchers("/api/v1/group/get", "/api/v1/group-member/member/*").hasAuthority("ADMIN")

                        //member, groups (being a member or the owner of the group is checked in the service)
                        .requestMatchers("/api/v1/group/add", "/api/v1/group/update/*", "/api/v1/group/invite/*", "/api/v1/group/resetInvite/*", "/api/v1/group/delete/*",
                                "/api/v1/group-member/group/*", "/api/v1/group-member/my", "/api/v1/group-member/join/*", "/api/v1/group-member/add/*/*", "/api/v1/group-member/leave/*",
                                "/api/v1/group-goal/add/*", "/api/v1/group-goal/active/*", "/api/v1/group-goal/history/*", "/api/v1/group-goal/board/*",
                                "/api/v1/goal-proposal/ai/*", "/api/v1/goal-proposal/add/*", "/api/v1/goal-proposal/open/*", "/api/v1/goal-proposal/vote/*", "/api/v1/goal-proposal/reject/*",
                                "/api/v1/group-match/suggest/*", "/api/v1/group-match/challenge/*", "/api/v1/group-match/respond/*/*", "/api/v1/group-match/get/*",
                                "/api/v1/group-settlement/get/*", "/api/v1/group-settlement/latest/*",
                                "/api/v1/group-title/latest/*", "/api/v1/group-title/history/*",
                                "/api/v1/group-alert/send/*/*", "/api/v1/group-alert/today/*",
                                "/api/v1/chat-message/send/*", "/api/v1/chat-message/get/*", "/api/v1/chat-message/delete/*",
                                "/api/v1/moment/add", "/api/v1/moment/my", "/api/v1/moment/group/*", "/api/v1/moment/widget", "/api/v1/moment/delete/*").hasAuthority("MEMBER")

                        //member or admin
                        .requestMatchers("/api/v1/group/get/*").hasAnyAuthority("MEMBER", "ADMIN")

                        //the other parts stay open until their rules are added here
                        .anyRequest().permitAll()
                )
                .logout(logout -> logout
                        .logoutUrl("/api/v1/user/auth/logout")
                        .invalidateHttpSession(true)
                )
                .httpBasic(basic -> {})
                .build();
    }
}
