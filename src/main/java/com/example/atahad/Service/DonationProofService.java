package com.example.atahad.Service;

import com.example.atahad.AI.AiService;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.DonationScreenshotRequest;
import com.example.atahad.Entity.Admin;
import com.example.atahad.Entity.DonationProof;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.Penalty;
import com.example.atahad.Repository.DonationProofRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.PenaltyRepository;
import com.example.atahad.Service.GmailService.BankEmail;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

// the "I donated" button: the member donates to Ehsan by himself, then proves it in one of two ways:
// 1) EMAIL: the bank email in his Gmail (signed by the bank, DKIM)  2) SCREENSHOT: the bank message + the Ehsan message
// the AI reads the amount, the time, the recipient and the transaction number, then the rules decide:
// the number was never used, the recipient is Ehsan, the time is after the penalty, the amount covers the penalty
@Service
@RequiredArgsConstructor
public class DonationProofService {
    private final AuthenticatedUserService authenticatedUserService;
    private final ProofAttachmentService proofAttachmentService;
    private final DonationProofRepository donationProofRepository;
    private final PenaltyRepository penaltyRepository;
    private final MemberRepository memberRepository;
    private final GmailService gmailService;
    private final LockService lockService;
    private final WhatsAppService whatsAppService;
    private final AiService aiService;

    private static final String EXTRACT_FORMAT = "Answer only with these lines (write NONE when you can not read a value):\n"
            + "BANK: bank name\nAMOUNT: number only, like 25.00\nTIME: yyyy-MM-ddTHH:mm\n"
            + "REFERENCE: the transaction number\nRECIPIENT: who received the money\n"
            + "SUSPICIOUS: YES or NO (edited image, numbers that do not match, not a real bank message)\n"
            + "NOTE: one short sentence in Arabic";

    // ================= the two ways =================

    @Transactional
    public DonationProof submitScreenshot(Integer memberId, DonationScreenshotRequest dto){
        // المعرف في الرابط يجب أن يخص العضو المسجل، وليس أي عضو موجود.
        authenticatedUserService.checkMember(memberId);
        Member member = getMember(memberId);
        if(Boolean.TRUE.equals(member.getScreenshotBanned())){
            throw new ApiException("A fake screenshot was found before, prove your donation with the bank email");
        }
        List<Penalty> pending = pendingPenalties(member);

        DonationProof proof = newProof(member, "SCREENSHOT");
        proof.setBankMessageImageUrl(dto.getBankMessageImageUrl());
        proof.setEhsanMessageImageUrl(dto.getEhsanMessageImageUrl());

        String answer = aiService.askWithImages(
                "You read donation receipts. The first image is the SMS of the bank transfer, the second is the thank you message or the receipt "
                        + "of Ehsan (the Saudi national platform for charity) or of a charity (جمعية خيرية, often chosen from the bank app). "
                        + "Read the transfer details. Both images must be about the same transfer. "
                        + EXTRACT_FORMAT,
                "Read the two images.",
                List.of(proofAttachmentService.resolve(memberId, dto.getBankMessageImageUrl()),
                        proofAttachmentService.resolve(memberId, dto.getEhsanMessageImageUrl())),
                "SUSPICIOUS: YES\nNOTE: الذكاء الاصطناعي غير متاح الحين، بيراجعه الأدمن");
        return evaluate(proof, answer, pending);
    }

    // looks for the bank email in Gmail, sent after the oldest penalty
    @Transactional
    public DonationProof submitEmail(Integer memberId){
        // المعرف في الرابط يجب أن يخص العضو المسجل، وليس أي عضو موجود.
        authenticatedUserService.checkMember(memberId);
        Member member = getMember(memberId);
        List<Penalty> pending = pendingPenalties(member);
        List<BankEmail> emails = gmailService.findBankEmails(member, pending.get(0).getCreatedAt());
        if(emails.isEmpty()){
            throw new ApiException("No bank email found after the penalty yet, try again when the email arrives");
        }

        DonationProof last = null;
        for(BankEmail email : emails){
            String answer = aiService.ask(
                    "You read Saudi bank emails about money transfers and card or Apple Pay purchases. Read the details of the transfer "
                            + "or the purchase (RECIPIENT = who received the money, the merchant of a purchase). " + EXTRACT_FORMAT,
                    "Subject: " + email.subject() + "\nReceived: " + email.receivedAt() + "\n\n" + email.text(),
                    "SUSPICIOUS: YES\nNOTE: الذكاء الاصطناعي غير متاح الحين، بيراجعه الأدمن");
            String recipient = aiService.field(answer, "RECIPIENT");
            if(recipient == null || !isEhsan(recipient)){
                continue; // another transfer, not the donation
            }
            DonationProof proof = newProof(member, "EMAIL");
            proof.setDkimDomain(email.domain());
            proof.setTransactionTime(email.receivedAt()); // when the email has no time of its own
            last = evaluate(proof, answer, pending);
            if("ACCEPTED".equals(last.getStatus())){
                return last;
            }
        }
        if(last == null){
            throw new ApiException("No transfer to Ehsan found in your bank emails after the penalty");
        }
        return last;
    }

