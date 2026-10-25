package com.example.atahad.AI;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.*;

// اتصال واحد لجميع ميزات البروف؛ المفاتيح في متغيرات البيئة وليست في Git.
@Service
public class OpenRouterClient {
    @Value("${openrouter.api-key:}") private String apiKey;
    @Value("${openrouter.url:https://openrouter.ai/api/v1/chat/completions}") private String url;
    @Value("${openrouter.models.text:google/gemma-4-26b-a4b-it:free}") private String textModel;
    @Value("${openrouter.models.vision:google/gemma-4-26b-a4b-it:free}") private String visionModel;
    @Value("${openrouter.models.timer:google/gemma-4-26b-a4b-it:free}") private String timerModel;
    private final RestClient client;

    public OpenRouterClient() {
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(Duration.ofSeconds(45));
        client = RestClient.builder().requestFactory(factory).build();
    }

    public boolean isConfigured() { return apiKey != null && !apiKey.isBlank(); }

    public String complete(String purpose, String instructions, String prompt, List<String> images, String fallback) {
        if (!isConfigured()) { return fallback; }
        String model = textModel;
        if (purpose.equals("vision")) { model = visionModel; }
        if (purpose.equals("timer")) { model = timerModel; }
        // لا نتحول تلقائيا إلى نموذج مدفوع عند تعطل المجاني.
        if (model == null || !(model.endsWith(":free") || model.equals("openrouter/free"))) { return fallback; }
        try {
            Object content = prompt;
            if (images != null && !images.isEmpty()) {
                List<Object> parts = new ArrayList<>();
                parts.add(Map.of("type", "text", "text", prompt));
                for (String image : images) {
                    parts.add(Map.of("type", "image_url", "image_url", Map.of("url", image)));
                }
                content = parts;
            }
            Map<?, ?> response = client.post().uri(url).header("Authorization", "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("model", model, "max_tokens", 1800,
                            "messages", List.of(Map.of("role", "system", "content", instructions), Map.of("role", "user", "content", content))))
                    .retrieve().body(Map.class);
            if (response == null) { return fallback; }
            List<?> choices = (List<?>) response.get("choices");
            if (choices == null || choices.isEmpty()) { return fallback; }
            Map<?, ?> message = (Map<?, ?>) ((Map<?, ?>) choices.get(0)).get("message");
            Object value = message.get("content");
            if (value == null || value.toString().isBlank()) { return fallback; }
            return value.toString().trim();
        } catch (Exception exception) { return fallback; }
    }
}
