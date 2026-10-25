package com.example.atahad.Service;

import com.example.atahad.AI.AiService;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GoalProposalRequest;
import com.example.atahad.Dto.Out.GoalProposalResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GroupMemberRepository;
import com.example.atahad.Repository.GroupGoalRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// choosing the next goal: the AI suggests 3 (from what the members achieved, or general ones when nobody achieved anything yet),
// members can add theirs, everyone votes, the owner confirms
// a proposal is a GroupGoal with status PROPOSED, and the vote of a member is GroupMember.votedGoal
@Service
@RequiredArgsConstructor
public class GoalProposalService {
    private final GroupMemberRepository groupMemberRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GroupGoalRepository groupGoalRepository;
    private final GroupAccessService groupAccessService;
    private final AiService aiService;

    @Transactional
    public List<GoalProposalResponse> suggestWithAi(Integer groupId, Integer memberId){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        Group group = groupMember.getGroup();

        int openFromAi = 0;
        for(GroupGoal proposal : groupGoalRepository.findGroupGoalsByGroupIdAndStatus(groupId, "PROPOSED")){
            if("AI".equals(proposal.getSuggestedBy())){
                openFromAi++;
            }
        }
        if(openFromAi >= 3){
            return getOpenProposals(groupId, memberId); // already suggested, no need to call the AI again
        }

        // what the members achieved: their personal commitments with a full week at least
        java.util.Set<String> achieved = new java.util.LinkedHashSet<>();
        for(GroupMember member : groupMemberRepository.findGroupMembersByGroupIdAndStatus(groupId, "ACTIVE")){
            for(CommitmentWeek week : commitmentWeekRepository.findCommitmentWeeksByCommitmentMember(member.getMember())){
                if(Boolean.TRUE.equals(week.getIsFullWeek()) && week.getCommitment().getGroupGoal() == null){
                    achieved.add(week.getCommitment().getTitle());
                }
            }
        }
        StringBuilder done = new StringBuilder();
        for(String title : achieved){
            done.append("- ").append(title).append("\n");
        }
        StringBuilder history = new StringBuilder();
        for(GroupGoal goal : groupGoalRepository.findGroupGoalsByGroupIdAndStatusInOrderByStartDateDesc(groupId, List.of("ACTIVE", "ENDED"))){
            history.append("- ").append(goal.getTitle()).append("\n");
        }
        String fallback = "المشي 30 دقيقة | امشِ 30 دقيقة على الأقل، والإثبات بالموقع أو صورة\n"
                + "قراءة 20 صفحة | اقرأ 20 صفحة من أي كتاب، والإثبات صورة الصفحة\n"
                + "النوم قبل 12 | كن في سريرك قبل منتصف الليل، والإثبات بالمؤقت";
        String basis = achieved.isEmpty()
                ? "Nobody in the group achieved a goal yet, so suggest 3 different, simple and useful goals that suit any group. "
                : "Base the 3 goals on what the members already achieved: goals of the same kind or one step further, so they keep going together. ";
        String answer = aiService.ask(
                "You suggest weekly goals for a group of friends in a commitment app. " + basis
                        + "Do not repeat a goal the group did before. Answer with exactly 3 lines, "
                        + "every line is: title | details. The title is short (max 6 words). No numbering. "
                        + aiService.tone(),
                "Group name: " + group.getName() + "\nDescription: " + group.getDescription()
                        + "\nWhat the members achieved:\n" + (done.length() == 0 ? "nothing yet\n" : done)
                        + "Group goals they did before:\n" + (history.length() == 0 ? "none\n" : history),
                fallback);

        int added = 0;
        for(String line : (answer + "\n" + fallback).split("\n")){
            if(added + openFromAi >= 3){
                break;
            }
            String[] parts = line.replaceAll("^[-*0-9. ]+", "").split("\\|", 2);
            String title = parts[0].trim();
            if(title.isEmpty()){
                continue;
            }
            GroupGoal proposal = new GroupGoal();
            proposal.setTitle(title.length() > 100 ? title.substring(0, 100) : title);
            proposal.setDetails(parts.length > 1 ? cut(parts[1].trim(), 500) : null);
            proposal.setSuggestedBy("AI");
            proposal.setStatus("PROPOSED");
            proposal.setGroup(group);
            groupGoalRepository.save(proposal);
            added++;
        }
        return getOpenProposals(groupId, memberId);
    }

    public void propose(Integer groupId, Integer memberId, GoalProposalRequest dto){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        GroupGoal proposal = new GroupGoal();
        proposal.setTitle(dto.getTitle());
        proposal.setDetails(dto.getDetails());
        proposal.setSuggestedBy("MEMBER");
        proposal.setStatus("PROPOSED");
        proposal.setGroup(groupMember.getGroup());
        groupGoalRepository.save(proposal);
    }

    public List<GoalProposalResponse> getOpenProposals(Integer groupId, Integer memberId){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        List<GoalProposalResponse> list = new ArrayList<>();
        for(GroupGoal proposal : groupGoalRepository.findGroupGoalsByGroupIdAndStatus(groupId, "PROPOSED")){
            List<GroupMember> votes = groupMemberRepository.findGroupMembersByVotedGoalId(proposal.getId());
            boolean mine = groupMember.getVotedGoal() != null && groupMember.getVotedGoal().getId().equals(proposal.getId());
            list.add(new GoalProposalResponse(proposal.getId(), proposal.getTitle(), proposal.getDetails(),
                    proposal.getSuggestedBy(), votes.size(), mine));
        }
        list.sort((a, b) -> b.getVotes() - a.getVotes());
        return list;
    }

    // one vote for every member, voting again moves the vote
    @Transactional
    public void vote(Integer proposalId, Integer memberId){
        GroupGoal proposal = getProposal(proposalId);
        if(!"PROPOSED".equals(proposal.getStatus())){
            throw new ApiException("Voting on this proposal is closed");
        }
        GroupMember groupMember = groupAccessService.getActiveMembership(proposal.getGroup().getId(), memberId);

        if(groupMember.getVotedGoal() != null && groupMember.getVotedGoal().getId().equals(proposalId)){
            throw new ApiException("You already voted for this proposal");
        }
        groupMember.setVotedGoal(proposal); // replaces his old vote
        groupMemberRepository.save(groupMember);
    }

    // the owner can close a proposal without choosing it
    public void reject(Integer proposalId, Integer ownerId){
        GroupGoal proposal = getProposal(proposalId);
        groupAccessService.checkOwner(proposal.getGroup().getId(), ownerId);
        if(!"PROPOSED".equals(proposal.getStatus())){
            throw new ApiException("This proposal is closed");
        }
        proposal.setStatus("REJECTED");
        groupGoalRepository.save(proposal);
        for(GroupMember voter : groupMemberRepository.findGroupMembersByVotedGoalId(proposalId)){
            voter.setVotedGoal(null);
            groupMemberRepository.save(voter);
        }
    }

    private GroupGoal getProposal(Integer proposalId){
        GroupGoal proposal = groupGoalRepository.findGroupGoalById(proposalId);
        if(proposal == null || proposal.getSuggestedBy() == null){
            throw new ApiException("Proposal not found");
        }
        return proposal;
    }

    private String cut(String text, int max){
        return text.length() > max ? text.substring(0, max) : text;
    }
}
