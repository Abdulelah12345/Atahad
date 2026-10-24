package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.AiScheduleResponse;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.Map;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
public class GoogleCalendarService {

    @Value("${google.calendar.client-id:}")
    private String clientId;

    @Value("${google.calendar.client-secret:}")
    private String clientSecret;

    @Value("${google.calendar.redirect-uri}")
    private String redirectUri;

    public String getAuthorizationUrl(HttpSession session){

        if(clientId.isBlank()){
            throw new ApiException("Google Calendar Client ID is missing");
        }

        byte[] random=new byte[32];
        new SecureRandom().nextBytes(random);

        String state=Base64.getUrlEncoder().withoutPadding().encodeToString(random);

        session.setAttribute("googleCalendarOAuthState",state);

        return UriComponentsBuilder
                .fromUriString("https://accounts.google.com/o/oauth2/v2/auth")
                .queryParam("client_id",clientId)
                .queryParam("redirect_uri",redirectUri)
                .queryParam("response_type","code")
                .queryParam("scope","https://www.googleapis.com/auth/calendar.events")
                .queryParam("access_type","offline")
                .queryParam("prompt","consent")
                .queryParam("state",state)
                .build()
                .encode()
                .toUriString();
    }

    public void handleCallback(String code,String state,HttpSession session){

        String savedState=(String)session.getAttribute("googleCalendarOAuthState");
        session.removeAttribute("googleCalendarOAuthState");

        if(savedState==null || state==null || !savedState.equals(state)){
            throw new ApiException("Invalid Google Calendar OAuth state");
        }

        if(code==null || code.isBlank()){
            throw new ApiException("Google Calendar authorization code is missing");
        }

        MultiValueMap<String,String> body=new LinkedMultiValueMap<>();
        body.add("code",code);
        body.add("client_id",clientId);
        body.add("client_secret",clientSecret);
        body.add("redirect_uri",redirectUri);
        body.add("grant_type","authorization_code");

        Map response=RestClient.create()
                .post()
                .uri("https://oauth2.googleapis.com/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(body)
                .retrieve()
                .body(Map.class);

        if(response==null || response.get("access_token")==null){
            throw new ApiException("Failed to connect Google Calendar");
        }

        session.setAttribute("googleCalendarAccessToken",response.get("access_token"));

        if(response.get("refresh_token")!=null){
            session.setAttribute("googleCalendarRefreshToken",response.get("refresh_token"));
        }
    }

    public void createEvent(String title,String date,String startTime,String endTime,HttpSession session){

        String accessToken=(String)session.getAttribute("googleCalendarAccessToken");

        if(accessToken==null){
            throw new ApiException("Google Calendar is not connected");
        }

        LocalDate eventDate;
        LocalTime start;
        LocalTime end;

        try{
            eventDate=LocalDate.parse(date);
            start=LocalTime.parse(startTime);
            end=LocalTime.parse(endTime);
        }catch(DateTimeParseException e){
            throw new ApiException("Invalid date or time");
        }

        LocalDateTime startDateTime=eventDate.atTime(start);
        LocalDateTime endDateTime=eventDate.atTime(end);

        ZoneId zone=ZoneId.of("Asia/Riyadh");

        DateTimeFormatter formatter=DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssXXX");

        if(!startDateTime.atZone(zone).isAfter(ZonedDateTime.now(zone))){
            throw new ApiException("Event date must be in the future");
        }

        if(!endDateTime.isAfter(startDateTime)){
            throw new ApiException("End time must be after start time");
        }

        Map<String,Object> startEvent=Map.of(
                "dateTime",startDateTime.atZone(zone).format(formatter),
                "timeZone","Asia/Riyadh"
        );

        Map<String,Object> endEvent=Map.of(
                "dateTime",endDateTime.atZone(zone).format(formatter),
                "timeZone","Asia/Riyadh"
        );

        Map<String,Object> event=Map.of(
                "summary","Atahad - "+title,
                "description","Commitment schedule approved by the user",
                "start",startEvent,
                "end",endEvent
        );

        Map response=RestClient.create()
                .post()
                .uri("https://www.googleapis.com/calendar/v3/calendars/primary/events")
                .header("Authorization","Bearer "+accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .body(event)
                .retrieve()
                .body(Map.class);

        if(response==null || response.get("id")==null){
            throw new ApiException("Failed to create Google Calendar event");
        }
    }

    public void approveSchedule(HttpSession session){

        AiScheduleResponse schedule=(AiScheduleResponse)session.getAttribute("pendingSchedule");

        if(schedule==null){
            throw new ApiException("Schedule not found");
        }

        createScheduleEvents(schedule,session);

        session.removeAttribute("pendingSchedule");
    }

    public void rejectSchedule(HttpSession session){

        AiScheduleResponse schedule=(AiScheduleResponse)session.getAttribute("pendingSchedule");

        if(schedule==null){
            throw new ApiException("Schedule not found");
        }

        session.removeAttribute("pendingSchedule");
    }

    public void createScheduleEvents(AiScheduleResponse schedule,HttpSession session){

        if(schedule==null || schedule.getTitle()==null || schedule.getTitle().isBlank()){
            throw new ApiException("Invalid schedule");
        }

        if(schedule.getSuggestions()==null || schedule.getSuggestions().isEmpty()){
            throw new ApiException("No schedule suggestions found");
        }

        if(schedule.getSuggestions().size()>31){
            throw new ApiException("Too many schedule suggestions");
        }

        String accessToken=(String)session.getAttribute("googleCalendarAccessToken");

        if(accessToken==null){
            throw new ApiException("Google Calendar is not connected");
        }

        // Validate all dates before creating any events
        for(AiScheduleResponse.ScheduleSuggestion suggestion:schedule.getSuggestions()){

            if(suggestion==null || suggestion.getDate()==null
                    || suggestion.getStartTime()==null || suggestion.getEndTime()==null){
                throw new ApiException("Invalid schedule suggestion");
            }

            try{
                LocalDate date=LocalDate.parse(suggestion.getDate());
                LocalTime start=LocalTime.parse(suggestion.getStartTime());
                LocalTime end=LocalTime.parse(suggestion.getEndTime());

                LocalDateTime startDateTime=date.atTime(start);
                LocalDateTime endDateTime=date.atTime(end);

                if(!startDateTime.atZone(ZoneId.of("Asia/Riyadh")).isAfter(ZonedDateTime.now(ZoneId.of("Asia/Riyadh")))){
                    throw new ApiException("Schedule date must be in the future");
                }

                if(!endDateTime.isAfter(startDateTime)){
                    throw new ApiException("Invalid schedule time");
                }

            }catch(DateTimeParseException e){
                throw new ApiException("Invalid schedule date or time");
            }
        }

        for(AiScheduleResponse.ScheduleSuggestion suggestion:schedule.getSuggestions()){

            createEvent(
                    schedule.getTitle(),
                    suggestion.getDate(),
                    suggestion.getStartTime(),
                    suggestion.getEndTime(),
                    session
            );
        }
    }
}