
package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.AiScheduleResponse;
import com.example.atahad.Entity.GoogleCalendarConnection;
import com.example.atahad.Entity.GoogleCalendarOAuthState;
import com.example.atahad.Entity.Member;
import com.example.atahad.Repository.GoogleCalendarConnectionRepository;
import com.example.atahad.Repository.GoogleCalendarOAuthStateRepository;
import com.example.atahad.Repository.MemberRepository;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class GoogleCalendarService {

    private final GoogleCalendarConnectionRepository connectionRepository;
    private final GoogleCalendarOAuthStateRepository oauthStateRepository;
    private final GoogleTokenCryptoService cryptoService;
    private final MemberRepository memberRepository;
    private final AiScheduleService aiScheduleService;

    private final RestClient restClient = RestClient.create();
    private final ZoneId zone = ZoneId.of("Asia/Riyadh");

    @Value("${google.calendar.client-id:}")
    private String clientId;

    @Value("${google.calendar.client-secret:}")
    private String clientSecret;

    @Value("${google.calendar.redirect-uri}")
    private String redirectUri;

    public String getAuthorizationUrl(Integer memberId) {

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        if (clientId == null || clientId.isBlank() ||
                clientSecret == null || clientSecret.isBlank()) {
            throw new ApiException("Google Calendar configuration is missing");
        }

        byte[] random = new byte[32];
        new SecureRandom().nextBytes(random);

        String state = Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(random);

        GoogleCalendarOAuthState oauthState = new GoogleCalendarOAuthState();
        oauthState.setStateHash(hashState(state));
        oauthState.setMember(member);
        oauthState.setExpiresAt(LocalDateTime.now(zone).plusMinutes(10));

        oauthStateRepository.save(oauthState);

        return UriComponentsBuilder
                .fromUriString("https://accounts.google.com/o/oauth2/v2/auth")
                .queryParam("client_id", clientId)
                .queryParam("redirect_uri", redirectUri)
                .queryParam("response_type", "code")
                .queryParam("scope", "https://www.googleapis.com/auth/calendar.events")
                .queryParam("access_type", "offline")
                .queryParam("prompt", "consent")
                .queryParam("state", state)
                .build()
                .encode()
                .toUriString();
    }

    public void handleCallback(String code, String state) {

        if (code == null || code.isBlank() ||
                state == null || state.isBlank()) {
            throw new ApiException("Invalid Google Calendar callback");
        }

        String stateHash = hashState(state);

        GoogleCalendarOAuthState oauthState = oauthStateRepository
                .findById(stateHash)
                .orElse(null);

        if (oauthState == null) {
            throw new ApiException("Invalid Google Calendar OAuth state");
        }

        Integer memberId = oauthState.getMember().getId();
        boolean expired = oauthState.getExpiresAt() == null ||
                !oauthState.getExpiresAt().isAfter(LocalDateTime.now(zone));

        oauthStateRepository.delete(oauthState);

        if (expired) {
            throw new ApiException("Google Calendar authorization expired");
        }

        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("code", code);
        body.add("client_id", clientId);
        body.add("client_secret", clientSecret);
        body.add("redirect_uri", redirectUri);
        body.add("grant_type", "authorization_code");

        Map response;

        try {
            response = restClient.post()
                    .uri("https://oauth2.googleapis.com/token")
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(body)
                    .retrieve()
                    .body(Map.class);
        } catch (Exception e) {
            throw new ApiException("Failed to authorize Google Calendar");
        }

        if (response == null || response.get("access_token") == null) {
            throw new ApiException("Google Calendar access token is missing");
        }

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        GoogleCalendarConnection connection =
                connectionRepository.findGoogleCalendarConnectionByMemberId(memberId);

        if (connection == null) {
            connection = new GoogleCalendarConnection();
            connection.setMember(member);
        }

        connection.setEncryptedAccessToken(
                cryptoService.encrypt(response.get("access_token").toString())
        );

        if (response.get("refresh_token") != null) {
            connection.setEncryptedRefreshToken(
                    cryptoService.encrypt(response.get("refresh_token").toString())
            );
        }

        if (connection.getEncryptedRefreshToken() == null) {
            throw new ApiException("Google Calendar refresh token is missing");
        }

        long expiresIn = getExpiresIn(response);

        connection.setExpiresAt(
                LocalDateTime.now(zone).plusSeconds(expiresIn)
        );
        connection.setConnected(true);
        connection.setConnectedAt(LocalDateTime.now(zone));

        connectionRepository.save(connection);
    }

    public boolean isConnected(Integer memberId) {

        GoogleCalendarConnection connection =
                connectionRepository.findGoogleCalendarConnectionByMemberId(memberId);

        return connection != null &&
                Boolean.TRUE.equals(connection.getConnected()) &&
                connection.getEncryptedRefreshToken() != null;
    }

    public void disconnect(Integer memberId) {

        GoogleCalendarConnection connection =
                connectionRepository.findGoogleCalendarConnectionByMemberId(memberId);

        if (connection == null) {
            throw new ApiException("Google Calendar is not connected");
        }

        String token = connection.getEncryptedRefreshToken() != null
                ? cryptoService.decrypt(connection.getEncryptedRefreshToken())
                : cryptoService.decrypt(connection.getEncryptedAccessToken());

        try {
            MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
            body.add("token", token);

            restClient.post()
                    .uri("https://oauth2.googleapis.com/revoke")
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(body)
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception e) {
            throw new ApiException("Failed to revoke Google Calendar access");
        }

        connectionRepository.delete(connection);
    }

    public String getValidAccessToken(Integer memberId) {

        GoogleCalendarConnection connection =
                connectionRepository.findGoogleCalendarConnectionByMemberId(memberId);

        if (connection == null ||
                !Boolean.TRUE.equals(connection.getConnected())) {
            throw new ApiException("Google Calendar is not connected");
        }

        if (connection.getExpiresAt() != null &&
                connection.getEncryptedAccessToken() != null &&
                connection.getExpiresAt().isAfter(
                        LocalDateTime.now(zone).plusMinutes(2))) {

            return cryptoService.decrypt(
                    connection.getEncryptedAccessToken()
            );
        }

        if (connection.getEncryptedRefreshToken() == null) {
            throw new ApiException("Google Calendar needs reconnection");
        }

        String refreshToken = cryptoService.decrypt(
                connection.getEncryptedRefreshToken()
        );

        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("client_id", clientId);
        body.add("client_secret", clientSecret);
        body.add("refresh_token", refreshToken);
        body.add("grant_type", "refresh_token");

        Map response;

        try {
            response = restClient.post()
                    .uri("https://oauth2.googleapis.com/token")
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(body)
                    .retrieve()
                    .body(Map.class);
        } catch (Exception e) {
            throw new ApiException("Failed to refresh Google Calendar token");
        }

        if (response == null || response.get("access_token") == null) {
            throw new ApiException("Failed to refresh Google Calendar token");
        }

        String newAccessToken = response.get("access_token").toString();

        connection.setEncryptedAccessToken(
                cryptoService.encrypt(newAccessToken)
        );

        connection.setExpiresAt(
                LocalDateTime.now(zone).plusSeconds(getExpiresIn(response))
        );

        if (response.get("refresh_token") != null) {
            connection.setEncryptedRefreshToken(
                    cryptoService.encrypt(response.get("refresh_token").toString())
            );
        }

        connectionRepository.save(connection);

        return newAccessToken;
    }

    public List<AiScheduleResponse> generateSchedule(Integer memberId, HttpSession session) {

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        List<AiScheduleResponse> schedules = aiScheduleService.generate(memberId);

        if (schedules == null || schedules.isEmpty()) {
            throw new ApiException("No active commitments need scheduling");
        }

        // Keep the generated proposal only until the user approves or rejects it.
        session.setAttribute("pendingScheduleMemberId", memberId);
        session.setAttribute("pendingSchedules", schedules);

        return schedules;
    }

    public void approveSchedule(Integer memberId, HttpSession session) {

        List<AiScheduleResponse> schedules = getPendingSchedules(memberId, session);

        createScheduleEvents(memberId, schedules);

        session.removeAttribute("pendingSchedules");
        session.removeAttribute("pendingScheduleMemberId");
    }

    public void rejectSchedule(Integer memberId, HttpSession session) {

        getPendingSchedules(memberId, session);

        session.removeAttribute("pendingSchedules");
        session.removeAttribute("pendingScheduleMemberId");
    }

    @SuppressWarnings("unchecked")
    private List<AiScheduleResponse> getPendingSchedules(Integer memberId, HttpSession session) {

        Member member = memberRepository.findMemberById(memberId);

        if (member == null) {
            throw new ApiException("Member not found");
        }

        Integer ownerId = (Integer) session.getAttribute("pendingScheduleMemberId");
        Object pending = session.getAttribute("pendingSchedules");

        if (!memberId.equals(ownerId) || !(pending instanceof List<?>)) {
            throw new ApiException("Schedule not found");
        }

        List<?> items = (List<?>) pending;

        if (items.isEmpty() || !items.stream().allMatch(AiScheduleResponse.class::isInstance)) {
            throw new ApiException("Schedule not found");
        }

        return (List<AiScheduleResponse>) pending;
    }

    public void createEvent(
            Integer memberId,
            String title,
            String date,
            String startTime,
            String endTime) {

        LocalDate eventDate;
        LocalTime start;
        LocalTime end;

        try {
            eventDate = LocalDate.parse(date);
            start = LocalTime.parse(startTime);
            end = LocalTime.parse(endTime);
        } catch (DateTimeParseException e) {
            throw new ApiException("Invalid date or time");
        }

        LocalDateTime startDateTime = eventDate.atTime(start);
        LocalDateTime endDateTime = eventDate.atTime(end);

        if (!startDateTime.isAfter(LocalDateTime.now(zone))) {
            throw new ApiException("Event date must be in the future");
        }

        if (!endDateTime.isAfter(startDateTime)) {
            throw new ApiException("End time must be after start time");
        }

        DateTimeFormatter formatter =
                DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssXXX");

        Map<String, Object> startEvent = Map.of(
                "dateTime", startDateTime.atZone(zone).format(formatter),
                "timeZone", "Asia/Riyadh"
        );

        Map<String, Object> endEvent = Map.of(
                "dateTime", endDateTime.atZone(zone).format(formatter),
                "timeZone", "Asia/Riyadh"
        );

        Map<String, Object> event = Map.of(
                "summary", "Atahad - " + title,
                "description", "Commitment schedule approved by the user",
                "start", startEvent,
                "end", endEvent
        );

        String accessToken = getValidAccessToken(memberId);

        Map response;

        try {
            response = restClient.post()
                    .uri("https://www.googleapis.com/calendar/v3/calendars/primary/events")
                    .header("Authorization", "Bearer " + accessToken)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(event)
                    .retrieve()
                    .body(Map.class);
        } catch (Exception e) {
            throw new ApiException("Failed to create Google Calendar event");
        }

        if (response == null || response.get("id") == null) {
            throw new ApiException("Failed to create Google Calendar event");
        }
    }

    public void createScheduleEvents(
            Integer memberId,
            List<AiScheduleResponse> schedules) {

        if (schedules == null || schedules.isEmpty()) {
            throw new ApiException("Schedule not found");
        }

        int totalEvents = 0;

        for (AiScheduleResponse schedule : schedules) {

            if (schedule == null ||
                    schedule.getTitle() == null ||
                    schedule.getTitle().isBlank() ||
                    schedule.getSuggestions() == null ||
                    schedule.getSuggestions().isEmpty()) {
                throw new ApiException("Invalid schedule");
            }

            totalEvents += schedule.getSuggestions().size();

            if (totalEvents > 100) {
                throw new ApiException("Too many schedule suggestions");
            }

            // Validate all dates before creating any events
            for (AiScheduleResponse.ScheduleSuggestion suggestion
                    : schedule.getSuggestions()) {

                if (suggestion == null ||
                        suggestion.getDate() == null ||
                        suggestion.getStartTime() == null ||
                        suggestion.getEndTime() == null) {
                    throw new ApiException("Invalid schedule suggestion");
                }

                try {
                    LocalDate date = LocalDate.parse(suggestion.getDate());
                    LocalTime start = LocalTime.parse(suggestion.getStartTime());
                    LocalTime end = LocalTime.parse(suggestion.getEndTime());

                    LocalDateTime startDateTime = date.atTime(start);
                    LocalDateTime endDateTime = date.atTime(end);

                    if (!startDateTime.isAfter(LocalDateTime.now(zone))) {
                        throw new ApiException("Schedule date must be in the future");
                    }

                    if (!endDateTime.isAfter(startDateTime)) {
                        throw new ApiException("Invalid schedule time");
                    }

                } catch (DateTimeParseException e) {
                    throw new ApiException("Invalid schedule date or time");
                }
            }
        }

        for (AiScheduleResponse schedule : schedules) {

            for (AiScheduleResponse.ScheduleSuggestion suggestion
                    : schedule.getSuggestions()) {

                createEvent(
                        memberId,
                        schedule.getTitle(),
                        suggestion.getDate(),
                        suggestion.getStartTime(),
                        suggestion.getEndTime()
                );
            }
        }
    }

    private long getExpiresIn(Map response) {

        Object value = response.get("expires_in");

        if (value instanceof Number number) {
            return number.longValue();
        }

        try {
            return Long.parseLong(String.valueOf(value));
        } catch (Exception e) {
            throw new ApiException("Google token expiry is missing");
        }
    }

    private String hashState(String state) {

        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(state.getBytes(StandardCharsets.UTF_8));

            return Base64.getUrlEncoder()
                    .withoutPadding()
                    .encodeToString(hash);

        } catch (Exception e) {
            throw new ApiException("Failed to secure Google OAuth state");
        }
    }
}
