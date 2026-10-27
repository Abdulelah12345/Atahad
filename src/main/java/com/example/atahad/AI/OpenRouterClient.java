package com.example.atahad.AI;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.*;
import java.util.regex.Pattern;

@Service
@Slf4j
public class OpenRouterClient {
    @Value("${openrouter.api-key:}") private String apiKey;
    @Value("${openrouter.url:https://openrouter.ai/api/v1/chat/completions}") private String url;
    @Value("${openrouter.models.text:google/gemma-4-26b-a4b-it:free}") private String textModel;
    @Value("${openrouter.models.vision:google/gemma-4-26b-a4b-it:free}") private String visionModel;
    @Value("${openrouter.models.timer:google/gemma-4-26b-a4b-it:free}") private String timerModel;
    @Value("${openrouter.fallbacks.text:google/gemma-4-31b-it:free,nvidia/nemotron-3.5-super-vl:free}")
    private String textFallbacks = "google/gemma-4-31b-it:free,nvidia/nemotron-3.5-super-vl:free";
    @Value("${openrouter.fallbacks.vision:google/gemma-4-31b-it:free,nvidia/nemotron-3.5-super-vl:free}")
    private String visionFallbacks = "google/gemma-4-31b-it:free,nvidia/nemotron-3.5-super-vl:free";
    @Value("${openrouter.fallbacks.timer:google/gemma-4-31b-it:free,nvidia/nemotron-3.5-super-vl:free}")
    private String timerFallbacks = "google/gemma-4-31b-it:free,nvidia/nemotron-3.5-super-vl:free";
    private static final int MAX_ATTEMPTS = 3;
    private static final int REQUEST_SECONDS = 25;
    private static final Pattern DECISION = Pattern.compile("(?m)^\\s*DECISION:\\s*(ACCEPTED|REJECTED|ESCALATED)\\s*$");
    private static final Pattern REASON = Pattern.compile("(?m)^\\s*REASON:\\s*\\S");
    private static final Pattern QUESTION = Pattern.compile("Q:\\s*(.+?)\\s*\\n\\s*A\\)\\s*(.+?)\\s*\\n\\s*B\\)\\s*(.+?)\\s*\\n\\s*C\\)\\s*(.+?)\\s*\\n\\s*ANSWER:\\s*([ABCabc])");
    private final RestClient client;

    public OpenRouterClient() {
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(8)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(Duration.ofSeconds(REQUEST_SECONDS));
        client = RestClient.builder().requestFactory(factory).build();
    }

    public boolean isConfigured() { return apiKey != null && !apiKey.isBlank(); }

    @PostConstruct
    void reportConfiguration() {
        log.info("OpenRouter initialized (configured={}, maxAttempts={}, requestTimeoutSeconds={})",
                isConfigured(), MAX_ATTEMPTS, REQUEST_SECONDS);
    }

