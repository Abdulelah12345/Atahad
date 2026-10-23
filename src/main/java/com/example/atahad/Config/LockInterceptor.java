package com.example.atahad.Config;

import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.UserRepository;
import com.example.atahad.Service.LockService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationTrustResolverImpl;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

// نطبق قفل العمليات على صاحب جلسة الدخول، وليس على معرف يختاره في الرابط.
// الخصومات لا تمنع الدخول؛ يظل التبرع والعذر والاعتراض متاحًا حسب قواعد LockService.
@Component
@RequiredArgsConstructor
public class LockInterceptor implements HandlerInterceptor {
    private final MemberRepository memberRepository;
    private final UserRepository userRepository;
    private final LockService lockService;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null) {
            return true; // السكيورتي تتولى رفض الطلبات التي تحتاج تسجيل الدخول.
        }
        if (new AuthenticationTrustResolverImpl().isAnonymous(authentication)) {
            return true; // مثل تسجيل حساب عضو أو رجوع Google.
        }

        User user = userRepository.findUserByEmail(authentication.getName());
        if (user == null) {
            response.sendError(401, "Login is required");
            return false;
        }
        if (user.getRole() != null) {
            boolean isAdmin = user.getRole().equals("ADMIN");
            if (isAdmin) {
                return true;
            }
        }

        Member member = memberRepository.findMemberById(user.getId());
        if (member == null) {
            response.sendError(403, "Member profile is required");
            return false;
        }
        String reason = lockService.blockReason(member, request.getMethod(), request.getRequestURI());
        if (reason == null) {
            return true;
        }
        response.setStatus(403);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"message\":\"" + reason.replace("\"", "'") + "\"}");
        return false;
    }
}
