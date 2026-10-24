package com.example.atahad.Config;

import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.UserRepository;
import com.example.atahad.Service.LockService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class LockInterceptorTest {
    private final MemberRepository members = mock(MemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final LockService locks = mock(LockService.class);
    private final LockInterceptor interceptor = new LockInterceptor(members, users, locks);

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private Member login() {
        User user = new User();
        user.setId(7);
        user.setEmail("member@example.test");
        user.setRole("MEMBER");
        Member member = new Member();
        member.setId(7);
        when(users.findUserByEmail(user.getEmail())).thenReturn(user);
        when(members.findMemberById(7)).thenReturn(member);
        SecurityContextHolder.getContext().setAuthentication(
                UsernamePasswordAuthenticationToken.authenticated(user, null, user.getAuthorities()));
        return member;
    }

    @Test
    void proofRouteWithoutMemberIdStillAppliesTheOwnersLock() throws Exception {
        Member member = login();
        String path = "/api/v1/proof/add/goal-task/1/week/2";
        when(locks.blockReason(member, "POST", path)).thenReturn("Locked");
        MockHttpServletResponse response = new MockHttpServletResponse();
        assertFalse(interceptor.preHandle(new MockHttpServletRequest("POST", path), response, new Object()));
        assertEquals(403, response.getStatus());
    }

    @Test
    void idInPathCannotSelectAnotherMembersLockState() throws Exception {
        Member member = login();
        String path = "/api/v1/proof/habit/99/2";
        assertTrue(interceptor.preHandle(new MockHttpServletRequest("POST", path), new MockHttpServletResponse(), new Object()));
        verify(locks).blockReason(member, "POST", path);
        verify(members, never()).findMemberById(99);
    }
}
