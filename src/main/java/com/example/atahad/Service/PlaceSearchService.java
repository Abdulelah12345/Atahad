package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.PlaceResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// the member searches for a place by its name (Google Places, Text Search) and the app takes its location
// the key stays on the server (google.places.api-key in application-local.properties)
@Service
public class PlaceSearchService {

    private static final String URL = "https://places.googleapis.com/v1/places:searchText";

    private final RestClient client;
    private final String apiKey;

    public PlaceSearchService(@Value("${google.places.api-key:}") String apiKey) {
        this.apiKey = apiKey;
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(Duration.ofSeconds(15));
        client = RestClient.builder().requestFactory(factory).build();
    }

    // lat and lng are optional, the results near the member come first
    public List<PlaceResponse> search(String query, Double lat, Double lng) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new ApiException("Place search is not set up (google.places.api-key)");
        }
        if (query == null || query.trim().length() < 2) {
            throw new ApiException("Write at least 2 letters of the place name");
        }

        Map<String, Object> body = new HashMap<>();
        body.put("textQuery", query.trim());
        body.put("languageCode", "ar");
        body.put("regionCode", "SA");
        body.put("pageSize", 8);
        if (lat != null && lng != null) {
            body.put("locationBias", Map.of("circle", Map.of(
                    "center", Map.of("latitude", lat, "longitude", lng),
                    "radius", 30000.0)));
        }

        Map<?, ?> response;
        try {
            response = client.post()
                    .uri(URL)
                    .contentType(MediaType.APPLICATION_JSON)
                    .header("X-Goog-Api-Key", apiKey)
                    .header("X-Goog-FieldMask", "places.displayName,places.formattedAddress,places.location")
                    .body(body)
                    .retrieve()
                    .body(Map.class);
        } catch (Exception e) {
            System.out.println("Place search failed: " + e.getMessage()); // the reason from Google (wrong key, API not on ...)
            throw new ApiException("Place search failed, try again");
        }

        List<PlaceResponse> places = new ArrayList<>();
        if (response == null || !(response.get("places") instanceof List<?> list)) {
            return places;
        }
        for (Object item : list) {
            if (!(item instanceof Map<?, ?> place) || !(place.get("location") instanceof Map<?, ?> location)) {
                continue;
            }
            String name = place.get("displayName") instanceof Map<?, ?> display ? String.valueOf(display.get("text")) : "";
            Object address = place.get("formattedAddress");
            places.add(new PlaceResponse(name, address == null ? "" : address.toString(),
                    ((Number) location.get("latitude")).doubleValue(),
                    ((Number) location.get("longitude")).doubleValue()));
        }
        return places;
    }
}
