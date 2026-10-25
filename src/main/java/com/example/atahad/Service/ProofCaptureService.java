package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import com.example.atahad.Dto.In.CaptureUploadRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.access.AccessDeniedException;
import java.util.*;
import java.io.ByteArrayInputStream;
import javax.imageio.ImageIO;

@Service @RequiredArgsConstructor
public class ProofCaptureService {
    private final ProofCaptureRepository captures;
    private final ProofRepository proofs;
    private final ProofTime time;

    @Transactional
    public Map<String,Object> start(Integer memberId, String kind, Integer proofId) {
        if (!List.of("BEFORE","AFTER","PAGE","PHOTO").contains(kind)) { throw new ApiException("Invalid capture kind"); }
        if (proofId != null) { ownProof(memberId, proofId); }
        if (kind.equals("AFTER") && proofId == null) { throw new ApiException("An after photo needs a proof attempt"); }
        ProofCapture capture = new ProofCapture();
        capture.setMemberId(memberId); capture.setKind(kind); capture.setProofId(proofId);
        capture.setToken(UUID.randomUUID().toString()); capture.setExpiresAt(time.now().plusMinutes(5));
        captures.save(capture);
        return Map.of("captureId",capture.getId(),"token",capture.getToken(),"expiresAt",capture.getExpiresAt());
    }

    @Transactional
    public ProofCapture upload(Integer memberId,Integer id,CaptureUploadRequest request) {
        ProofCapture capture = captures.findForUpdate(id);
        if (capture == null || !capture.getMemberId().equals(memberId)) { throw new AccessDeniedException("Not your capture"); }
        if (capture.getImageData() != null) { throw new ApiException("This capture was already uploaded"); }
        if (!capture.getToken().equals(request.getToken()) || !time.now().isBefore(capture.getExpiresAt())) { throw new ApiException("Capture expired or invalid"); }
        String data = request.getImageData();
        if (!(data.startsWith("data:image/jpeg;base64,") || data.startsWith("data:image/png;base64,"))) { throw new ApiException("Use a camera JPEG or PNG"); }
        try {
            byte[] bytes = Base64.getDecoder().decode(data.substring(data.indexOf(',')+1));
            if (bytes.length == 0 || bytes.length > 2*1024*1024) { throw new ApiException("Image must be at most 2 MB"); }
            try (var input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
                var readers = ImageIO.getImageReaders(input);
                if (!readers.hasNext()) { throw new ApiException("Invalid image"); }
                var reader = readers.next();
                try {
                    reader.setInput(input);
                    long pixels = (long)reader.getWidth(0)*reader.getHeight(0);
                    if (pixels > 16000000 || pixels < 1) { throw new ApiException("Image dimensions are invalid"); }
                } finally { reader.dispose(); }
            }
            capture.setFingerprint(HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(bytes)));
        } catch (ApiException exception) { throw exception; }
        catch (Exception exception) { throw new ApiException("Invalid image data"); }
        capture.setImageData(data); capture.setCapturedAt(time.now()); capture.setToken(null);
        return captures.save(capture);
    }

    @Transactional
    public ProofCapture use(Integer memberId,Integer id,String kind,Integer proofId) {
        ProofCapture capture = captures.findForUpdate(id);
        if (capture == null || !capture.getMemberId().equals(memberId)) { throw new AccessDeniedException("Not your capture"); }
        if (!capture.getKind().equals(kind) || capture.getImageData() == null) { throw new ApiException("Capture is not ready for this use"); }
        if (capture.getUsedAt() != null) { throw new ApiException("Capture was already used"); }
        if (capture.getProofId() != null && !capture.getProofId().equals(proofId)) { throw new ApiException("Capture belongs to another attempt"); }
        if (kind.equals("BEFORE") && !time.now().isBefore(capture.getExpiresAt())) { throw new ApiException("Take the before photo when starting the activity"); }
        capture.setProofId(proofId); capture.setUsedAt(time.now());
        return captures.save(capture);
    }

    public ProofCapture read(Integer memberId,Integer id) {
        ProofCapture capture = captures.findById(id).orElseThrow(() -> new ApiException("Capture not found"));
        if (!capture.getMemberId().equals(memberId)) { throw new AccessDeniedException("Not your capture"); }
        return capture;
    }
    public Proof ownProof(Integer memberId,Integer id) {
        Proof proof = proofs.findProofById(id);
        if (proof == null) { throw new ApiException("Proof not found"); }
        if (!proof.getCommitmentWeek().getCommitment().getMember().getId().equals(memberId)) { throw new AccessDeniedException("Not your proof"); }
        return proof;
    }
}
