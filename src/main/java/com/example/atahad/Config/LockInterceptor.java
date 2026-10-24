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
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;

import java.util.List;
import java.util.Map;

// runs before every endpoint: if the member who sends the request is locked, banned or deactivated,
// the request stops here with 403 (only "I donated", "I have an excuse" and reading are allowed, see LockService)
// the member is the logged in user, and for the parts without login yet, the member id in the path
@Component
@RequiredArgsConstructor
public class LockInterceptor implements HandlerInterceptor {
    private final MemberRepository memberRepository;
    private final UserRepository userRepository;
    private final LockService lockService;

    private static final List<String> MEMBER_KEYS = List.of("memberId", "userId", "senderId", "ownerId");

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null) {
            return true; // السكيورتي تتولى رفض الطلبات التي تحتاج تسجيل الدخول.
        }
        if (new AuthenticationTrustResolverImpl().isAnonymous(authentication)) {
            return true; // مثل تسجيل حساب عضو أو رجوع Google.
        }
        Integer memberId = loggedInMember();
        if(memberId == null){
            if(isLoggedInAdmin()){
                return true; // an admin is never locked
            }
        }
        if(memberId == null){
            return true;
        }
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            return true; // the service answers "Member not found"
        }
        String reason = lockService.blockReason(member, request.getMethod(), request.getRequestURI());
        if(reason == null){
            return true;
        }
        response.setStatus(403);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"message\":\"" + reason.replace("\"", "'") + "\"}");
        return false;
    }

    // the logged in member (his user id is his member id), null when nobody is logged in or it is an admin
    private Integer loggedInMember(){
        User user = loggedInUser();
        return user != null && "MEMBER".equals(user.getRole()) ? user.getId() : null;
    }

    private boolean isLoggedInAdmin(){
        User user = loggedInUser();
        return user != null && "ADMIN".equals(user.getRole());
    }

    private User loggedInUser(){
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if(authentication != null && authentication.getPrincipal() instanceof User user){
            return user;
        }
        return null;
    }

    // the old way, for the endpoints that still have the member id in the path
    private Integer memberFromPath(HttpServletRequest request){
        Object attribute = request.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE);
        if(!(attribute instanceof Map<?, ?> variables) || variables.containsKey("adminId")){
            return null; // adminId = an admin action on a member (unban, review ...)
        }
        for(String key : MEMBER_KEYS){
            Object value = variables.get(key);
            if(value != null){
                try{
                    return Integer.valueOf(value.toString());
                }catch(NumberFormatException e){
                    return null; // the controller advice answers the wrong id
                }
            }
        }
        return null;
    }
}
