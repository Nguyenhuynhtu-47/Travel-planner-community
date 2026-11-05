package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.service.GeocodingProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.util.UriComponentsBuilder;
import tools.jackson.databind.JsonNode;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * HERE Geocoding and Search REST API v7 Provider.
 * Supports Geocode (/v1/geocode) and Discover (/v1/discover) for Vietnam POIs.
 */
@Component
public class HereGeocodingProvider implements GeocodingProvider {

    private static final Logger logger = LoggerFactory.getLogger(HereGeocodingProvider.class);
    private static final String PROVIDER_NAME = "HERE";

    private final RestClient restClient;
    private final MapProperties mapProperties;

    @Autowired
    public HereGeocodingProvider(RestClient.Builder restClientBuilder, MapProperties mapProperties) {
        this.mapProperties = mapProperties;
        int timeoutMs = mapProperties.getGeocoding().getTimeoutMs();
        if (timeoutMs <= 0) {
            timeoutMs = 3000;
        }

        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(Duration.ofMillis(timeoutMs));
        requestFactory.setReadTimeout(Duration.ofMillis(timeoutMs));

        this.restClient = restClientBuilder
                .requestFactory(requestFactory)
                .build();
    }

    public HereGeocodingProvider(RestClient restClient, MapProperties mapProperties) {
        this.restClient = restClient;
        this.mapProperties = mapProperties;
    }

    @Override
    public String getProviderName() {
        return PROVIDER_NAME;
    }

    @Override
    public boolean isConfigured() {
        String key = mapProperties.getGeocoding().getHereApiKey();
        return key != null && !key.trim().isEmpty();
    }

    @Override
    public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {
        if (!isConfigured()) {
            logger.debug("HERE API key is not configured. Returning empty results.");
            return Collections.emptyList();
        }

        String apiKey = mapProperties.getGeocoding().getHereApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getHereBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://geocode.search.hereapi.com/v1";
        }

        UriComponentsBuilder uriBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/geocode")
                .queryParam("q", query)
                .queryParam("apiKey", apiKey)
                .queryParam("limit", limit)
                .queryParam("in", "countryCode:VNM")
                .queryParam("lang", "vi");

        if (latitude != null && longitude != null) {
            uriBuilder.queryParam("at", String.format(Locale.ROOT, "%.5f,%.5f", latitude, longitude));
        }

