package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.RoutingProviderException;
import Travel_Planner.Travel_Planner.model.CachedRouteResult;
import Travel_Planner.Travel_Planner.model.WaypointCoordinate;
import Travel_Planner.Travel_Planner.service.RoutingProvider;
import Travel_Planner.Travel_Planner.util.HaversineUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * OpenRouteService implementation of {@link RoutingProvider}.
 * Calls the OpenRouteService Directions v2 GeoJSON endpoint.
 */
@Component
public class OpenRouteServiceRoutingProvider implements RoutingProvider {

    private static final Logger logger = LoggerFactory.getLogger(OpenRouteServiceRoutingProvider.class);
    private static final String PROVIDER_NAME = "OPEN_ROUTE_SERVICE";

    private final RestClient restClient;
    private final MapProperties mapProperties;

    @Autowired
    public OpenRouteServiceRoutingProvider(RestClient.Builder restClientBuilder, MapProperties mapProperties) {
        this.mapProperties = mapProperties;
        int timeoutMs = mapProperties.getRouting().getTimeoutMs();
        if (timeoutMs <= 0) {
            timeoutMs = 4000;
        }

        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(Duration.ofMillis(timeoutMs));
        requestFactory.setReadTimeout(Duration.ofMillis(timeoutMs));

        this.restClient = restClientBuilder
                .requestFactory(requestFactory)
                .build();
    }

    public OpenRouteServiceRoutingProvider(RestClient restClient, MapProperties mapProperties) {
        this.restClient = restClient;
        this.mapProperties = mapProperties;
    }

    @Override
    public String getProviderName() {
        return PROVIDER_NAME;
    }

    @Override
    public boolean isConfigured() {
        String apiKey = mapProperties.getRouting().getApiKey();
        return apiKey != null && !apiKey.trim().isEmpty();
    }

    public static String mapModeToProfile(String mode) {
        if (mode == null || mode.isBlank() || mode.equalsIgnoreCase("driving")) {
            return "driving-car";
        }
        if (mode.equalsIgnoreCase("walking")) {
            return "foot-walking";
        }
        throw new BadRequestException("Phương thức di chuyển không được hỗ trợ: " + mode);
    }

    @Override
    public CachedRouteResult calculateRoute(String mode, List<WaypointCoordinate> waypoints) {
        if (!isConfigured()) {
            logger.debug("OpenRouteService API key is not configured");
            throw new RoutingProviderException("OpenRouteService API key chưa được cấu hình", HttpStatus.SERVICE_UNAVAILABLE, false, false);
        }

        if (waypoints == null || waypoints.size() < 2) {
            throw new BadRequestException("Cần ít nhất 2 điểm dừng có tọa độ để tính toán tuyến đường");
        }

        int maxWaypoints = mapProperties.getRouting().getMaxWaypoints();
        if (maxWaypoints <= 0) {
            maxWaypoints = 50;
        }
        if (waypoints.size() > maxWaypoints) {
            throw new BadRequestException("Số lượng điểm dừng (" + waypoints.size() + ") vượt quá giới hạn tối đa cho phép (" + maxWaypoints + ")");
        }

        String profile = mapModeToProfile(mode);
        String apiKey = mapProperties.getRouting().getApiKey().trim();
        String baseUrl = mapProperties.getRouting().getBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://api.openrouteservice.org";
        }

        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/v2/directions/{profile}/geojson")
                .buildAndExpand(profile)
                .encode()
                .toUri();

        // Coordinates format for ORS: [[lon1, lat1], [lon2, lat2], ...]
        List<List<Double>> coordinatesList = waypoints.stream()
                .map(wp -> List.of(wp.longitude(), wp.latitude()))
                .toList();

        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("coordinates", coordinatesList);
        requestBody.put("instructions", false);
        requestBody.put("geometry", true);

        try {
            JsonNode root = restClient.post()
                    .uri(uri)
                    .header("Authorization", apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON, MediaType.parseMediaType("application/geo+json"))
                    .body(requestBody)
                    .retrieve()
                    .body(JsonNode.class);

            if (root == null) {
                throw new RoutingProviderException("Phản hồi rỗng từ dịch vụ định tuyến", HttpStatus.BAD_GATEWAY, false, false);
            }

            JsonNode features = root.path("features");
            if (!features.isArray() || features.isEmpty()) {
                throw new RoutingProviderException("Không tìm thấy dữ liệu tuyến đường trong phản hồi từ dịch vụ", HttpStatus.NOT_FOUND, false, false);
            }

            JsonNode feature = features.get(0);
            JsonNode coordsNode = feature.path("geometry").path("coordinates");
            if (!coordsNode.isArray() || coordsNode.isEmpty()) {
                throw new RoutingProviderException("Dữ liệu tọa độ tuyến đường không hợp lệ từ dịch vụ", HttpStatus.UNPROCESSABLE_ENTITY, false, false);
            }

            List<List<Double>> geometryCoordinates = new ArrayList<>();
            for (JsonNode pointNode : coordsNode) {
                if (pointNode.isArray() && pointNode.size() >= 2) {
                    double lon = pointNode.get(0).asDouble();
                    double lat = pointNode.get(1).asDouble();
                    geometryCoordinates.add(List.of(lon, lat));
                }
            }

            JsonNode summary = feature.path("properties").path("summary");
            Double distance = summary.has("distance") ? summary.get("distance").asDouble() : null;
            Double duration = summary.has("duration") ? summary.get("duration").asDouble() : null;

            double directDistance = HaversineUtil.calculateTotalDirectDistanceMeters(waypoints);

            return new CachedRouteResult(
                    "ACTUAL_ROAD",
                    PROVIDER_NAME,
                    distance,
                    directDistance,
                    duration,
                    geometryCoordinates
            );

        } catch (RestClientResponseException ex) {
            int statusCode = ex.getStatusCode().value();
            if (statusCode == 429) {
                logger.warn("OpenRouteService rate limit exceeded (HTTP 429)");
                throw new RoutingProviderException("Vượt quá giới hạn lượt gọi đến dịch vụ định tuyến", HttpStatus.TOO_MANY_REQUESTS, false, true);
            }
            if (statusCode == 400 || statusCode == 404) {
                logger.warn("OpenRouteService returned HTTP {}: {}", statusCode, ex.getStatusText());
                throw new RoutingProviderException("Không tìm thấy đường đi phù hợp giữa các điểm đã chọn", HttpStatus.valueOf(statusCode), false, false);
            }
            if (statusCode == 401 || statusCode == 403) {
                logger.error("OpenRouteService authentication error HTTP {}", statusCode);
                throw new RoutingProviderException("Lỗi cấu hình xác thực dịch vụ định tuyến", HttpStatus.valueOf(statusCode), false, false);
            }
            logger.warn("OpenRouteService server error HTTP {}: {}", statusCode, ex.getStatusText());
            throw new RoutingProviderException("Dịch vụ định tuyến gặp sự cố máy chủ", HttpStatus.valueOf(statusCode), false, false);
        } catch (ResourceAccessException ex) {
            logger.warn("OpenRouteService upstream timeout or connection failure");
            throw new RoutingProviderException("Hết thời gian chờ kết nối dịch vụ định tuyến (timeout)", HttpStatus.GATEWAY_TIMEOUT, true, false);
        } catch (RoutingProviderException ex) {
            throw ex;
        } catch (Exception ex) {
            logger.warn("Unexpected error calling OpenRouteService: {}", ex.getMessage());
            throw new RoutingProviderException("Lỗi xử lý kết quả từ dịch vụ định tuyến: " + ex.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR, false, false);
        }
    }
}

