package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Controller.ExcuseController;
import com.example.atahad.Controller.HabitCheckInController;
import com.example.atahad.Entity.ProofCapture;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ExcuseDocumentRequirementTest {
    @Test void allExcuseWriteRoutesRejectAbsentBlankAndNullDocumentsBeforeCallingServices() throws Exception {
        ExcuseService goals = mock(ExcuseService.class);
        ExcuseDecisionService habits = mock(ExcuseDecisionService.class);
        var mvc = MockMvcBuilders.standaloneSetup(new ExcuseController(goals),
                new HabitCheckInController(mock(AuthenticatedUserService.class), mock(ProofDecisionService.class), habits)).build();
        for (String evidence : new String[]{"", ",\"evidenceUrl\":null", ",\"evidenceUrl\":\"  \""}) {
            String body = "{\"type\":\"SICK\",\"excuseDate\":\"2026-10-25\"" + evidence + "}";
            mvc.perform(post("/api/v1/excuse/add/goal-task/1/week/2").contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isBadRequest());
            mvc.perform(put("/api/v1/excuse/update/goal-task/1").contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isBadRequest());
            mvc.perform(post("/api/v1/excuse/habit/1/2").contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isBadRequest());
        }
        verifyNoInteractions(goals, habits);
    }

    @Test void onlyAnUploadedDocumentOwnedByTheMemberCanBeUsed() {
        ProofCaptureService captures = mock(ProofCaptureService.class);
        ProofAttachmentService service = new ProofAttachmentService(captures);
        assertThrows(ApiException.class, () -> service.requireExcuseDocument(7, null));
        assertThrows(ApiException.class, () -> service.requireExcuseDocument(7, "   "));
        assertThrows(ApiException.class, () -> service.requireExcuseDocument(7, "not-a-document"));
        when(captures.read(7, 22)).thenReturn(new ProofCapture());
        assertThrows(ApiException.class, () -> service.requireExcuseDocument(7, "capture:22"));
        when(captures.read(7, 23)).thenThrow(new AccessDeniedException("Not your capture"));
        assertThrows(AccessDeniedException.class, () -> service.requireExcuseDocument(7, "capture:23"));
        ProofCapture uploaded = new ProofCapture();
        uploaded.setImageData("data:image/png;base64,image");
        when(captures.read(7, 24)).thenReturn(uploaded);
        assertDoesNotThrow(() -> service.requireExcuseDocument(7, "capture:24"));
    }
}
