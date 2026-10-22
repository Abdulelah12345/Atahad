package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Admin;
import com.example.atahad.Entity.CommitmentWeek;
import com.example.atahad.Entity.GraceDay;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.AdminRepository;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GraceDayRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class GraceDayService {

    private final GraceDayRepository graceDayRepository;
    private final MemberRepository memberRepository;
    private final AdminRepository adminRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;

    public List<GraceDay> getAllGraceDays() {
        return graceDayRepository.findAll();
    }

    public GraceDay getGraceDayById(Integer id) {
        GraceDay graceDay = graceDayRepository.findGraceDayById(id);

        if (graceDay == null) {
            throw new ApiException("Grace day not found");
        }

        return graceDay;
    }

    public List<GraceDay> getMemberGraceDays(Integer memberId) {
        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        return graceDayRepository.findGraceDaysByMemberId(memberId);
    }

    @Transactional
    public void grantGraceDay(Integer adminId, Integer memberId, String reason) {

        Admin admin = adminRepository.findAdminById(adminId);

        if (admin == null) {
            throw new ApiException("Admin not found");
        }

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        if (reason == null || reason.isBlank() || reason.length() > 255) {
            throw new ApiException("Valid grant reason is required");
        }

        GraceDay graceDay = new GraceDay();
        graceDay.setSource("ADMIN_GRANTED");
        graceDay.setGrantReason(reason);
        graceDay.setEarnedAt(LocalDate.now());
        graceDay.setExpiresAt(LocalDate.now().plusWeeks(4));
        graceDay.setMember(member);
        graceDay.setAdmin(admin);

        graceDayRepository.save(graceDay);
    }

    @Transactional
    public void earnGraceDay(Integer memberId) {

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        // TODO: Check member's streak before awarding a grace day.

        GraceDay graceDay = new GraceDay();
        graceDay.setSource("PERSONAL_POINTS");
        graceDay.setEarnedAt(LocalDate.now());
        graceDay.setExpiresAt(LocalDate.now().plusWeeks(4));
        graceDay.setMember(member);

        graceDayRepository.save(graceDay);
    }

    @Transactional
    public void useGraceDay(Integer graceDayId, Integer memberId, Integer weekId) {

        GraceDay graceDay = graceDayRepository.findGraceDayById(graceDayId);

        if (graceDay == null) {
            throw new ApiException("Grace day not found");
        }

        if (!graceDay.getMember().getId().equals(memberId)) {
            throw new ApiException("This grace day does not belong to the member");
        }

        if (graceDay.getUsedAt() != null) {
            throw new ApiException("Grace day already used");
        }

        if (graceDay.getExpiresAt().isBefore(LocalDate.now())) {
            throw new ApiException("Grace day has expired");
        }

        CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(weekId);

        if (week == null) {
            throw new ApiException("Commitment week not found");
        }

        if (!week.getCommitment().getMember().getId().equals(memberId)) {
            throw new ApiException("Commitment week does not belong to the member");
        }

        if ("SETTLED".equals(week.getTrackStatus())) {
            throw new ApiException("Cannot use grace day on a settled week");
        }

        if (week.getGraceDay() != null) {
            throw new ApiException("Commitment week already has a grace day");
        }

        graceDay.setUsedAt(LocalDate.now());
        graceDay.setCommitmentWeek(week);

        graceDayRepository.save(graceDay);
    }
}