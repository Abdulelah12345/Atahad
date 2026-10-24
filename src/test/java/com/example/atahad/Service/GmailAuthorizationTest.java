package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class GmailAuthorizationTest {
    private final AuthenticatedUserService identity = mock(AuthenticatedUserService.class);
    private final MemberRepository members = mock(MemberRepository.class);
    private final GmailService service = new GmailService(identity, members);
    private final MockHttpSession session = new MockHttpSession();

    @BeforeEach
    void configure() {
        ReflectionTestUtils.setField(service, "clientId", "test-client");
        ReflectionTestUtils.setField(service, "clientSecret", "test-secret");
        ReflectionTestUtils.setField(service, "redirectUri", "http://localhost/callback");
    }

    @Test
    void connectBindsRandomStateToTheOwnerSession() {
        String link = service.connectLink(7, session);
        String state = (String) session.getAttribute("gmailOAuthState");
        assertNotNull(state);
        assertNotEquals("7", state);
        assertTrue(link.contains("&state=" + state));
        assertEquals(7, session.getAttribute("gmailOAuthMemberId"));
        verify(identity).checkMember(7);
    }

    @Test
    void cannotStartLinkingForAnotherMember() {
        doThrow(new AccessDeniedException("Not your member")).when(identity).checkMember(8);
        assertThrows(AccessDeniedException.class, () -> service.connectLink(8, session));
        assertNull(session.getAttribute("gmailOAuthState"));
    }

    @Test
    void callbackWithoutInitiatingSessionIsRejectedBeforeExternalCalls() {
        assertThrows(ApiException.class, () -> service.finishConnect("unused", "7", session));
        verifyNoInteractions(members);
    }

    @Test
    void wrongStateIsRejectedBeforeExternalCalls() {
        service.connectLink(7, session);
        assertThrows(ApiException.class, () -> service.finishConnect("unused", "wrong", session));
        verifyNoInteractions(members);
    }

    @Test
    void expiredStateIsRejectedBeforeExternalCalls() {
        service.connectLink(7, session);
        String state = (String) session.getAttribute("gmailOAuthState");
        session.setAttribute("gmailOAuthExpiresAt", Instant.now().minusSeconds(1).getEpochSecond());
        assertThrows(ApiException.class, () -> service.finishConnect("unused", state, session));
        verifyNoInteractions(members);
    }
}
