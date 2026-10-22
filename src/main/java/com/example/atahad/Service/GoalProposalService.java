package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.GoalProposalRequest;
import com.example.atahad.Dto.Out.GoalProposalResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.GoalProposalRepository;
import com.example.atahad.Repository.GoalVoteRepository;
import com.example.atahad.Repository.GroupGoalRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// choosing the next goal: the AI suggests 3, members can add theirs, everyone votes, the owner confirms
@Service
@RequiredArgsConstructor
public class GoalProposalService {
    private final GoalProposalRepository goalProposalRepository;
    private final GoalVoteRepository goalVoteRepository;
    private final GroupGoalRepository groupGoalRepository;
    private final GroupAccessService groupAccessService;
    private final AiService aiService;

    @Transactional
    public List<GoalProposalResponse> suggestWithAi(Integer groupId, Integer memberId){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        Group group = groupMember.getGroup();

        int openFromAi = 0;
        for(GoalProposal proposal : goalProposalRepository.findGoalProposalsByGroupIdAndStatus(groupId, "OPEN")){
            if("AI".equals(proposal.getSuggestedBy())){
                openFromAi++;
            }
        }
        if(openFromAi >= 3){
            return getOpenProposals(groupId, memberId); // already suggested, no need to call the AI again
        }

        StringBuilder history = new StringBuilder();
        for(GroupGoal goal : groupGoalRepository.findGroupGoalsByGroupIdOrderByStartDateDesc(groupId)){
            history.append("- ").append(goal.getTitle()).append("\n");
        }
        String fallback = "Walk 30 minutes | Walk at least 30 minutes, proof by location or photo\n"
                + "Read 20 pages | Read 20 pages of any book, proof by a photo of the page\n"
                + "Sleep before 12 | Be in bed before midnight, proof by a timer";
        String answer = aiService.ask(
                "You suggest weekly goals for a group of friends in a commitment app. Answer with exactly 3 lines, "
                        + "every line is: title | details. The title is short (max 6 words). No numbering. "
                        + aiService.tone(group.getHumorLevel()),
                "Group name: " + group.getName() + "\nDescription: " + group.getDescription()
                        + "\nGoals they did before:\n" + (history.length() == 0 ? "none\n" : history),
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
            GoalProposal proposal = new GoalProposal();
            proposal.setTitle(title.length() > 100 ? title.substring(0, 100) : title);
            proposal.setDetails(parts.length > 1 ? cut(parts[1].trim(), 500) : null);
            proposal.setSuggestedBy("AI");
            proposal.setStatus("OPEN");
            proposal.setGroup(group);
            goalProposalRepository.save(proposal);
            added++;
        }
        return getOpenProposals(groupId, memberId);
    }

    public void propose(Integer groupId, Integer memberId, GoalProposalRequest dto){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        GoalProposal proposal = new GoalProposal();
        proposal.setTitle(dto.getTitle());
        proposal.setDetails(dto.getDetails());
        proposal.setSuggestedBy("MEMBER");
        proposal.setStatus("OPEN");
        proposal.setGroup(groupMember.getGroup());
        goalProposalRepository.save(proposal);
    }

    public List<GoalProposalResponse> getOpenProposals(Integer groupId, Integer memberId){
        GroupMember groupMember = groupAccessService.getActiveMembership(groupId, memberId);
        List<GoalProposalResponse> list = new ArrayList<>();
        for(GoalProposal proposal : goalProposalRepository.findGoalProposalsByGroupIdAndStatus(groupId, "OPEN")){
            List<GoalVote> votes = goalVoteRepository.findGoalVotesByGoalProposalId(proposal.getId());
            boolean mine = false;
            for(GoalVote vote : votes){
                if(vote.getGroupMember().getId().equals(groupMember.getId())){
                    mine = true;
                }
            }
            list.add(new GoalProposalResponse(proposal.getId(), proposal.getTitle(), proposal.getDetails(),
                    proposal.getSuggestedBy(), votes.size(), mine));
        }
        list.sort((a, b) -> b.getVotes() - a.getVotes());
        return list;
    }

    // one vote for every member, voting again moves the vote
    @Transactional
    public void vote(Integer proposalId, Integer memberId){
        GoalProposal proposal = goalProposalRepository.findGoalProposalById(proposalId);
        if(proposal == null){
            throw new ApiException("Proposal not found");
        }
        if(!"OPEN".equals(proposal.getStatus())){
            throw new ApiException("Voting on this proposal is closed");
        }
        GroupMember groupMember = groupAccessService.getActiveMembership(proposal.getGroup().getId(), memberId);

        for(GoalVote old : goalVoteRepository.findGoalVotesByGroupMemberIdAndGoalProposalStatus(groupMember.getId(), "OPEN")){
            if(old.getGoalProposal().getId().equals(proposalId)){
                throw new ApiException("You already voted for this proposal");
            }
            goalVoteRepository.delete(old);
        }
        GoalVote vote = new GoalVote();
        vote.setVotedAt(LocalDateTime.now());
        vote.setGoalProposal(proposal);
        vote.setGroupMember(groupMember);
        goalVoteRepository.save(vote);
    }

    // the owner can close a proposal without choosing it
    public void reject(Integer proposalId, Integer ownerId){
        GoalProposal proposal = goalProposalRepository.findGoalProposalById(proposalId);
        if(proposal == null){
            throw new ApiException("Proposal not found");
        }
        groupAccessService.checkOwner(proposal.getGroup().getId(), ownerId);
        proposal.setStatus("REJECTED");
        goalProposalRepository.save(proposal);
    }

    private String cut(String text, int max){
        return text.length() > max ? text.substring(0, max) : text;
    }
}
