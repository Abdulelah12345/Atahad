package com.example.atahad.Service;

import com.example.atahad.Dto.In.AdminRegisterRequest;
import com.example.atahad.Dto.In.MemberRegisterRequest;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.*;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class RegistrationSecurityTest {
    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder encoder = new BCryptPasswordEncoder();

    @Test
    void memberPasswordIsEncodedBeforeSaving() {
        MemberService service = new MemberService(mock(MemberRepository.class), users, encoder, mock(CommitmentWeekService.class));
        service.registerMember(new MemberRegisterRequest("Member", "member@example.test", "+966501234567", "test-password"));
        ArgumentCaptor<User> captured = ArgumentCaptor.forClass(User.class);
        verify(users).save(captured.capture());
        User user = captured.getValue();
        assertNotEquals("test-password", user.getPassword());
        assertTrue(encoder.matches("test-password", user.getPassword()));
        assertEquals("MEMBER", user.getRole());
    }

    @Test
    void adminPasswordIsEncodedBeforeSaving() {
        AdminService service = new AdminService(mock(AdminRepository.class), users, encoder);
        service.registerAdmin(new AdminRegisterRequest("Admin", "admin@example.test", "+966501234567", "test-password", "Reviewer"));
        ArgumentCaptor<User> captured = ArgumentCaptor.forClass(User.class);
        verify(users).save(captured.capture());
        assertTrue(encoder.matches("test-password", captured.getValue().getPassword()));
        assertNotEquals("test-password", captured.getValue().getPassword());
        assertEquals("ADMIN", captured.getValue().getRole());
    }
}
