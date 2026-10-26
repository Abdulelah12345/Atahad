
package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.ActivityDayResponse;
import com.example.atahad.Entity.Member;
import com.example.atahad.Entity.PointLog;
import com.example.atahad.Repository.ActivityMapRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ActivityMapService {

    private final ActivityMapRepository activityMapRepository;
    private final MemberRepository memberRepository;

    @Transactional(readOnly = true)
    public List<ActivityDayResponse> getActivityMap(Integer memberId){

        Member member=memberRepository.findMemberById(memberId);
        if(member==null){
            throw new ApiException("Member not found");
        }

        int year=LocalDate.now(ZoneId.of("Asia/Riyadh")).getYear();

        LocalDate start=LocalDate.of(year,1,1);
        LocalDate end=start.plusYears(1);

        List<PointLog> activities=activityMapRepository
                .findByMember_IdAndReasonAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        memberId,"TASK_DONE",start.atStartOfDay(),end.atStartOfDay());

        Map<LocalDate,Integer> completedDays=new HashMap<>();

        for(PointLog activity:activities){
            LocalDate date=activity.getCreatedAt().toLocalDate();
            completedDays.put(date,completedDays.getOrDefault(date,0)+1);
        }

        List<ActivityDayResponse> response=new ArrayList<>();

        for(LocalDate date=start;date.isBefore(end);date=date.plusDays(1)){

            int completed=completedDays.getOrDefault(date,0);
            String status=completed>0 ? "COMPLETED" : "NO_ACTIVITY";

            response.add(new ActivityDayResponse(date,completed,status));
        }

        return response;
    }
}
