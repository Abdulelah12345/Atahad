package com.example.atahad.Config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

// مؤقت لين نبني تسجيل الدخول: كل الطلبات مسموحة بدون توثيق.
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /*
     الخصومات غير المدفوعة لا تمنع تسجيل الدخول، حتى يتمكن العضو من رفع إثبات التبرع.
     نقيّد عملياته عن طريق LockInterceptor حسب الفلو، أما الحساب المعطل فيمنع من الدخول.
    */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                // هذا يعطل حماية CSRF، ولا يغني عن مراجعتها عند استخدام جلسات المتصفح.
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
                )
                .authorizeHttpRequests(auth -> auth
                        // إنشاء حساب عضو متاح قبل تسجيل الدخول؛ إنشاء الأدمن للأدمن فقط.
                        .requestMatchers(HttpMethod.POST, "/api/v1/member/register").permitAll()
                        .requestMatchers("/api/v1/admin/**").hasAuthority("ADMIN")

                        // رجوع Google لا يشترط دور عضو؛ يجب التحقق من state داخل مسار الربط.
                        .requestMatchers(HttpMethod.GET,
                                "/api/v1/donation-proof/gmail/callback").permitAll()

                        // الأدمن يعرض جميع الإثباتات والأعذار والاعتراضات والخصومات وقائمة المراجعة.
                        .requestMatchers(HttpMethod.GET,
                                "/api/v1/proof/get-all",
                                "/api/v1/excuse/get",
                                "/api/v1/objection/get-all",
                                "/api/v1/penalty/get/{adminId}",
                                "/api/v1/admin-review/queue/{adminId}").hasAuthority("ADMIN")

                        // إلغاء الخصم وإصدار قرار المراجعة من صلاحيات الأدمن فقط.
                        .requestMatchers(HttpMethod.PUT,
                                "/api/v1/penalty/cancel/{adminId}/{penaltyId}",
                                "/api/v1/admin-review/decide/{adminId}/{kind}/{id}/{accept}").hasAuthority("ADMIN")

                        // العضو يعرض بياناته فقط؛ السيرفس مسؤول عن فحص الملكية بهوية المستخدم المسجل.
                        .requestMatchers(HttpMethod.GET,
                                "/api/v1/proof/get/{id}",
                                "/api/v1/proof/get-my-proofs",
                                "/api/v1/excuse/get/{id}",
                                "/api/v1/objection/get/{id}",
                                "/api/v1/donation-proof/gmail/connect/{memberId}",
                                "/api/v1/donation-proof/my/{memberId}",
                                "/api/v1/penalty/my/{memberId}").hasAuthority("MEMBER")

                        // إضافة الإثبات والعذر والاعتراض وإثبات التبرع للعضو فقط.
                        // معرف العضو في الرابط يجب أن يطابق المستخدم المسجل، وليس مجرد عضو موجود.
                        .requestMatchers(HttpMethod.POST,
                                "/api/v1/proof/add/goal-task/{goalTaskId}/week/{commitmentWeekId}",
                                "/api/v1/excuse/add/goal-task/{goalTaskId}/week/{commitmentWeekId}",
                                "/api/v1/proof/habit/{memberId}/{weekId}",
                                "/api/v1/excuse/habit/{memberId}/{weekId}",
                                "/api/v1/objection/add/proof/{proofId}",
                                "/api/v1/objection/add/excuse/{excuseId}",
                                "/api/v1/donation-proof/screenshot/{memberId}",
                                "/api/v1/donation-proof/email/{memberId}",
                                "/api/v1/donation-proof/objection/{memberId}/{donationProofId}").hasAuthority("MEMBER")

                        // العضو يعدل طلباته حسب حالة الطلب وشروط السيرفس.
                        .requestMatchers(HttpMethod.PUT,
                                "/api/v1/proof/update/goal-task/{proofId}",
                                "/api/v1/excuse/update/goal-task/{excuseId}",
                                "/api/v1/objection/update/{objectionId}").hasAuthority("MEMBER")

                        // العضو يحذف طلباته فقط إذا سمحت حالة الطلب بذلك.
                        .requestMatchers(HttpMethod.DELETE,
                                "/api/v1/proof/delete/goal-task/{proofId}",
                                "/api/v1/excuse/delete/goal-task/{excuseId}",
                                "/api/v1/objection/delete/{objectionId}").hasAuthority("MEMBER")

                        // نمنع أي مسار أو طريقة غير مصنفة داخل الكنترولرز التي راجعناها.
                        .requestMatchers(
                                "/api/v1/proof/**",
                                "/api/v1/excuse/**",
                                "/api/v1/objection/**",
                                "/api/v1/donation-proof/**",
                                "/api/v1/penalty/**",
                                "/api/v1/admin-review/**").denyAll()

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
