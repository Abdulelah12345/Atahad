package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import com.example.atahad.Dto.In.AiScheduleRequest;
import com.example.atahad.DTO.Out.AiScheduleResponse;
import tools.jackson.databind.ObjectMapper;import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;

// one place for every AI call in the app (decisions, group texts, goal plans, the monthly wrapped)
// works with any OpenAI compatible chat API (Gemini in our project), the settings are in application-local.properties
// without a key (or if the AI fails) the fallback is used, so nothing stops working
@Service
public class AiService {

    @Value("${ai.url:https://api.openai.com/v1/chat/completions}")
    private String url;

    @Value("${ai.model:gpt-4o-mini}")
    private String model;

    @Value("${ai.api-key:}")
    private String apiKey;

    // Gemini's own API, used for videos (the OpenAI compatible one takes images only)
    @Value("${ai.native-url:https://generativelanguage.googleapis.com/v1beta/models/}")
    private String nativeUrl;

    public static final int MAX_VIDEO_BYTES = 15 * 1024 * 1024; // the request must stay under 20 MB

    private final RestClient restClient = RestClient.create();

    public String ask(String instructions, String prompt, String fallback){
        return askWithImages(instructions, prompt, List.of(), fallback);
    }

    // images: links (http...) or data urls, the AI looks at them with the text
    public String askWithImages(String instructions, String prompt, List<String> images, String fallback){
        if(apiKey == null || apiKey.isBlank()){
            return fallback;
        }
        try{
            Object content = prompt;
            if(images != null && !images.isEmpty()){
                List<Object> parts = new ArrayList<>();
                parts.add(Map.of("type", "text", "text", prompt));
                for(String image : images){
                    if(image != null && !image.isBlank()){
                        parts.add(Map.of("type", "image_url", "image_url", Map.of("url", toDataUrl(image))));
                    }
                }
                content = parts;
            }
            Map<String, Object> body = Map.of(
                    "model", model,
                    "messages", List.of(
                            Map.of("role", "system", "content", instructions),
                            Map.of("role", "user", "content", content)
                    )
            );
            Map<?, ?> response = restClient.post()
                    .uri(url)
                    .header("Authorization", "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(Map.class);

            List<?> choices = (List<?>) response.get("choices");
            Map<?, ?> message = (Map<?, ?>) ((Map<?, ?>) choices.get(0)).get("message");
            String text = String.valueOf(message.get("content")).trim();
            return text.isBlank() ? fallback : text;
        }catch(Exception e){
            return fallback;
        }
    }

    // one file from the app camera: a video goes to Gemini's own API, a photo goes the normal way
    public String askWithMedia(String instructions, String prompt, String mediaUrl, String fallback){
        if(apiKey == null || apiKey.isBlank() || mediaUrl == null || mediaUrl.isBlank()){
            return fallback;
        }
        try{
            ResponseEntity<byte[]> file = download(mediaUrl);
            String type = mediaType(file, mediaUrl);
            byte[] bytes = file.getBody();
            if(bytes == null || bytes.length == 0){
                return fallback;
            }
            String data = Base64.getEncoder().encodeToString(bytes);
            if(!type.startsWith("video/")){
                return askWithImages(instructions, prompt, List.of("data:" + type + ";base64," + data), fallback);
            }
            if(bytes.length > MAX_VIDEO_BYTES){
                return fallback; // too big, an admin decides
            }
            Map<String, Object> body = Map.of(
                    "system_instruction", Map.of("parts", List.of(Map.of("text", instructions))),
                    "contents", List.of(Map.of(
                            "role", "user",
                            "parts", List.of(
                                    Map.of("text", prompt),
                                    Map.of("inline_data", Map.of("mime_type", type, "data", data))
                            )
                    ))
            );
            Map<?, ?> response = restClient.post()
                    .uri(nativeUrl + model + ":generateContent")
                    .header("x-goog-api-key", apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(Map.class);

            List<?> candidates = (List<?>) response.get("candidates");
            Map<?, ?> content = (Map<?, ?>) ((Map<?, ?>) candidates.get(0)).get("content");
            StringBuilder text = new StringBuilder();
            for(Object part : (List<?>) content.get("parts")){
                Object value = ((Map<?, ?>) part).get("text");
                if(value != null){
                    text.append(value);
                }
            }
            String answer = text.toString().trim();
            return answer.isBlank() ? fallback : answer;
        }catch(Exception e){
            return fallback;
        }
    }

    // reads "KEY: value" from the AI answer, null when it is missing
    public String field(String answer, String key){
        if(answer == null){
            return null;
        }
        for(String line : answer.split("\n")){
            String clean = line.replace("*", "").trim();
            if(clean.toUpperCase().startsWith(key.toUpperCase() + ":")){
                String value = clean.substring(key.length() + 1).trim();
                return value.isEmpty() || value.equalsIgnoreCase("null") || value.equalsIgnoreCase("none") ? null : value;
            }
        }
        return null;
    }

    // ACCEPTED, REJECTED or ESCALATED, anything else = ESCALATED so an admin decides
    public String decision(String answer){
        String value = field(answer, "DECISION");
        if(value == null){
            return "ESCALATED";
        }
        value = value.toUpperCase();
        if(value.startsWith("ACCEPT")){
            return "ACCEPTED";
        }
        if(value.startsWith("REJECT")){
            return "REJECTED";
        }
        return "ESCALATED";
    }

    // one style for every text the AI writes to the members
    public String tone(){
        return "Write in simple white Saudi Arabic that every Arab understands, a little formal, with some Modern Standard Arabic words, "
                + "natural and relaxed. Do not try to be funny: no jokes, no teasing, no slang like (يا ناشفين), no exaggeration. "
                + "Use no emojis, or one at most.";
    }

    // Gemini does not open links by itself, so the image is downloaded and sent inside the request
    private String toDataUrl(String image){
        if(image.startsWith("data:")){
            return image;
        }
        ResponseEntity<byte[]> file = download(image);
        String type = file.getHeaders().getContentType() == null ? "image/jpeg" : file.getHeaders().getContentType().toString();
        return "data:" + type + ";base64," + Base64.getEncoder().encodeToString(file.getBody());
    }

    private ResponseEntity<byte[]> download(String url){
        return restClient.get().uri(url).retrieve().toEntity(byte[].class);
    }

    // from the header, or from the end of the link when the storage sends a general type
    private String mediaType(ResponseEntity<byte[]> file, String url){
        String type = file.getHeaders().getContentType() == null ? "" : file.getHeaders().getContentType().toString().split(";")[0].trim();
        if(type.startsWith("video/") || type.startsWith("image/")){
            return type;
        }
        String path = url.toLowerCase().split("\\?")[0];
        if(path.endsWith(".mp4")){
            return "video/mp4";
        }
        if(path.endsWith(".mov")){
            return "video/quicktime";
        }
        if(path.endsWith(".webm")){
            return "video/webm";
        }
        if(path.endsWith(".png")){
            return "image/png";
        }
        return "image/jpeg";
    }

    public String matchGroupGoals(String goal1, String goal2){

        String instructions = """
            You are an AI matchmaking system for group competitions.

            Compare two goals based on their semantic similarity.

            Goals do not need to be identical.
            They should involve related activities or develop similar skills.

            Examples:
            Reading books and studying = related.
            Walking and running = related.
            Learning Java and solving programming problems = related.
            Reading books and weightlifting = unrelated.

            Return exactly:
            SCORE: number from 0 to 100
            REASON: short explanation in Arabic

            IMPORTANT:
            The REASON must be written entirely in Arabic.
            Explain clearly why the two goals are related.
            Do not use English words in the REASON.
            Keep the explanation short and natural.
            Do not return anything else.
            """;

        String prompt = "First goal: " + goal1 + "\nSecond goal: " + goal2;

        return ask(instructions, prompt, "SCORE: 0\nREASON: تعذر تحليل توافق الأهداف");
    }
    public AiScheduleResponse suggestSchedule(AiScheduleRequest request){

        if(request.getDescription() == null || request.getDescription().isBlank()){
            throw new ApiException("Goal description is required");
        }

        String instructions = """
            You are an AI scheduling assistant for Atahad.

            Create a realistic weekly schedule based on the user's goal.

            Rules:
            1. Understand the user's preferred days, times, and frequency.
            2. Suggest specific future dates.
            3. Use Asia/Riyadh timezone.
            4. Respect the user's preferences.
            5. Never suggest past dates.
            6. Return 3 suggestions unless the user requests a different number.
            7. Do not claim to have checked Google Calendar availability.
            8. Return ONLY valid JSON without markdown.

            JSON format:
            {
              "title": "Reading",
              "durationMinutes": 30,
              "suggestions": [
                {
                  "date": "2026-10-27",
                  "startTime": "19:00",
                  "endTime": "19:30"
                }
              ]
            }
            """;

        String prompt = "Today's date: " + LocalDate.now(ZoneId.of("Asia/Riyadh"))
                + "\nUser goal: " + request.getDescription();

        String answer = ask(instructions, prompt, "");

        if(answer == null || answer.isBlank()){
            throw new ApiException("AI scheduling is currently unavailable");
        }

        try{
            ObjectMapper mapper = new ObjectMapper();

            AiScheduleResponse response = mapper.readValue(answer, AiScheduleResponse.class);

            if(response.getTitle() == null || response.getTitle().isBlank()
                    || response.getSuggestions() == null || response.getSuggestions().isEmpty()){
                throw new ApiException("AI returned an invalid schedule");
            }

            return response;

        }catch(Exception e){
            throw new ApiException("Failed to generate AI schedule");
        }
    }
}