    // ================= the rules =================

    private DonationProof evaluate(DonationProof proof, String answer, List<Penalty> pending){
        proof.setBankName(cut(aiService.field(answer, "BANK"), 50));
        proof.setRecipient(cut(aiService.field(answer, "RECIPIENT"), 100));
        proof.setAmount(parseAmount(aiService.field(answer, "AMOUNT")));
        LocalDateTime time = parseTime(aiService.field(answer, "TIME"));
        if(time != null || proof.getTransactionTime() == null){
            proof.setTransactionTime(time);
        }
        String reference = cut(aiService.field(answer, "REFERENCE"), 100);
        String note = aiService.field(answer, "NOTE");
        boolean suspicious = !"NO".equalsIgnoreCase(String.valueOf(aiService.field(answer, "SUSPICIOUS")));
        boolean email = "EMAIL".equals(proof.getMethod());
        if(email){
            // the email is signed by the bank (DKIM), so it is real: no need for the AI's doubt.
            // An Apple Pay / card purchase email often has no transaction number: the bank + the time + the amount
            // make one, so the same email can not be used twice
            suspicious = false;
            if(reference == null && proof.getAmount() != null && proof.getTransactionTime() != null){
                reference = cut("EMAIL-" + proof.getDkimDomain() + "-" + proof.getTransactionTime() + "-" + proof.getAmount().toPlainString(), 100);
            }
        }

        String rejection = null;
        if(reference != null && donationProofRepository.findDonationProofByTransactionReference(reference) != null){
            rejection = "رقم العملية مستخدم قبل";
        }else if(proof.getRecipient() != null && !isEhsan(proof.getRecipient())){
            rejection = "المستلم مو منصة إحسان ولا جمعية خيرية";
        }else if(proof.getTransactionTime() != null && proof.getTransactionTime().isBefore(pending.get(0).getCreatedAt())){
            rejection = "التحويل قبل وقت العقوبة";
        }else if(proof.getAmount() != null && proof.getAmount().compareTo(smallest(pending)) < 0){
            rejection = "المبلغ أقل من العقوبة";
        }

        if(rejection != null){
            proof.setStatus("REJECTED");
            proof.setAiResult(rejection);
            donationProofRepository.save(proof); // the number is not kept, so it does not block a real one later
            return proof;
        }

        proof.setTransactionReference(reference);
        if(suspicious || reference == null || proof.getAmount() == null || proof.getTransactionTime() == null || proof.getRecipient() == null){
            proof.setStatus("ESCALATED");
            proof.setAiResult(cut(note == null ? "بيانات ناقصة، بيراجعه الأدمن" : note, 1000));
            donationProofRepository.save(proof);
            lockService.refresh(proof.getMember()); // the app opens until the admin decides
            return proof;
        }

        proof.setAiResult(cut(note, 1000));
        accept(proof);
        return proof;
    }