    public String complete(String purpose, String instructions, String prompt, List<String> images, String fallback) {
        if (!isConfigured()) {
            log.warn("OpenRouter {} skipped (key not configured)", purpose);
            return fallback;
        }
        boolean vision = purpose.equals("vision") || (images != null && !images.isEmpty());
        String model = vision ? visionModel : purpose.equals("timer") ? timerModel : textModel;
        String alternatives = vision ? visionFallbacks : purpose.equals("timer") ? timerFallbacks : textFallbacks;
        List<String> models = freeModels(model, alternatives);
        if (models.isEmpty()) {
            log.warn("OpenRouter {} skipped (no allowed free primary model)", purpose);
            return fallback;
        }
        Object content = prompt;
        if (vision && images != null && !images.isEmpty()) {
            List<Object> parts = new ArrayList<>();
            parts.add(Map.of("type", "text", "text", prompt));
            for (String image : images) {
                parts.add(Map.of("type", "image_url", "image_url", Map.of("url", image)));
            }
            content = parts;
        }

        // try the next model on a failure, a clear accept/reject stops here
        String uncertain = null;
        for (int index = 0; index < models.size(); index++) {
            String candidate = models.get(index);
            long started = System.nanoTime();
            log.info("OpenRouter {} trying model={} attempt={}/{} images={}", purpose, candidate,
                    index + 1, models.size(), images == null ? 0 : images.size());
            try {
                Map<?, ?> response = client.post().uri(url).header("Authorization", "Bearer " + apiKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(Map.of("model", candidate, "max_tokens", 1800,
                                "messages", List.of(Map.of("role", "system", "content", instructions),
                                        Map.of("role", "user", "content", content))))
                        .retrieve().body(Map.class);
                String reply = readReply(response);
                ReplyKind kind = reply == null ? ReplyKind.INVALID : classify(instructions, reply);
                if (kind == ReplyKind.VALID) {
                    log.info("OpenRouter {} completed using {} (attempt={}, elapsedMs={})", purpose,
                            candidate, index + 1, (System.nanoTime() - started) / 1_000_000);
                    return reply;
                }
                if (kind == ReplyKind.UNCERTAIN) { uncertain = reply; }
                log.warn("OpenRouter {} model={} returned {}; trying next if available", purpose,
                        candidate, kind == ReplyKind.UNCERTAIN ? "inconclusive analysis" : "empty or invalid content");
            } catch (RestClientResponseException exception) {
                log.warn("OpenRouter {} model={} failed (HTTP {}); trying next if available",
                        purpose, candidate, exception.getStatusCode().value());
            } catch (Exception exception) {
                Throwable cause = exception;
                for (int depth = 0; depth < 8 && cause.getCause() != null && cause.getCause() != cause; depth++) {
                    cause = cause.getCause();
                }
                log.warn("OpenRouter {} model={} failed ({}, rootCause={}); trying next if available",
                        purpose, candidate, exception.getClass().getSimpleName(), cause.getClass().getSimpleName());
            }
        }
        log.warn("OpenRouter {} exhausted {} models without a conclusive response", purpose, models.size());
        return uncertain == null ? fallback : uncertain;
    }

    private String readReply(Map<?, ?> response) {
        if (response == null || response.containsKey("error")) { return null; }
        if (!(response.get("choices") instanceof List<?> choices) || choices.isEmpty()) { return null; }
        if (!(choices.get(0) instanceof Map<?, ?> choice) || "length".equals(choice.get("finish_reason"))) { return null; }
        if (!(choice.get("message") instanceof Map<?, ?> message)) { return null; }
        if (!(message.get("content") instanceof String text) || text.isBlank()) { return null; }
        return text.trim();
    }

    private ReplyKind classify(String instructions, String reply) {
        String clean = reply.replace("*", "").trim();
        if (instructions.contains("DECISION:")) {
            var decision = DECISION.matcher(clean);
            if (!decision.find() || !REASON.matcher(clean).find()) { return ReplyKind.INVALID; }
            return decision.group(1).equals("ESCALATED") ? ReplyKind.UNCERTAIN : ReplyKind.VALID;
        }
        if (instructions.contains("Q:") && instructions.contains("ANSWER:")) {
            if (clean.equals("READABLE: NO") || clean.equals("TOPIC: UNCLEAR")) { return ReplyKind.UNCERTAIN; }
            return QUESTION.matcher(clean).results().count() == 4 ? ReplyKind.VALID : ReplyKind.INVALID;
        }
        return ReplyKind.VALID;
    }

    private List<String> freeModels(String primary, String alternatives) {
        if (primary == null || !isFree(primary.trim())) { return List.of(); }
        Set<String> ordered = new LinkedHashSet<>();
        ordered.add(primary.trim());
        if (alternatives != null) {
            for (String item : alternatives.split(",")) {
                String candidate = item.trim();
                if (isFree(candidate)) { ordered.add(candidate); }
            }
        }
        return ordered.stream().limit(MAX_ATTEMPTS).toList();
    }

    private boolean isFree(String model) {
        return model.equals("openrouter/free") ||
                (model.contains("/") && model.endsWith(":free") && !model.contains(" "));
    }

    private enum ReplyKind { VALID, UNCERTAIN, INVALID }
}
