package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.MomentRequest;
import com.example.atahad.Dto.Out.MomentResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GroupMemberRepository;
import com.example.atahad.Repository.MomentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

// moments: a photo or a 15 seconds video, private or shared with a group (like Locket)
// a moment is never a proof
@Service
@RequiredArgsConstructor
public class MomentService {
    private final MomentRepository momentRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final GroupAccessService groupAccessService;

    // the photos and videos of the moments are saved on the server in this folder (not in git)
    public static final Path UPLOADS = Path.of("uploads", "moments");
    private static final long MAX_SIZE = 20L * 1024 * 1024; // 20 MB
    private static final List<String> PHOTO_TYPES = List.of("jpg", "jpeg", "png", "heic", "webp");
    private static final List<String> VIDEO_TYPES = List.of("mp4", "mov", "m4v");

    // the app sends the photo or the video from the camera first, then adds the moment with the returned link
    // returns the file name, the controller turns it into a link
    public String upload(MultipartFile file){
        if(file == null || file.isEmpty()){
            throw new ApiException("Send a photo or a video");
        }
        if(file.getSize() > MAX_SIZE){
            throw new ApiException("The file must be 20 MB max");
        }
        String original = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
        int dot = original.lastIndexOf('.');
        String extension = dot < 0 ? "" : original.substring(dot + 1).toLowerCase(Locale.ROOT);
        if(!PHOTO_TYPES.contains(extension) && !VIDEO_TYPES.contains(extension)){
            throw new ApiException("Only photos and videos are allowed");
        }
        String name = UUID.randomUUID() + "." + extension;
        try{
            Files.createDirectories(UPLOADS);
            file.transferTo(UPLOADS.resolve(name).toAbsolutePath());
        }catch(IOException e){
            throw new ApiException("The file was not saved, try again");
        }
        return name;
    }

    public MomentResponse add(Integer memberId, MomentRequest dto){
        Member member = groupAccessService.getMember(memberId);
        Moment moment = new Moment();
        moment.setMediaUrl(dto.getMediaUrl());
        moment.setMediaType(dto.getMediaType());
        moment.setCaption(dto.getCaption());
        moment.setVisibility(dto.getVisibility());
        moment.setCreatedAt(LocalDateTime.now());
        moment.setMember(member);

        if("GROUP".equals(dto.getVisibility())){
            if(dto.getGroupId() == null){
                throw new ApiException("Choose the group to share with");
            }
            moment.setGroup(groupAccessService.getActiveMembership(dto.getGroupId(), memberId).getGroup());
        }
        if(dto.getCommitmentWeekId() != null){
            CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(dto.getCommitmentWeekId());
            if(week == null || !week.getCommitment().getMember().getId().equals(memberId)){
                throw new ApiException("Week not found");
            }
            moment.setCommitmentWeek(week);
        }
        momentRepository.save(moment);
        return toResponse(moment);
    }

    public List<MomentResponse> getMyMoments(Integer memberId){
        groupAccessService.getMember(memberId);
        List<MomentResponse> list = new ArrayList<>();
        for(Moment moment : momentRepository.findMomentsByMemberIdOrderByCreatedAtDesc(memberId)){
            list.add(toResponse(moment));
        }
        return list;
    }

    public List<MomentResponse> getGroupFeed(Integer groupId, Integer memberId){
        groupAccessService.getActiveMembership(groupId, memberId);
        List<MomentResponse> list = new ArrayList<>();
        for(Moment moment : momentRepository.findMomentsByGroupIdAndVisibilityOrderByCreatedAtDesc(groupId, "GROUP")){
            list.add(toResponse(moment));
        }
        return list;
    }

    // the home screen widget: the newest moment a friend shared in any of my groups
    public MomentResponse getLatestForWidget(Integer memberId){
        groupAccessService.getMember(memberId);
        Moment latest = null;
        for(GroupMember groupMember : groupMemberRepository.findGroupMembersByMemberIdAndStatus(memberId, "ACTIVE")){
            for(Moment moment : momentRepository.findMomentsByGroupIdAndVisibilityOrderByCreatedAtDesc(groupMember.getGroup().getId(), "GROUP")){
                if(moment.getMember().getId().equals(memberId)){
                    continue;
                }
                if(latest == null || moment.getCreatedAt().isAfter(latest.getCreatedAt())){
                    latest = moment;
                }
                break; // the list is newest first
            }
        }
        if(latest == null){
            throw new ApiException("No moments from your friends yet");
        }
        return toResponse(latest);
    }

    public void delete(Integer memberId, Integer momentId){
        Moment moment = momentRepository.findMomentById(momentId);
        if(moment == null || !moment.getMember().getId().equals(memberId)){
            throw new ApiException("You can only delete your own moment");
        }
        momentRepository.delete(moment);
    }

    private MomentResponse toResponse(Moment moment){
        return new MomentResponse(moment.getId(), moment.getMember().getId(), groupAccessService.nameOf(moment.getMember()),
                moment.getMediaUrl(), moment.getMediaType(), moment.getCaption(), moment.getVisibility(),
                moment.getGroup() == null ? null : moment.getGroup().getName(), moment.getCreatedAt());
    }
}
