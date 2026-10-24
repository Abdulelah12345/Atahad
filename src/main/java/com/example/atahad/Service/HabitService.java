package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Habit;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.HabitRepository;
import com.example.atahad.Repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class HabitService {
    private final HabitRepository habitRepository;
    private final MemberRepository memberRepository;
    private final CommitmentWeekService commitmentWeekService;

    // admin
    public List<Habit> getAllHabits(){
        return habitRepository.findAll();
    }

    public List<Habit> getMyHabits(Integer memberId){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        return habitRepository.findHabitsByMember(member);
    }

    // starts right away, the first week needs min(times, days left until saturday)
    @Transactional
    public void addHabit(Integer memberId, Habit habit){
        Member member = memberRepository.findMemberById(memberId);
        if(member == null){
            throw new ApiException("Member not found");
        }
        if(Boolean.TRUE.equals(member.getIsLocked())){
            throw new ApiException("Your app is locked, donate first to add a new habit");
        }
        if(habit.getBaseAmount() == null){
            throw new ApiException("Amount per time cannot be empty");
        }
        habit.setMember(member);
        habit.setStatus("ACTIVE");
        habit.setEffectiveFrom(LocalDate.now());
        habit.setPendingTimesPerWeek(null);
        habit.setPendingBaseAmount(null);
        CommitmentService.checkTargets(habit);
        habitRepository.save(habit);

        commitmentWeekService.startFirstWeek(habit);
    }

    // the title and the planned days change right away, times and amount change from the next week
    public void updateHabit(Integer memberId, Integer id, Habit habit){
        Habit oldHabit = getMyHabit(memberId, id);
        if(oldHabit.getStatus().equals("WITHDRAWN") || oldHabit.getStatus().equals("ENDED")){
            throw new ApiException("Habit is finished and cannot be updated");
        }
        oldHabit.setTitle(habit.getTitle());
        oldHabit.setPlannedDays(habit.getPlannedDays());
        if(!hasStarted(oldHabit)){
            oldHabit.setProofMethod(habit.getProofMethod());
            oldHabit.setTimesPerWeek(habit.getTimesPerWeek());
            oldHabit.setBaseAmount(habit.getBaseAmount());
        }else{
            if(!oldHabit.getProofMethod().equals(habit.getProofMethod())){
                throw new ApiException("Proof method cannot change after the habit starts");
            }
            if(!oldHabit.getTimesPerWeek().equals(habit.getTimesPerWeek())){
                oldHabit.setPendingTimesPerWeek(habit.getTimesPerWeek());
            }
            if(habit.getBaseAmount() != null && oldHabit.getBaseAmount().compareTo(habit.getBaseAmount()) != 0){
                oldHabit.setPendingBaseAmount(habit.getBaseAmount());
            }
        }
        habitRepository.save(oldHabit);
    }

    // a habit can be deleted only if nothing happened in it yet, after that it is withdrawn
    public void deleteHabit(Integer memberId, Integer id){
        Habit habit = getMyHabit(memberId, id);
        if(commitmentWeekService.hasProgress(habit)){
            throw new ApiException("Habit already has progress, withdraw from it instead");
        }
        habitRepository.delete(habit);
    }

    private Habit getMyHabit(Integer memberId, Integer id){
        Habit habit = habitRepository.findHabitById(id);
        if(habit == null){
            throw new ApiException("Habit not found");
        }
        if(!habit.getMember().getId().equals(memberId)){
            throw new ApiException("You can only change your own habit");
        }
        return habit;
    }

    // true when the habit already has a week
    private boolean hasStarted(Habit commitment){
        return commitment.getWeeks() != null && !commitment.getWeeks().isEmpty();
    }
}
