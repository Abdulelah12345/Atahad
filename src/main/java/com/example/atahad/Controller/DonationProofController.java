package com.example.atahad.Controller;

import com.example.atahad.Api.ApiResponse;
import com.example.atahad.Dto.In.DonationScreenshotRequest;
import com.example.atahad.Dto.In.GmailConnectRequest;
import com.example.atahad.Dto.In.ObjectionRequest;
import com.example.atahad.Service.DonationProofService;
import com.example.atahad.Service.GmailService;
import com.example.atahad.Service.ObjectionDecisionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

// the "I donated" button, these endpoints work while the app is locked
@RestController
@RequestMapping("/api/v1/donation-proof")
@RequiredArgsConstructor
public class DonationProofController {
    private final DonationProofService donationProofService;
    private final GmailService gmailService;
    private final ObjectionDecisionService objectionDecisionService;

    // way 1: the bank SMS + the Ehsan SMS screenshots
    @PostMapping("/screenshot/{memberId}")
    public ResponseEntity<?> submitScreenshot(@PathVariable Integer memberId, @RequestBody @Valid DonationScreenshotRequest dto){
        return ResponseEntity.status(200).body(donationProofService.submitScreenshot(memberId, dto));
    }

    // way 2: the bank email in Gmail (link Gmail first)
    @PostMapping("/email/{memberId}")
    public ResponseEntity<?> submitEmail(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(donationProofService.submitEmail(memberId));
    }

    // links the Gmail with an App Password, the login is tried first
    @PostMapping("/gmail/connect/{memberId}")
    public ResponseEntity<?> connectGmail(@PathVariable Integer memberId, @RequestBody @Valid GmailConnectRequest dto){
        gmailService.connect(memberId, dto);
        return ResponseEntity.status(200).body(new ApiResponse("Gmail linked"));
    }

    @DeleteMapping("/gmail/disconnect/{memberId}")
    public ResponseEntity<?> disconnectGmail(@PathVariable Integer memberId){
        gmailService.disconnect(memberId);
        return ResponseEntity.status(200).body(new ApiResponse("Gmail unlinked"));
    }

    @GetMapping("/my/{memberId}")
    public ResponseEntity<?> getMyProofs(@PathVariable Integer memberId){
        return ResponseEntity.status(200).body(donationProofService.getMyProofs(memberId));
    }

    // within 48 hours of a rejection
    @PostMapping("/objection/{memberId}/{donationProofId}")
    public ResponseEntity<?> object(@PathVariable Integer memberId, @PathVariable Integer donationProofId, @RequestBody @Valid ObjectionRequest request){
        return ResponseEntity.status(200).body(objectionDecisionService.addDonationObjection(memberId, donationProofId, request));
    }
}
