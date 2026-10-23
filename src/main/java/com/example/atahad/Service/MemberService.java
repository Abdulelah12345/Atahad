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
import org.springframework.security.crypto.password.PasswordEncoder;
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
    private final PasswordEncoder passwordEncoder;
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
        // نخزن BCrypt فقط؛ لا نخزن كلمة المرور الأصلية.
        user.setPassword(passwordEncoder.encode(dto.getPassword()));
        user.setRole("MEMBER");
        user.setCreatedAt(LocalDateTime.now());

        userRepository.save(user);

        Member member = new Member();
        member.setUser(user);
        member.setLevel("BEGINNER");
        member.setConsecutiveWeeks(0);
        member.setPoints(0);
        member.setIsLocked(false);
        member.setEmailLinked(false);
        member.setScreenshotBanned(false);
        member.setGroupRefusalCount(0);
        member.setGroupBannedForever(false);
        member.setAccountBanned(false);

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
                member.getLevel(),
                member.getConsecutiveWeeks(),
                member.getPoints(),
                member.getIsLocked(),
                member.getEmailLinked(),
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