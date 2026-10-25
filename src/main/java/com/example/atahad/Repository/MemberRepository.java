package com.example.atahad.Repository;

import com.example.atahad.Entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MemberRepository extends JpaRepository<Member, Integer> {
    Member findMemberById(Integer id);

    // the phone is in the user of the member (+966501234567)
    Member findMemberByUserPhone(String phone);

}
