package com.example.atahad.Service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

// one place for every AI text in the app (group alerts, the weekly settlement, goal ideas, the monthly wrapped)
// works with any OpenAI compatible chat API, the key is read from the environment variable AI_API_KEY
// without a key (or if the AI fails) the app uses the fallback text, so nothing stops working
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
        if(apiKey == null || apiKey.isBlank()){
            return fallback;
        }
        try{
            Map<String, Object> body = Map.of(
                    "model", model,
                    "messages", List.of(
                            Map.of("role", "system", "content", instructions),
                            Map.of("role", "user", "content", prompt)
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

    // GENTLE is kind, HYPE is loud and funny, both stay respectful
    public String tone(String humorLevel){
        if("HYPE".equals(humorLevel)){
            return "Write in Saudi Arabic dialect, loud, funny and full of energy like friends teasing each other, never insulting.";
        }
        return "Write in Saudi Arabic dialect, kind, warm and encouraging.";
    }
}
