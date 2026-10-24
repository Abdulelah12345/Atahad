package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.PenaltyResponse;
import com.example.atahad.Entity.Admin;
import com.example.atahad.Entity.Penalty;
import com.example.atahad.Repository.AdminRepository;
import com.example.atahad.Repository.MemberRepository;
import com.example.atahad.Repository.PenaltyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

// penalties are made by the app (lost time, withdrawal, group settlement), here only showing them
// and the admin can cancel one by mistake
@Service
@RequiredArgsConstructor
public class PenaltyService {
    private final AuthenticatedUserService authenticatedUserService;
    private final PenaltyRepository penaltyRepository;
    private final MemberRepository memberRepository;
    private final AdminRepository adminRepository;
    private final LockService lockService;

    // the donations history of the member: waiting, paid and cancelled
    public List<PenaltyResponse> getMyPenalties(Integer memberId){
        // المعرف في الرابط يجب أن يخص العضو المسجل، وليس أي عضو موجود.
        authenticatedUserService.checkMember(memberId);
        if(memberRepository.findMemberById(memberId) == null){
            throw new ApiException("Member not found");
        }
        List<PenaltyResponse> list = new ArrayList<>();
        for(Penalty penalty : penaltyRepository.findPenaltiesByMemberIdOrderByCreatedAtDesc(memberId)){
            list.add(toResponse(penalty));
        }
        return list;
    }

    // admin
    public List<PenaltyResponse> getAll(Integer adminId){
        getAdmin(adminId);
        List<PenaltyResponse> list = new ArrayList<>();
        for(Penalty penalty : penaltyRepository.findAll()){
            list.add(toResponse(penalty));
        }
        return list;
    }

    // admin: a penalty made by mistake, the app opens if nothing else is owed
    @Transactional
    public void cancel(Integer adminId, Integer penaltyId){
        getAdmin(adminId);
        Penalty penalty = penaltyRepository.findPenaltyById(penaltyId);
        if(penalty == null){
            throw new ApiException("Penalty not found");
        }
        if(!"PENDING".equals(penalty.getStatus())){
            throw new ApiException("Only a penalty that was not paid can be cancelled");
        }
        penalty.setStatus("CANCELLED");
        penaltyRepository.save(penalty);
        lockService.refresh(penalty.getMember());
    }

    private PenaltyResponse toResponse(Penalty penalty){
        String about = null;
        if(penalty.getGroupSettlement() != null){
            about = penalty.getGroupSettlement().getGroupGoal().getGroup().getName() + " - " + penalty.getGroupSettlement().getGroupGoal().getTitle();
        }else if(penalty.getCommitmentWeek() != null){
            about = penalty.getCommitmentWeek().getCommitment().getTitle()
                    + (penalty.getGoalTask() == null ? "" : " - " + penalty.getGoalTask().getTitle());
        }
        return new PenaltyResponse(penalty.getId(), penalty.getMember().getId(), penalty.getAmount(), penalty.getReason(),
                penalty.getStatus(), about, penalty.getCreatedAt(), penalty.getPaidAt());
    }

    private Admin getAdmin(Integer adminId){
        authenticatedUserService.checkAdmin(adminId);
        Admin admin = adminRepository.findAdminById(adminId);
        if(admin == null){
            throw new ApiException("Admin not found");
        }
        return admin;
    }
}
