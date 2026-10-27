
package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.LearnResourceDTO;
import tools.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import tools.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class LearnQuestService {

    private final RestClient restClient = RestClient.create();
    private final ObjectMapper objectMapper = new ObjectMapper();
    public List<LearnResourceDTO> search(String query) {
        validateQuery(query);

        List<LearnResourceDTO> results = new ArrayList<>();

        // A provider failure must not prevent other providers
        // from returning their available results.
        try {
            results.addAll(searchBooks(query));
        } catch (RestClientException ignored) {}

        try {
            results.addAll(searchPodcasts(query));
        } catch (RestClientException ignored) {}

        try {
            results.addAll(searchCourses(query));
        } catch (RestClientException ignored) {}

        return results;
    }

    public List<LearnResourceDTO> searchBooks(String query) {
        validateQuery(query);

        JsonNode response = restClient.get()
                .uri("https://openlibrary.org/search.json",
                        builder -> builder
                                .queryParam("q", query.trim())
                                .queryParam("limit", 10)
                                .queryParam("fields",
                                        "key,title,author_name,cover_i,first_publish_year")
                                .build())
                .retrieve()
                .body(JsonNode.class);

        List<LearnResourceDTO> books = new ArrayList<>();

        if (response == null) return books;

        for (JsonNode book : response.path("docs")) {
            String key = value(book, "key");
            String coverId = value(book, "cover_i");

            String author = "";
            JsonNode authors = book.path("author_name");

            if (authors.isArray() && !authors.isEmpty()) {
                author = authors.get(0).asText();
            }

            String image = coverId.isBlank() ? null :
                    "https://covers.openlibrary.org/b/id/" + coverId + "-M.jpg";

            books.add(new LearnResourceDTO(
                    value(book, "title"),
                    "BOOK",
                    author,
                    "First published: " + value(book, "first_publish_year"),
                    image,
                    "Open Library",
                    key.startsWith("/works/")
                            ? "https://openlibrary.org" + key
                            : "https://openlibrary.org"
            ));
        }

        return books;
    }

    public List<LearnResourceDTO> searchPodcasts(String query) {
        validateQuery(query);

        String responseBody = restClient.get()
                .uri(builder -> builder
                        .scheme("https")
                        .host("itunes.apple.com")
                        .path("/search")
                        .queryParam("term", query.trim())
                        .queryParam("media", "podcast")
                        .queryParam("entity", "podcast")
                        .queryParam("country", "SA")
                        .queryParam("limit", 10)
                        .build())
                .retrieve()
                .body(String.class);

        JsonNode response = responseBody == null
                ? null
                : objectMapper.readTree(responseBody);

        List<LearnResourceDTO> podcasts = new ArrayList<>();

        if (response == null) return podcasts;

        for (JsonNode podcast : response.path("results")) {
            podcasts.add(new LearnResourceDTO(
                    value(podcast, "collectionName"),
                    "PODCAST",
                    value(podcast, "artistName"),
                    value(podcast, "primaryGenreName"),
                    nullableValue(podcast, "artworkUrl600"),
                    "Apple Podcasts",
                    nullableValue(podcast, "collectionViewUrl")
            ));
        }

        return podcasts;
    }

    public List<LearnResourceDTO> searchCourses(String query) {
        validateQuery(query);

        List<LearnResourceDTO> courses = new ArrayList<>();
        String keyword = query.trim().toLowerCase();

        // Edraak provides catalog pages, so filter the returned
        // courses locally. Three pages cover up to 300 entries.
        for (int offset = 0; offset < 300; offset += 100) {
            final int currentOffset = offset;

            JsonNode response = restClient.get()
                    .uri("https://www.edraak.org/api/marketing/courses/",
                            builder -> builder
                                    .queryParam("limit", 100)
                                    .queryParam("offset", currentOffset)
                                    .build())
                    .retrieve()
                    .body(JsonNode.class);

            if (response == null) break;

            for (JsonNode course : response.path("results")) {
                String titleAr = value(course, "name_ar");
                String titleEn = value(course, "name_en");
                String description = value(course, "short_description");
                String categoryAr = value(course.path("category"), "name_ar");
                String categoryEn = value(course.path("category"), "name_en");

                String searchable = (
                        titleAr + " " + titleEn + " " +
                                description + " " + categoryAr + " " + categoryEn
                ).toLowerCase();

                if (!searchable.contains(keyword)) continue;

                courses.add(new LearnResourceDTO(
                        titleAr.isBlank() ? titleEn : titleAr,
                        "COURSE",
                        "Edraak",
                        description,
                        nullableValue(course, "cover_image"),
                        "Edraak",
                        nullableValue(course, "course_url")
                ));

                if (courses.size() >= 10) return courses;
            }

            if (response.path("next").isNull()
                    || response.path("next").isMissingNode()) {
                break;
            }
        }

        return courses;
    }

    private void validateQuery(String query) {
        if (query == null || query.isBlank()) {
            throw new ApiException("Search query is required");
        }

        if (query.trim().length() > 100) {
            throw new ApiException("Search query is too long");
        }
    }

    private String value(JsonNode node, String field) {
        JsonNode result = node.path(field);
        return result.isMissingNode() || result.isNull()
                ? "" : result.asText("");
    }

    private String nullableValue(JsonNode node, String field) {
        String result = value(node, field);
        return result.isBlank() ? null : result;
    }
}
