package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class ProofAttachmentService {
    private final ProofCaptureService proofCaptureService;

    public void requireExcuseDocument(Integer memberId, String reference) {
        if (reference == null || reference.isBlank()) {
            throw new ApiException("أرفق مستندًا داعمًا للعذر");
        }
        if (!reference.matches("capture:[0-9]+")) {
            throw new ApiException("ارفعي صورة المستند أولًا ثم أرسل مرجع المرفق");
        }
        resolve(memberId, reference);
    }

    // save a short reference, the AI gets the image itself (not a localhost link)
    public String resolve(Integer memberId, String value) {
        if (value == null || !value.startsWith("capture:")) { return value; }
        Integer captureId;
        try { captureId = Integer.valueOf(value.substring(8)); }
        catch (NumberFormatException exception) { throw new ApiException("Invalid attachment reference"); }
        String image = proofCaptureService.read(memberId, captureId).getImageData();
        if (image == null) { throw new ApiException("Attachment upload is not complete"); }
        return image;
    }
}