        URI uri = uriBuilder.build().encode().toUri();
        return executeHereQuery(uri, query);
    }

    @Override
    public List<LocationSearchResultResponse> searchInArea(String query, int limit, Double latitude, Double longitude, List<Double> boundingBox, Integer radiusMeters) {
        if (!isConfigured()) {
            return Collections.emptyList();
        }

        String apiKey = mapProperties.getGeocoding().getHereApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getHereDiscoverBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://discover.search.hereapi.com/v1";
        }

        UriComponentsBuilder uriBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/discover")
                .queryParam("q", query)
                .queryParam("limit", limit)
                .queryParam("apiKey", apiKey)
                .queryParam("lang", "vi");

        if (boundingBox != null && boundingBox.size() == 4) {
            double minLat = Math.min(boundingBox.get(0), boundingBox.get(1));
            double maxLat = Math.max(boundingBox.get(0), boundingBox.get(1));
            double minLon = Math.min(boundingBox.get(2), boundingBox.get(3));
            double maxLon = Math.max(boundingBox.get(2), boundingBox.get(3));
            uriBuilder.queryParam("in", String.format(Locale.ROOT, "bbox:%.5f,%.5f,%.5f,%.5f", minLon, minLat, maxLon, maxLat));
        } else if (latitude != null && longitude != null) {
            int rad = (radiusMeters != null && radiusMeters > 0) ? radiusMeters : 10000;
            uriBuilder.queryParam("in", String.format(Locale.ROOT, "circle:%.5f,%.5f;r=%d", latitude, longitude, rad));
        } else {
            uriBuilder.queryParam("in", "countryCode:VNM");
        }

        URI uri = uriBuilder.build().encode().toUri();
        return executeHereQuery(uri, query);
    }

    private List<LocationSearchResultResponse> executeHereQuery(URI uri, String query) {
        try {
            JsonNode response = restClient.get()
                    .uri(uri)
                    .retrieve()
                    .body(JsonNode.class);

            if (response == null || !response.has("items") || !response.path("items").isArray()) {
                return Collections.emptyList();
            }

            List<LocationSearchResultResponse> results = new ArrayList<>();
            Set<String> seenPlaceIds = new HashSet<>();
            Set<String> seenCoordKeys = new HashSet<>();

            for (JsonNode item : response.path("items")) {
                LocationSearchResultResponse parsed = parseHereItem(item);
                if (parsed != null) {
                    String coordKey = String.format(Locale.ROOT, "%s:%.4f:%.4f",
                            parsed.getName().toLowerCase(Locale.ROOT).trim(),
                            parsed.getLatitude(),
                            parsed.getLongitude());
                    if (seenPlaceIds.add(parsed.getPlaceId()) && seenCoordKeys.add(coordKey)) {
                        results.add(parsed);
                    }
                }
            }
            return results;

        } catch (RestClientResponseException ex) {
            if (ex.getStatusCode() == HttpStatus.NOT_FOUND) {
                return Collections.emptyList();
            }
            if (ex.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                logger.warn("HERE upstream rate limit exceeded (HTTP 429) for query: {}", query);
                throw new RateLimitExceededException("Dịch vụ tìm kiếm HERE tạm thời đạt giới hạn lượt gọi.");
            }
            logger.warn("HERE geocoding error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
            return Collections.emptyList();
        } catch (ResourceAccessException ex) {
            logger.warn("HERE geocoding timeout or connection error for query: {}", query);
            return Collections.emptyList();
        } catch (Exception ex) {
            logger.warn("Unexpected error calling HERE geocoding: {}", ex.getMessage());
            return Collections.emptyList();
        }
    }

    @Override
    public List<LocationSearchResultResponse> searchNearby(double latitude, double longitude, String category, int radiusMeters, int limit) {
        if (!isConfigured()) {
            return Collections.emptyList();
        }
        String apiKey = mapProperties.getGeocoding().getHereApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getHereDiscoverBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://discover.search.hereapi.com/v1";
        }

        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/discover")
                .queryParam("q", category)
                .queryParam("at", String.format(Locale.ROOT, "%.5f,%.5f", latitude, longitude))
                .queryParam("limit", limit)
                .queryParam("apiKey", apiKey)
                .queryParam("in", "countryCode:VNM")
                .queryParam("lang", "vi")
                .build().encode().toUri();

        try {
            JsonNode response = restClient.get().uri(uri).retrieve().body(JsonNode.class);
            if (response == null || !response.has("items") || !response.path("items").isArray()) {
                return Collections.emptyList();
            }
            List<LocationSearchResultResponse> results = new ArrayList<>();
            for (JsonNode item : response.path("items")) {
                LocationSearchResultResponse parsed = parseHereItem(item);
                if (parsed != null) results.add(parsed);
            }
            return results;
        } catch (Exception ex) {
            logger.warn("HERE discover error: {}", ex.getMessage());
            return Collections.emptyList();
        }
    }

    @Override
    public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {
        if (!isConfigured()) {
            return null;
        }
        String apiKey = mapProperties.getGeocoding().getHereApiKey().trim();
        String baseUrl = "https://revgeocode.search.hereapi.com/v1";

        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/revgeocode")
                .queryParam("at", String.format(Locale.ROOT, "%.5f,%.5f", latitude, longitude))
                .queryParam("apiKey", apiKey)
                .queryParam("lang", "vi")
                .build().encode().toUri();

        try {
            JsonNode response = restClient.get().uri(uri).retrieve().body(JsonNode.class);
            if (response == null || !response.has("items") || !response.path("items").isArray() || response.path("items").isEmpty()) {
                return null;
            }
            return parseHereItem(response.path("items").get(0));
        } catch (Exception ex) {
            logger.warn("HERE reverse geocode error: {}", ex.getMessage());
            return null;
        }
    }

    private LocationSearchResultResponse parseHereItem(JsonNode node) {
        if (node == null || node.isMissingNode()) {
            return null;
        }

        String id = node.path("id").asText("here_" + System.currentTimeMillis());
        String title = node.path("title").asText(null);
        JsonNode address = node.path("address");
        String label = address.path("label").asText(null);
        String city = address.path("city").asText(null);
        String district = address.path("district").asText(null);

        String resultType = node.path("resultType").asText("place");
        if (node.hasNonNull("localityType") && !node.path("localityType").asText().isBlank()) {
            resultType = node.path("localityType").asText().trim();
        }

        String name = title != null && !title.isBlank() ? title.trim() : (label != null ? label.split(",")[0].trim() : "Vị trí đã chọn");
        if (resultType.toLowerCase().contains("administrative")
                || "locality".equalsIgnoreCase(resultType)
                || "city".equalsIgnoreCase(resultType)
                || "town".equalsIgnoreCase(resultType)) {
            if (city != null && !city.isBlank()) {
                name = city.trim();
            } else if (district != null && !district.isBlank()) {
                name = district.trim();
            }
        }
        String formattedAddress = label != null && !label.isBlank() ? label.trim() : name;

        JsonNode pos = node.path("position");
        double lat = pos.path("lat").asDouble(Double.NaN);
        double lon = pos.path("lng").asDouble(Double.NaN);

        if (!Double.isFinite(lat) || !Double.isFinite(lon)
                || lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
            return null;
        }

        String category = resultType;
        if (node.has("categories") && node.path("categories").isArray() && !node.path("categories").isEmpty()) {
            category = node.path("categories").get(0).path("name").asText(resultType);
        }

        Double scoring = null;
        if (node.has("scoring") && node.path("scoring").has("queryScore")) {
            scoring = node.path("scoring").path("queryScore").asDouble(0.5);
        }

        List<Double> boundingBox = null;
        if (node.has("mapView")) {
            JsonNode mv = node.path("mapView");
            double south = mv.path("south").asDouble(Double.NaN);
            double north = mv.path("north").asDouble(Double.NaN);
            double west = mv.path("west").asDouble(Double.NaN);
            double east = mv.path("east").asDouble(Double.NaN);
            if (Double.isFinite(south) && Double.isFinite(north) && Double.isFinite(west) && Double.isFinite(east)) {
                boundingBox = List.of(south, north, west, east);
            }
        }

        return LocationSearchResultResponse.builder()
                .placeId(id)
                .name(name)
                .formattedAddress(formattedAddress)
                .latitude(lat)
                .longitude(lon)
                .category(category)
                .type(resultType)
                .importance(scoring)
                .boundingBox(boundingBox)
                .provider(PROVIDER_NAME)
                .build();
    }
}
