package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class ProofAttachmentService {
    private final ProofCaptureService proofCaptureService;

    // نحفظ مرجعا قصيرا للصورة، ونرسل محتواها الفعلي للذكاء؛ لا نرسل رابط localhost للمزود.
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
