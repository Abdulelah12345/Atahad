package com.example.atahad.Service;

import com.example.atahad.Entity.Admin;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AuthenticatedUserServiceTest {
    private final UserRepository repository = mock(UserRepository.class);
    private final AuthenticatedUserService service = new AuthenticatedUserService(repository);

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private void login(String role) {
        User user = new User();
        user.setId(7);
        user.setEmail("owner@example.test");
        user.setRole(role);
        Member member = new Member();
        member.setId(7);
        Admin admin = new Admin();
        admin.setId(7);
        user.setMember(member);
        user.setAdmin(admin);
        when(repository.findUserByEmail(user.getEmail())).thenReturn(user);
        SecurityContextHolder.getContext().setAuthentication(
                UsernamePasswordAuthenticationToken.authenticated(user, null, user.getAuthorities()));
    }

    @Test
    void ownMemberIdIsAllowed() {
        login("MEMBER");
        assertDoesNotThrow(() -> service.checkMember(7));
    }

    @Test
    void anotherMemberIdIsForbidden() {
        login("MEMBER");
        assertThrows(AccessDeniedException.class, () -> service.checkMember(8));
    }

    @Test
    void ownAdminIdentityIsAllowed() {
        login("ADMIN");
        assertDoesNotThrow(() -> service.checkAdmin(7));
    }

    @Test
    void anotherAdminIdentityIsForbidden() {
        login("ADMIN");
        assertThrows(AccessDeniedException.class, () -> service.checkAdmin(8));
    }

    @Test
    void memberCannotUseAdminIdentityEvenWhenIdsMatch() {
        login("MEMBER");
        assertThrows(AccessDeniedException.class, () -> service.checkAdmin(7));
    }

    @Test
    void missingLoginIsRejected() {
        SecurityContextHolder.clearContext();
        assertThrows(AuthenticationCredentialsNotFoundException.class, () -> service.checkMember(7));
    }
}
