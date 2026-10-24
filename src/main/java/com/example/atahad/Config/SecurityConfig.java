
package com.example.atahad.Config;

import com.example.atahad.Service.MyUserDetailsService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final MyUserDetailsService myUserDetailsService;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration configuration
    ) throws Exception {
        return configuration.getAuthenticationManager();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http
    ) throws Exception {

        return http
                .csrf(csrf -> csrf.disable())

                .userDetailsService(myUserDetailsService)

                .authorizeHttpRequests(auth -> auth

                        // Public endpoints
                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/member/register"
                        ).permitAll()

                        .requestMatchers(
                                "/api/v1/account/login"
                        ).permitAll()

                        // Admin endpoints
                        .requestMatchers(
                                "/api/v1/admin/**"
                        ).hasAuthority("ADMIN")

                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/proof/get-all",
                                "/api/v1/excuse/get",
                                "/api/v1/objection/get-all",
                                "/api/v1/penalty/get/{adminId}",
                                "/api/v1/admin-review/queue/{adminId}",
                                "/api/v1/member/get",
                                "/api/v1/member/get/{id}",
                                "/api/v1/admin/get",
                                "/api/v1/admin/get/{id}",
                                "/api/v1/user/get",
                                "/api/v1/user/get/{id}"
                        ).hasAuthority("ADMIN")

                        .requestMatchers(
                                HttpMethod.PUT,
                                "/api/v1/penalty/cancel/{adminId}/{penaltyId}",
                                "/api/v1/admin-review/decide/{adminId}/{kind}/{id}/{accept}",
                                "/api/v1/admin/update",
                                "/api/v1/account/unban/{memberId}"
                        ).hasAuthority("ADMIN")

                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/admin/register"
                        ).hasAuthority("ADMIN")

                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/admin/profile"
                        ).hasAuthority("ADMIN")

                        // Member endpoints
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/member/profile",
                                "/api/v1/proof/get/{id}",
                                "/api/v1/proof/get-my-proofs",
                                "/api/v1/excuse/get/{id}",
                                "/api/v1/objection/get/{id}",
                                "/api/v1/donation-proof/gmail/connect/{memberId}",
                                "/api/v1/donation-proof/my/{memberId}",
                                "/api/v1/penalty/my/{memberId}"
                        ).hasAuthority("MEMBER")

                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/proof/add/goal-task/{goalTaskId}/week/{commitmentWeekId}",
                                "/api/v1/excuse/add/goal-task/{goalTaskId}/week/{commitmentWeekId}",
                                "/api/v1/proof/habit/{memberId}/{weekId}",
                                "/api/v1/excuse/habit/{memberId}/{weekId}",
                                "/api/v1/objection/add/proof/{proofId}",
                                "/api/v1/objection/add/excuse/{excuseId}",
                                "/api/v1/donation-proof/screenshot/{memberId}",
                                "/api/v1/donation-proof/email/{memberId}",
                                "/api/v1/donation-proof/objection/{memberId}/{donationProofId}"
                        ).hasAuthority("MEMBER")

                        .requestMatchers(
                                HttpMethod.PUT,
                                "/api/v1/proof/update/goal-task/{proofId}",
                                "/api/v1/excuse/update/goal-task/{excuseId}",
                                "/api/v1/objection/update/{objectionId}",
                                "/api/v1/member/update"
                        ).hasAuthority("MEMBER")

                        .requestMatchers(
                                HttpMethod.DELETE,
                                "/api/v1/proof/delete/goal-task/{proofId}",
                                "/api/v1/excuse/delete/goal-task/{excuseId}",
                                "/api/v1/objection/delete/{objectionId}",
                                "/api/v1/member/delete"
                        ).hasAuthority("MEMBER")

                        .requestMatchers(
                                "/api/v1/account/deactivate"
                        ).hasAuthority("MEMBER")

                        // Commitments (part 3) admin endpoints
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/habit/get",
                                "/api/v1/goal/get",
                                "/api/v1/grace-day/get",
                                "/api/v1/grace-day/get/{id}",
                                "/api/v1/grace-day/member/{memberId}"
                        ).hasAuthority("ADMIN")

                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/grace-day/grant/{memberId}",
                                "/api/v1/commitment-week/runDaily"
                        ).hasAuthority("ADMIN")

                        // Commitments (part 3) member endpoints
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/commitment/getMyCommitments",
                                "/api/v1/commitment/get/{id}",
                                "/api/v1/commitment/lockStatus",
                                "/api/v1/commitment/stats",
                                "/api/v1/commitment-week/get/{id}",
                                "/api/v1/commitment-week/getHistory/{commitmentId}",
                                "/api/v1/commitment-week/getCurrent/{commitmentId}",
                                "/api/v1/commitment-week/today",
                                "/api/v1/habit/getMyHabits",
                                "/api/v1/goal/getMyGoals",
                                "/api/v1/goal/progress/{id}",
                                "/api/v1/goal-task/getByGoal/{goalId}",
                                "/api/v1/goal-task/getByWeek/{goalId}/{weekNumber}",
                                "/api/v1/grace-day/my",
                                "/api/v1/point-log/my",
                                "/api/v1/point-log/group/{groupId}",
                                "/api/v1/monthly-wrapped/my"
                        ).hasAuthority("MEMBER")

                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/habit/add",
                                "/api/v1/goal/add",
                                "/api/v1/goal/suggest",
                                "/api/v1/goal/addWithPlan",
                                "/api/v1/goal-task/add/{goalId}",
                                "/api/v1/goal-task/addToAllWeeks/{goalId}",
                                "/api/v1/grace-day/earn",
                                "/api/v1/monthly-wrapped/generate/{month}"
                        ).hasAuthority("MEMBER")

                        .requestMatchers(
                                HttpMethod.PUT,
                                "/api/v1/commitment/withdraw/{id}",
                                "/api/v1/commitment-week/changePlan/{weekId}",
                                "/api/v1/habit/update/{id}",
                                "/api/v1/goal/start/{id}",
                                "/api/v1/goal/update/{id}",
                                "/api/v1/goal-task/update/{id}",
                                "/api/v1/grace-day/use/{graceDayId}/{weekId}"
                        ).hasAuthority("MEMBER")

                        .requestMatchers(
                                HttpMethod.DELETE,
                                "/api/v1/habit/delete/{id}",
                                "/api/v1/goal/delete/{id}",
                                "/api/v1/goal-task/delete/{id}"
                        ).hasAuthority("MEMBER")

                        // User endpoints
                        .requestMatchers(
                                HttpMethod.PUT,
                                "/api/v1/user/update"
                        ).authenticated()

                        .requestMatchers(
                                HttpMethod.DELETE,
                                "/api/v1/user/delete"
                        ).authenticated()

                        // Google OAuth callbacks
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/donation-proof/gmail/callback",
                                "/api/v1/google-calendar/callback"
                        ).permitAll()

                        // Google Calendar requires authentication
                        .requestMatchers(
                                "/api/v1/google-calendar/connect",
                                "/api/v1/google-calendar/suggest-schedule",
                                "/api/v1/google-calendar/approve-schedule",
                                "/api/v1/google-calendar/reject-schedule"
                        ).authenticated()

                        // n8n endpoints
                        .requestMatchers(
                                "/api/v1/n8n/run-daily",
                                "/api/v1/n8n/reminders",
                                "/api/v1/n8n/whatsapp/pending",
                                "/api/v1/n8n/whatsapp/sent/{id}",
                                "/api/v1/n8n/whatsapp/failed/{id}"
                        ).permitAll()

                        // Deny unconfigured endpoints in these controllers
                        .requestMatchers(
                                "/api/v1/proof/**",
                                "/api/v1/excuse/**",
                                "/api/v1/objection/**",
                                "/api/v1/donation-proof/**",
                                "/api/v1/penalty/**",
                                "/api/v1/admin-review/**",
                                "/api/v1/commitment/**",
                                "/api/v1/commitment-week/**",
                                "/api/v1/habit/**",
                                "/api/v1/goal/**",
                                "/api/v1/goal-task/**",
                                "/api/v1/grace-day/**",
                                "/api/v1/point-log/**",
                                "/api/v1/monthly-wrapped/**"
                        ).denyAll()

                        // All remaining endpoints require authentication
                        .anyRequest().authenticated()
                )

                .sessionManagement(session -> session
                        .sessionCreationPolicy(
                                SessionCreationPolicy.IF_REQUIRED
                        )
                )

                .exceptionHandling(exception -> exception

                        .authenticationEntryPoint(
                                (request, response, authException) -> {
                                    response.setStatus(401);
                                    response.setContentType(
                                            MediaType.APPLICATION_JSON_VALUE
                                    );
                                    response.setCharacterEncoding("UTF-8");
                                    response.getWriter().write(
                                            "{\"message\":\"Unauthorized\"}"
                                    );
                                }
                        )

                        .accessDeniedHandler(
                                (request, response, accessDeniedException) -> {
                                    response.setStatus(403);
                                    response.setContentType(
                                            MediaType.APPLICATION_JSON_VALUE
                                    );
                                    response.setCharacterEncoding("UTF-8");
                                    response.getWriter().write(
                                            "{\"message\":\"Access denied\"}"
                                    );
                                }
                        )
                )

                .logout(logout -> logout
                        .logoutUrl("/api/v1/user/logout")
                        .invalidateHttpSession(true)
                        .deleteCookies("JSESSIONID")
                )

                .formLogin(form -> form.disable())

                .httpBasic(basic -> {})

                .build();
    }
}
