package com.example.atahad.Config;

import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Service.LockService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;

import java.util.List;
import java.util.Map;

// runs before every endpoint: if the path has the member id (memberId, userId, senderId or ownerId)
// and the member is locked, banned or deactivated, the request stops here with 403
@Component
@RequiredArgsConstructor
public class LockInterceptor implements HandlerInterceptor {
    private final MemberRepository memberRepository;
    private final LockService lockService;

    private static final List<String> MEMBER_KEYS = List.of("memberId", "userId", "senderId", "ownerId");

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if(!(handler instanceof HandlerMethod)){
            return true;
        }
        Object attribute = request.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE);
        if(!(attribute instanceof Map<?, ?> variables)){
            return true;
        }
        if(variables.containsKey("adminId")){
            return true; // an admin action on a member (unban, review ...)
        }
        Integer memberId = null;
        for(String key : MEMBER_KEYS){
            Object value = variables.get(key);
            if(value != null){
                try{
                    memberId = Integer.valueOf(value.toString());
                }catch(NumberFormatException e){
                    return true; // the controller advice answers the wrong id
                }
                break;
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
}
