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

    // GENTLE is kind, HYPE is loud and funny, both stay respectful
    public String tone(String humorLevel){
        if("HYPE".equals(humorLevel)){
            return "Write in Saudi Arabic dialect, loud, funny and full of energy like friends teasing each other, never insulting.";
        }
        return "Write in Saudi Arabic dialect, kind, warm and encouraging.";
    }

    // Gemini does not open links by itself, so the image is downloaded and sent inside the request
    private String toDataUrl(String image){
        if(image.startsWith("data:")){
            return image;
        }
        ResponseEntity<byte[]> file = restClient.get().uri(image).retrieve().toEntity(byte[].class);
        String type = file.getHeaders().getContentType() == null ? "image/jpeg" : file.getHeaders().getContentType().toString();
        return "data:" + type + ";base64," + Base64.getEncoder().encodeToString(file.getBody());
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
