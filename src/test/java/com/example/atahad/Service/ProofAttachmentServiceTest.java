package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.ProofCapture;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ProofAttachmentServiceTest {
    private final ProofCaptureService captures = mock(ProofCaptureService.class);
    private final ProofAttachmentService service = new ProofAttachmentService(captures);

    @Test void resolvesOnlyTheOwnersUploadedImage() {
        ProofCapture capture = new ProofCapture();
        capture.setImageData("data:image/png;base64,image");
        when(captures.read(7, 22)).thenReturn(capture);
        assertEquals(capture.getImageData(), service.resolve(7, "capture:22"));
        verify(captures).read(7, 22);
    }

    @Test void anotherMembersReferenceIsRejected() {
        when(captures.read(8, 22)).thenThrow(new AccessDeniedException("Not your capture"));
        assertThrows(AccessDeniedException.class, () -> service.resolve(8, "capture:22"));
    }

    @Test void invalidAndUnfinishedReferencesCannotReachTheAi() {
        assertThrows(ApiException.class, () -> service.resolve(7, "capture:invalid"));
        when(captures.read(7, 22)).thenReturn(new ProofCapture());
        assertThrows(ApiException.class, () -> service.resolve(7, "capture:22"));
    }

    @Test void existingExternalReferencesRemainSupported() {
        assertEquals("https://example.test/image.png", service.resolve(7, "https://example.test/image.png"));
        assertNull(service.resolve(7, null));
        verifyNoInteractions(captures);
    }
}