    // pays the oldest penalties first with the amount, then opens the app if nothing is left
    @Transactional
    public void accept(DonationProof proof){
        proof.setStatus("ACCEPTED");
        donationProofRepository.save(proof);

        BigDecimal left = proof.getAmount() == null ? BigDecimal.ZERO : proof.getAmount();
        BigDecimal paid = BigDecimal.ZERO;
        for(Penalty penalty : penaltyRepository.findPenaltiesByMemberAndStatus(proof.getMember(), "PENDING")
                .stream().sorted(Comparator.comparing(Penalty::getCreatedAt)).toList()){
            if(left.compareTo(penalty.getAmount()) < 0){
                break;
            }
            penalty.setStatus("PAID");
            penalty.setPaidAt(LocalDateTime.now());
            penalty.setDonationProof(proof);
            penaltyRepository.save(penalty);
            left = left.subtract(penalty.getAmount());
            paid = paid.add(penalty.getAmount());
        }
        Member member = proof.getMember();
        lockService.refresh(member);
        if(!Boolean.TRUE.equals(member.getIsLocked()) && paid.signum() > 0){
            whatsAppService.unlockMessage(member, paid);
        }
    }

    // ================= the admin =================

    @Transactional
    public void review(Admin admin, DonationProof proof, boolean accept, String note){
        if(!"ESCALATED".equals(proof.getStatus()) && !"REJECTED".equals(proof.getStatus())){
            throw new ApiException("This donation proof was already decided");
        }
        proof.setAdmin(admin);
        if(note != null){
            proof.setAiResult(cut(note, 1000));
        }
        if(accept){
            accept(proof);
            return;
        }
        proof.setStatus("REJECTED");
        proof.setTransactionReference(null);
        donationProofRepository.save(proof);
        if("SCREENSHOT".equals(proof.getMethod())){
            Member member = proof.getMember();
            member.setScreenshotBanned(true); // a fake screenshot: only the bank email from now
            memberRepository.save(member);
        }
        lockService.refresh(proof.getMember());
    }

    public List<DonationProof> getEscalated(){
        return donationProofRepository.findDonationProofsByStatus("ESCALATED");
    }

    public List<DonationProof> getMyProofs(Integer memberId){
        // المعرف في الرابط يجب أن يخص العضو المسجل، وليس أي عضو موجود.
        authenticatedUserService.checkMember(memberId);
        getMember(memberId);
        return donationProofRepository.findDonationProofsByMemberIdOrderByCreatedAtDesc(memberId);
    }

    public DonationProof getProof(Integer id){
        DonationProof proof = donationProofRepository.findDonationProofById(id);
        if(proof == null){
            throw new ApiException("Donation proof not found");
        }
        return proof;
    }

    // ================= helpers =================

    private DonationProof newProof(Member member, String method){
        DonationProof proof = new DonationProof();
        proof.setMethod(method);
        proof.setStatus("PENDING");
        proof.setCreatedAt(LocalDateTime.now());
        proof.setMember(member);
        return proof;
    }

    private List<Penalty> pendingPenalties(Member member){
        List<Penalty> pending = new ArrayList<>(penaltyRepository.findPenaltiesByMemberAndStatus(member, "PENDING"));
        if(pending.isEmpty()){
            throw new ApiException("You have no donations to pay");
        }
        pending.sort(Comparator.comparing(Penalty::getCreatedAt));
        return pending;
    }

    private BigDecimal smallest(List<Penalty> pending){
        BigDecimal min = null;
        for(Penalty penalty : pending){
            if(min == null || penalty.getAmount().compareTo(min) < 0){
                min = penalty.getAmount();
            }
        }
        return min;
    }

    // Ehsan, or a charity (the charities the banks list in their apps): جمعية خيرية، مؤسسة خيرية، وقف ...
    private boolean isEhsan(String recipient){
        String text = recipient.toLowerCase();
        return text.contains("احسان") || text.contains("إحسان") || text.contains("ehsan")
                || text.contains("جمعية") || text.contains("جمعيه") || text.contains("خيري")
                || text.contains("وقف") || text.contains("أوقاف") || text.contains("اوقاف")
                || text.contains("charity") || text.contains("charitable");
    }

    private BigDecimal parseAmount(String value){
        if(value == null){
            return null;
        }
        try{
            return new BigDecimal(value.replaceAll("[^0-9.]", ""));
        }catch(Exception e){
            return null;
        }
    }

    private LocalDateTime parseTime(String value){
        if(value == null){
            return null;
        }
        try{
            return LocalDateTime.parse(value.length() == 16 ? value + ":00" : value.substring(0, 19));
        }catch(Exception e){
            return null;
        }
    }

    private Member getMember(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return member;
    }

    private String cut(String text, int max){
        if(text == null){
            return null;
        }
        return text.length() > max ? text.substring(0, max) : text;
    }
}
