package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.util.UriUtils;
import tools.jackson.databind.JsonNode;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Component
public class TomTomPlacesProvider {
    private final RestClient restClient;
    private final MapProperties.TomTom properties;
    private static final Set<String> TYPES = Set.of("pois", "addresses", "streets", "intersections", "areas");

    @Autowired
    public TomTomPlacesProvider(RestClient.Builder builder, MapProperties mapProperties) {
        this.properties = mapProperties.getTomtom();
        int timeout = properties.getTimeoutMs() > 0 ? properties.getTimeoutMs() : 4000;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofMillis(timeout));
        factory.setReadTimeout(Duration.ofMillis(timeout));
        this.restClient = builder.requestFactory(factory).build();
    }

    public TomTomPlacesProvider(RestClient restClient, MapProperties mapProperties) {
        this.restClient = restClient;
        this.properties = mapProperties.getTomtom();
    }

    public boolean isEnabled() {
        return properties.isEnabled() && properties.getApiKey() != null && !properties.getApiKey().isBlank();
    }

    public List<LocationSearchResultResponse> suggest(String query, int limit, Double latitude, Double longitude, String sessionId) {
        if (!isEnabled()) throw new AppException("Tìm kiếm TomTom chưa được bật trên máy chủ", HttpStatus.SERVICE_UNAVAILABLE);
        Map<String, Object> body = new java.util.LinkedHashMap<>();
        body.put("query", query);
        body.put("maxResults", Math.min(10, limit));
        body.put("filters", Map.of("countryCodesIso2", List.of("VN")));
        if (latitude != null && longitude != null) body.put("origin", point(longitude, latitude));
        JsonNode response = post("/places/suggest", body, sessionId,
                "results(id,type,title,subtitles,more)");
        return mapResults(response, sessionId);
    }

    public LocationSearchResultResponse details(String type, String id, String sessionId) {
        String normalizedType = type == null ? "" : type.toLowerCase(Locale.ROOT);
        validateType(normalizedType);
        if (id == null || id.isBlank() || id.length() > 200) throw new BadRequestException("Mã địa điểm TomTom không hợp lệ");
        JsonNode response = request("/places/details/" + normalizedType + "/" + UriUtils.encodePathSegment(id, StandardCharsets.UTF_8), sessionId,
                "id,type,title,position,address");
        JsonNode result = response.path("result");
        if (result.isMissingNode()) result = response;
        LocationSearchResultResponse mapped = mapResult(result, sessionId, false);
        if (mapped == null) throw new ResourceNotFoundException("TomTom không trả về tọa độ cho địa điểm đã chọn");
        return mapped;
    }

    public List<LocationSearchResultResponse> discover(String query, String poiType, Double latitude, Double longitude, String sessionId) {
        if (!isEnabled()) throw new AppException("Tìm kiếm TomTom chưa được bật trên máy chủ", HttpStatus.SERVICE_UNAVAILABLE);
        Map<String, Object> body = new java.util.LinkedHashMap<>();
        body.put("query", query);
        body.put("maxResults", 10);
        Map<String, Object> filters = new java.util.LinkedHashMap<>();
        filters.put("countryCodesIso2", List.of("VN"));
        if (poiType != null && !poiType.isBlank()) filters.put("poiTypes", List.of(poiType));
        body.put("filters", filters);
        if (latitude != null && longitude != null) body.put("origin", point(longitude, latitude));
        return mapResults(post("/places/discover", body, sessionId,
                "results(id,type,title,subtitles,position,address,poiTypes,more)"), sessionId);
    }

    private Map<String, Object> point(double longitude, double latitude) {
        return Map.of("type", "point", "coordinates", List.of(longitude, latitude));
    }

    private JsonNode post(String path, Map<String, Object> body, String sessionId, String attributes) {
        try {
            return restClient.post().uri(baseUrl() + path).headers(h -> headers(h, sessionId, attributes))
                    .contentType(MediaType.APPLICATION_JSON).body(body).retrieve().body(JsonNode.class);
        } catch (RestClientResponseException ex) {
            throw upstreamError(ex);
        } catch (ResourceAccessException ex) {
            throw new AppException("Không thể kết nối dịch vụ tìm kiếm TomTom", HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    private JsonNode request(String path, String sessionId, String attributes) {
        if (!isEnabled()) throw new AppException("Tìm kiếm TomTom chưa được bật trên máy chủ", HttpStatus.SERVICE_UNAVAILABLE);
        try {
            return restClient.get().uri(baseUrl() + path).headers(h -> headers(h, sessionId, attributes))
                    .retrieve().body(JsonNode.class);
        } catch (RestClientResponseException ex) {
            throw upstreamError(ex);
        } catch (ResourceAccessException ex) {
            throw new AppException("Không thể kết nối dịch vụ tìm kiếm TomTom", HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    private void headers(org.springframework.http.HttpHeaders headers, String sessionId, String attributes) {
        headers.set("TomTom-Api-Key", properties.getApiKey().trim());
        headers.set("TomTom-Api-Version", "3");
        headers.set("Attributes", attributes);
        headers.set("Accept-Language", "vi-VN");
        if (sessionId != null && sessionId.matches("[0-9a-fA-F-]{36}")) headers.set("Session-Id", sessionId);
    }

    private String baseUrl() {
        String value = properties.getBaseUrl();
        if (value == null || value.isBlank()) value = "https://api.tomtom.com/maps/orbis";
        return value.replaceAll("/+$", "");
    }

    private RuntimeException upstreamError(RestClientResponseException ex) {
        if (ex.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) return new Travel_Planner.Travel_Planner.exception.RateLimitExceededException("Dịch vụ tìm kiếm TomTom đã đạt giới hạn lượt gọi.");
        return new AppException("Dịch vụ tìm kiếm TomTom hiện không khả dụng (HTTP " + ex.getStatusCode().value() + ")", HttpStatus.SERVICE_UNAVAILABLE);
    }

    private List<LocationSearchResultResponse> mapResults(JsonNode response, String sessionId) {
        JsonNode results = response == null ? null : response.path("results");
        if (results == null || !results.isArray()) return List.of();
        List<LocationSearchResultResponse> mapped = new ArrayList<>();
        for (JsonNode node : results) {
            LocationSearchResultResponse result = mapResult(node, sessionId, true);
            if (result != null) mapped.add(result);
        }
        return mapped;
    }

    private LocationSearchResultResponse mapResult(JsonNode node, String sessionId, boolean suggestion) {
        if (node == null || node.isMissingNode()) return null;
        String id = node.path("id").asText("");
        String type = node.path("type").asText("pois").toLowerCase(Locale.ROOT);
        JsonNode more = node.path("more");
        JsonNode pathParameters = more.path("pathParameters");
        String providerType = "";
        if (pathParameters.isArray()) {
            for (JsonNode parameter : pathParameters) {
                String name = parameter.path("parameter").asText("");
                String value = parameter.path("argument").asText("");
                if ("type".equals(name)) providerType = value;
                if ("id".equals(name) && id.isBlank()) id = value;
            }
        }
        if (id.isBlank() && "discoverAction".equals(type)) {
            id = more.path("requestBody").path("filters").path("poiTypes").path(0).asText("");
        }
        if (id.isBlank()) return null;
        JsonNode position = node.path("position");
        JsonNode coordinates = position.path("coordinates");
        double lon = Double.NaN, lat = Double.NaN;
        if (coordinates.isArray() && coordinates.size() >= 2) {
            lon = coordinates.get(0).asDouble(Double.NaN);
            lat = coordinates.get(1).asDouble(Double.NaN);
        } else {
            lat = position.path("lat").asDouble(Double.NaN);
            lon = position.path("lon").asDouble(position.path("lng").asDouble(Double.NaN));
        }
        JsonNode address = node.path("address");
        String title = node.path("title").asText(node.path("name").asText(""));
        String formatted = address.path("freeformAddress").asText(address.path("label").asText(title));
        JsonNode subtitles = node.path("subtitles");
        if ((formatted.isBlank() || formatted.equals(title)) && subtitles.isArray()) {
            List<String> parts = new ArrayList<>();
            for (JsonNode subtitle : subtitles) {
                if (!subtitle.asText().isBlank()) parts.add(subtitle.asText().trim());
            }
            if (!parts.isEmpty()) formatted = String.join(", ", parts);
        }
        boolean hasCoordinates = Double.isFinite(lat) && Double.isFinite(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
        if (providerType.isBlank()) providerType = switch (type) {
            case "poi" -> "pois";
            case "address" -> "addresses";
            case "street" -> "streets";
            case "intersection" -> "intersections";
            case "area" -> "areas";
            default -> type;
        };
        boolean requiresDetails = suggestion && "details".equalsIgnoreCase(more.path("operation").asText());
        return LocationSearchResultResponse.builder().placeId(providerType + ":" + id).name(title.isBlank() ? formatted : title)
                .formattedAddress(formatted).latitude(hasCoordinates ? lat : null).longitude(hasCoordinates ? lon : null)
                .category(node.path("poiTypes").path(0).path("name").asText(node.path("poiCategory").asText(node.path("category").asText("place")))).type(type)
                .provider("TOMTOM").providerId(id).providerType(providerType).requiresDetails(requiresDetails)
                .sessionId(sessionId).build();
    }

    private void validateType(String type) {
        if (type == null || !TYPES.contains(type.toLowerCase(Locale.ROOT))) throw new BadRequestException("Loại kết quả TomTom không hợp lệ");
    }
}
