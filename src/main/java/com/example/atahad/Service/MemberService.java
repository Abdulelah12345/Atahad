package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.MemberRegisterRequest;
import com.example.atahad.Dto.In.MemberUpdateRequest;
import com.example.atahad.Dto.Out.MemberResponse;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;
    private final UserRepository userRepository;
    private final PaymentHoldService paymentHoldService;
    private final CommitmentWeekService commitmentWeekService;
    @Transactional
    public void registerMember(MemberRegisterRequest dto) {

        User existingUser = userRepository.findUserByEmail(dto.getEmail());

        if (existingUser != null) {
            throw new ApiException("Email already exists");
        }

        User user = new User();
        user.setName(dto.getName());
        user.setEmail(dto.getEmail());
        user.setPhone(dto.getPhone());
        user.setPassword(dto.getPassword());
        user.setRole("MEMBER");
        user.setCreatedAt(LocalDateTime.now());

        userRepository.save(user);

        Member member = new Member();
        member.setUser(user);
//        member.setPlan("FREE_TRIAL");
//        member.setTrialEndsAt(LocalDate.now().plusMonths(1));
        member.setLevel("BEGINNER");
        member.setConsecutiveWeeks(0);
        member.setTaskPoints(0);
        member.setCanCreateCommitment(true);
        member.setHasNoHoldPrivilege(false);

        memberRepository.save(member);
    }

    public List<MemberResponse> getAllMembers() {

        List<Member> members = memberRepository.findAll();
        List<MemberResponse> memberResponses = new ArrayList<>();

        for (Member member : members) {
            memberResponses.add(convertToDTO(member));
        }

        return memberResponses;
    }

    public MemberResponse getMemberById(Integer id) {

        Member member = memberRepository.findMemberById(id);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        return convertToDTO(member);
    }

    @Transactional
    public void updateMember(Integer id, MemberUpdateRequest dto) {

        Member member = memberRepository.findMemberById(id);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        User user = member.getUser();

        User existingUser = userRepository.findUserByEmail(dto.getEmail());

        if (existingUser != null && !existingUser.getId().equals(id)) {
            throw new ApiException("Email already exists");
        }

        user.setName(dto.getName());
        user.setEmail(dto.getEmail());
        user.setPhone(dto.getPhone());

        userRepository.save(user);
    }

    public MemberResponse convertToDTO(Member member) {

        User user = member.getUser();

        return new MemberResponse(
                member.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
//                member.getPlan(),
//                member.getTrialEndsAt(),
                member.getRenewsAt(),
                member.getCardType(),
                member.getLevel(),
                member.getConsecutiveWeeks(),
                member.getTaskPoints(),
                member.getCanCreateCommitment(),
                member.getHasNoHoldPrivilege(),
                user.getCreatedAt()
        );
    }
    public void deleteMember(Integer id) {
        Member member = memberRepository.findMemberById(id);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        memberRepository.delete(member);
    }
}