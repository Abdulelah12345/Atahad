package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

// what the admin does with member accounts: find them, suspend and restore
@Service
@RequiredArgsConstructor
public class AdminMemberService {

    public static final String SUSPENDED = "SUSPENDED";

    private final MemberRepository memberRepository;

    // by name, email or phone (empty = everyone)
    public List<Map<String, Object>> search(String query) {
        String q = query == null ? "" : query.trim().toLowerCase();
        List<Map<String, Object>> result = new ArrayList<>();
        for (Member member : memberRepository.findAll()) {
            User user = member.getUser();
            if (user == null) {
                continue;
            }
            String text = (user.getName() + " " + user.getEmail() + " " + user.getPhone()).toLowerCase();
            if (!q.isEmpty() && !text.contains(q)) {
                continue;
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", member.getId());
            row.put("name", user.getName());
            row.put("email", user.getEmail());
            row.put("phone", user.getPhone());
            row.put("level", member.getLevel());
            row.put("points", member.getPoints());
            row.put("isLocked", member.getIsLocked());
            row.put("accountBanned", member.getAccountBanned());
            row.put("accountStatus", member.getAccountStatus() == null ? "ACTIVE" : member.getAccountStatus());
            result.add(row);
        }
        return result;
    }

    // a suspended member can't log in until the admin restores him, his data stays as it is
    public void suspend(Integer memberId) {
        Member member = getMember(memberId);
        if (SUSPENDED.equals(member.getAccountStatus())) {
            throw new ApiException("This account is already suspended");
        }
        if ("DEACTIVATED".equals(member.getAccountStatus())) {
            throw new ApiException("This account is deactivated by its owner");
        }
        member.setAccountStatus(SUSPENDED);
        memberRepository.save(member);
    }

    public void restore(Integer memberId) {
        Member member = getMember(memberId);
        if (!SUSPENDED.equals(member.getAccountStatus())) {
            throw new ApiException("This account is not suspended");
        }
        member.setAccountStatus("ACTIVE");
        memberRepository.save(member);
    }

    private Member getMember(Integer memberId) {
        Member member = memberRepository.findMemberById(memberId);
        if (member == null) {
            throw new ApiException("Member not found");
        }
        return member;
    }
}
