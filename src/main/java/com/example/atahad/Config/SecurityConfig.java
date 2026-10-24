package com.example.atahad.Config;

import com.example.atahad.Service.MyUserDetailsService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final MyUserDetailsService myUserDetailsService;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .userDetailsService(myUserDetailsService)
                .authorizeHttpRequests(auth -> auth


                        .requestMatchers("/api/v1/member/register", "/api/v1/account/login").permitAll()


                        .requestMatchers("/api/v1/member/get").hasRole("ADMIN")
                        .requestMatchers("/api/v1/member/get/{id}").hasRole("ADMIN")
                        .requestMatchers("/api/v1/member/profile").hasRole("MEMBER")
                        .requestMatchers("/api/v1/member/update").hasRole("MEMBER")
                        .requestMatchers("/api/v1/member/delete").hasRole("MEMBER")


                        .requestMatchers("/api/v1/admin/get").hasRole("ADMIN")
                        .requestMatchers("/api/v1/admin/get/{id}").hasRole("ADMIN")
                        .requestMatchers("/api/v1/admin/profile").hasRole("ADMIN")
                        .requestMatchers("/api/v1/admin/register").hasRole("ADMIN")
                        .requestMatchers("/api/v1/admin/update").hasRole("ADMIN")


                        .requestMatchers("/api/v1/user/get").hasRole("ADMIN")
                        .requestMatchers("/api/v1/user/get/{id}").hasRole("ADMIN")
                        .requestMatchers("/api/v1/user/update").authenticated()
                        .requestMatchers("/api/v1/user/delete").authenticated()


                        .requestMatchers("/api/v1/account/deactivate").hasRole("MEMBER")
                        .requestMatchers("/api/v1/account/unban/{memberId}").hasRole("ADMIN")

                        .requestMatchers("/api/v1/n8n/run-daily").permitAll()
                        .requestMatchers("/api/v1/n8n/reminders").permitAll()
                        .requestMatchers("/api/v1/n8n/whatsapp/pending").permitAll()
                        .requestMatchers("/api/v1/n8n/whatsapp/sent/{id}").permitAll()
                        .requestMatchers("/api/v1/n8n/whatsapp/failed/{id}").permitAll()

                        .requestMatchers("/api/v1/google-calendar/callback").permitAll()
                        .requestMatchers("/api/v1/google-calendar/connect").authenticated()
                        .requestMatchers("/api/v1/google-calendar/suggest-schedule").authenticated()
                        .requestMatchers("/api/v1/google-calendar/approve-schedule").authenticated()
                        .requestMatchers("/api/v1/google-calendar/reject-schedule").authenticated()

                        .anyRequest().authenticated()
                )
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
                )
                .exceptionHandling(exception -> exception

                        .authenticationEntryPoint((request, response, authException) -> {
                            response.setStatus(401);
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                            response.setCharacterEncoding("UTF-8");
                            response.getWriter().write("{\"message\":\"Unauthorized\"}");
                        })

                        .accessDeniedHandler((request, response, accessDeniedException) -> {
                            response.setStatus(403);
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                            response.setCharacterEncoding("UTF-8");
                            response.getWriter().write("{\"message\":\"Access denied\"}");
                        })
                )
                .formLogin(form -> form.disable())
                .httpBasic(basic -> {});

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) throws Exception {
        return configuration.getAuthenticationManager();
    }
}