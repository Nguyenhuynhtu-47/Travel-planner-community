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
import java.util.List;

@Component
public class LocationIqGeocodingProvider implements GeocodingProvider {

    private static final Logger logger = LoggerFactory.getLogger(LocationIqGeocodingProvider.class);
    private static final String PROVIDER_NAME = "LOCATION_IQ";

    private final RestClient restClient;
    private final MapProperties mapProperties;

    @Autowired
    public LocationIqGeocodingProvider(RestClient.Builder restClientBuilder, MapProperties mapProperties) {
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

    public LocationIqGeocodingProvider(RestClient restClient, MapProperties mapProperties) {
        this.restClient = restClient;
        this.mapProperties = mapProperties;
    }

    @Override
    public String getProviderName() {
        return PROVIDER_NAME;
    }

    @Override
    public boolean isConfigured() {
        String apiKey = mapProperties.getGeocoding().getApiKey();
        return apiKey != null && !apiKey.trim().isEmpty();
    }

    @Override
    public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {
        if (!isConfigured()) {
            logger.debug("LocationIQ API key is not configured. Returning empty search results for query: {}", query);
            return Collections.emptyList();
        }

        String apiKey = mapProperties.getGeocoding().getApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://us1.locationiq.com/v1";
        }

        UriComponentsBuilder uriBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/autocomplete")
                .queryParam("key", apiKey)
                .queryParam("q", query)
                .queryParam("limit", limit)
                .queryParam("countrycodes", "vn")
                .queryParam("format", "json")
                .queryParam("accept-language", "vi,en");

        if (latitude != null && longitude != null) {
            uriBuilder.queryParam("lat", latitude);
            uriBuilder.queryParam("lon", longitude);
        }

        URI uri = uriBuilder.build().encode().toUri();

        try {
            JsonNode response = restClient.get()
                    .uri(uri)
                    .retrieve()
                    .body(JsonNode.class);

            if (response == null || !response.isArray()) {
                return Collections.emptyList();
            }

            List<LocationSearchResultResponse> results = new ArrayList<>();
            for (JsonNode item : response) {
                LocationSearchResultResponse parsed = parseLocationItem(item);
                if (parsed != null) {
                    results.add(parsed);
                }
            }
            return results;

        } catch (RestClientResponseException ex) {
            // LocationIQ returns HTTP 404 when no places match the query (genuine empty result)
            if (ex.getStatusCode() == HttpStatus.NOT_FOUND) {
                logger.debug("LocationIQ returned 404 (no places found) for query: {}", query);
                return Collections.emptyList();
            }
            // LocationIQ returns HTTP 429 when upstream daily/per-second quota is exceeded
            if (ex.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                logger.warn("LocationIQ upstream rate limit exceeded (HTTP 429) for query: {}", query);
                throw new RateLimitExceededException("Dịch vụ tìm kiếm vị trí tạm thời đạt giới hạn lượt gọi. Vui lòng thử lại sau.");
            }
            // Server error from upstream
            if (ex.getStatusCode().is5xxServerError()) {
                logger.warn("LocationIQ upstream server error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
                throw new AppException("Dịch vụ định vị gặp sự cố máy chủ. Vui lòng thử lại sau.", HttpStatus.BAD_GATEWAY);
            }
            logger.warn("LocationIQ upstream error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
            return Collections.emptyList();
        } catch (ResourceAccessException ex) {
            logger.warn("LocationIQ upstream timeout or connection error for query: {}", query);
            throw new AppException("Dịch vụ tìm kiếm vị trí không phản hồi kịp thời (timeout). Vui lòng thử lại sau.", HttpStatus.GATEWAY_TIMEOUT);
        } catch (AppException ex) {
            throw ex;
        } catch (Exception ex) {
            logger.warn("Unexpected error calling LocationIQ search: {}", ex.getMessage());
            throw new AppException("Không thể xử lý yêu cầu tìm kiếm vị trí.", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @Override
    public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {
        if (!isConfigured()) {
            logger.debug("LocationIQ API key is not configured. Returning null for reverse geocode.");
            return null;
        }

        String apiKey = mapProperties.getGeocoding().getApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://us1.locationiq.com/v1";
        }

        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/reverse")
                .queryParam("key", apiKey)
                .queryParam("lat", latitude)
                .queryParam("lon", longitude)
                .queryParam("format", "json")
                .queryParam("accept-language", "vi,en")
                .build().encode().toUri();

        try {
            JsonNode response = restClient.get()
                    .uri(uri)
                    .retrieve()
                    .body(JsonNode.class);

            if (response == null || response.isMissingNode() || response.isNull()) {
                return null;
            }

            return parseLocationItem(response);

        } catch (RestClientResponseException ex) {
            // LocationIQ returns 404 when coordinates do not resolve to an address (genuine unmapped coordinate)
            if (ex.getStatusCode() == HttpStatus.NOT_FOUND) {
                logger.debug("LocationIQ returned 404 (no address at coordinates {}, {})", latitude, longitude);
                return null;
            }
            if (ex.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                logger.warn("LocationIQ upstream rate limit exceeded (HTTP 429) for reverse geocode ({}, {})", latitude, longitude);
                throw new RateLimitExceededException("Dịch vụ định vị tạm thời đạt giới hạn lượt gọi. Vui lòng thử lại sau.");
            }
            if (ex.getStatusCode().is5xxServerError()) {
                logger.warn("LocationIQ upstream server error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
                throw new AppException("Dịch vụ định vị gặp sự cố máy chủ. Vui lòng thử lại sau.", HttpStatus.BAD_GATEWAY);
            }
            logger.warn("LocationIQ upstream error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
            return null;
        } catch (ResourceAccessException ex) {
            logger.warn("LocationIQ upstream timeout or connection error for reverse geocode ({}, {})", latitude, longitude);
            throw new AppException("Dịch vụ định vị không phản hồi kịp thời (timeout). Vui lòng thử lại sau.", HttpStatus.GATEWAY_TIMEOUT);
        } catch (AppException ex) {
            throw ex;
        } catch (Exception ex) {
            logger.warn("Unexpected error calling LocationIQ reverse geocode: {}", ex.getMessage());
            throw new AppException("Không thể xử lý yêu cầu định vị tọa độ.", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private LocationSearchResultResponse parseLocationItem(JsonNode node) {
        if (node == null || node.isMissingNode()) {
            return null;
        }

        String osmType = node.path("osm_type").asText(null);
        String osmId = node.path("osm_id").asText(null);
        String placeId = node.path("place_id").asText(null);

        String effectivePlaceId;
        if (osmType != null && !osmType.isBlank() && osmId != null && !osmId.isBlank()) {
            effectivePlaceId = "osm_" + osmType.trim() + "_" + osmId.trim();
        } else if (placeId != null && !placeId.isBlank()) {
            effectivePlaceId = placeId.trim();
        } else {
            effectivePlaceId = "loc_" + System.currentTimeMillis();
        }

        String displayName = node.path("display_name").asText(null);
        String displayPlace = node.path("display_place").asText(null);
        String addressName = node.path("address").path("name").asText(null);

        String name;
        if (displayPlace != null && !displayPlace.isBlank()) {
            name = displayPlace.trim();
        } else if (addressName != null && !addressName.isBlank()) {
            name = addressName.trim();
        } else if (displayName != null && !displayName.isBlank()) {
            name = displayName.split(",")[0].trim();
        } else {
            name = "Vị trí đã chọn";
        }

        String formattedAddress = displayName != null && !displayName.isBlank() ? displayName.trim() : name;

        double lat = node.path("lat").asDouble(0.0);
        double lon = node.path("lon").asDouble(0.0);

        String category = node.path("class").asText(null);
        if (category == null || category.isBlank()) {
            category = node.path("type").asText("place");
        }

        return LocationSearchResultResponse.builder()
                .placeId(effectivePlaceId)
                .name(name)
                .formattedAddress(formattedAddress)
                .latitude(lat)
                .longitude(lon)
                .category(category)
                .provider(PROVIDER_NAME)
                .build();
    }
}
