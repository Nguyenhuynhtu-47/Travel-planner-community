package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.RouteResponse;
import Travel_Planner.Travel_Planner.dto.response.RouteWaypointResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.RoutingProviderException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ActivityRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryDayRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.service.RouteService;
import Travel_Planner.Travel_Planner.service.RoutingProvider;
import Travel_Planner.Travel_Planner.util.HaversineUtil;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.*;

/**
 * Implementation of {@link RouteService}.
 * Calculates per-day travel routes between activities, backed by Caffeine caching
 * and automatic Haversine straight-line fallback.
 */
@Service
public class RouteServiceImpl implements RouteService {

    private static final Logger logger = LoggerFactory.getLogger(RouteServiceImpl.class);

    private static final String CACHE_VERSION = "v1";
    private static final String DEFAULT_PROVIDER_KEY = "ors";
    private static final String EMPTY_OPTIONS_HASH = sha256Hex("");

    private final ItineraryRepository itineraryRepository;
    private final ItineraryDayRepository itineraryDayRepository;
    private final ActivityRepository activityRepository;
    private final RoutingProvider routingProvider;
    private final MapProperties mapProperties;

    // Caffeine in-memory cache: max 500 entries, 12-hour TTL.
    // Strictly caches normalized provider calculation output (CachedRouteResult), NEVER domain entities.
    private final Cache<String, CachedRouteResult> routeCache;

    public RouteServiceImpl(
            ItineraryRepository itineraryRepository,
            ItineraryDayRepository itineraryDayRepository,
            ActivityRepository activityRepository,
            RoutingProvider routingProvider,
            MapProperties mapProperties
    ) {
        this.itineraryRepository = itineraryRepository;
        this.itineraryDayRepository = itineraryDayRepository;
        this.activityRepository = activityRepository;
        this.routingProvider = routingProvider;
        this.mapProperties = mapProperties;
        this.routeCache = Caffeine.newBuilder()
                .maximumSize(500)
                .expireAfterWrite(Duration.ofHours(12))
                .build();
    }

    public Cache<String, CachedRouteResult> getRouteCache() {
        return routeCache;
    }

    @Override
    @Transactional(readOnly = true)
    public RouteResponse calculateDayRoute(Integer itineraryId, Integer dayId, String mode, String currentUsername) {
        if (itineraryId == null || dayId == null) {
            throw new BadRequestException("Mã lịch trình và mã ngày không được để trống");
        }

        if (currentUsername == null || currentUsername.isBlank()) {
            throw new UnauthorizedException("Vui lòng đăng nhập để xem thông tin lộ trình");
        }

        // 1. Normalize and validate mode
        String normalizedMode = normalizeAndValidateMode(mode);

        // 2. Validate itinerary status, authorization, and ownership (prevents ID enumeration)
        Itinerary itinerary = itineraryRepository.findByIdWithUser(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa"));

        if (itinerary.getStatus() == ItineraryStatus.DELETED ||
                (itinerary.getUser() != null && itinerary.getUser().getStatus() != UserStatus.ACTIVE)) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        boolean isOwner = itinerary.getUser() != null && currentUsername.equals(itinerary.getUser().getUsername());

        if (itinerary.getStatus() != ItineraryStatus.ACTIVE && !isOwner) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        if (itinerary.getVisibility() != Visibility.PUBLIC && !isOwner) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        // 3. Validate that dayId belongs to itineraryId
        ItineraryDay day = itineraryDayRepository.findByDayIdAndItinerary_ItineraryId(dayId, itineraryId)
                .orElseThrow(() -> new BadRequestException("Ngày không thuộc lịch trình này"));

        // 4. Retrieve current activities in actual display order directly from MySQL
        List<Activity> activities = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(dayId);

        // 5. Extract only activities with valid coordinates and assemble waypoints
        List<RouteWaypointResponse> validWaypointResponses = new ArrayList<>();
        List<WaypointCoordinate> coordinates = new ArrayList<>();

        for (Activity activity : activities) {
            BigDecimal lat = activity.getLatitude();
            BigDecimal lon = activity.getLongitude();
            String locationName = activity.getLocationName() != null
                    ? activity.getLocationName()
                    : (activity.getCustomLocationName() != null ? activity.getCustomLocationName() : activity.getName());

            if (isValidCoordinate(lat, lon)) {
                validWaypointResponses.add(RouteWaypointResponse.builder()
                        .activityId(activity.getActivityId())
                        .name(activity.getName())
                        .locationName(locationName)
                        .latitude(lat)
                        .longitude(lon)
                        .displayOrder(activity.getDisplayOrder())
                        .build());
                coordinates.add(new WaypointCoordinate(lat.doubleValue(), lon.doubleValue()));
            }
        }

        int maxWaypoints = mapProperties.getRouting().getMaxWaypoints();
        if (maxWaypoints <= 0) {
            maxWaypoints = 50;
        }
        if (coordinates.size() > maxWaypoints) {
            throw new BadRequestException("Số lượng điểm dừng (" + coordinates.size() + ") vượt quá giới hạn tối đa cho phép (" + maxWaypoints + ")");
        }

        // 6. Handle case of fewer than 2 valid waypoints
        if (coordinates.size() < 2) {
            return RouteResponse.builder()
                    .itineraryId(itineraryId)
                    .dayId(dayId)
                    .status("INSUFFICIENT_WAYPOINTS")
                    .routeType("NONE")
                    .mode(normalizedMode)
                    .totalDistanceMeters(null)
                    .directDistanceMeters(null)
                    .totalDurationSeconds(null)
                    .waypoints(validWaypointResponses)
                    .geometryCoordinates(Collections.emptyList())
                    .build();
        }

        // 7. Calculate direct straight-line distance via Haversine
        double directDistanceMeters = HaversineUtil.calculateTotalDirectDistanceMeters(coordinates);

        // 8. Build deterministic composite cache key
        String cacheKey = buildRouteCacheKey(normalizedMode, coordinates);

        // 9. Check Caffeine cache
        CachedRouteResult cachedResult = routeCache.getIfPresent(cacheKey);
        if (cachedResult != null) {
            logger.debug("Route cache HIT for key: {}", cacheKey);
            return RouteResponse.builder()
                    .itineraryId(itineraryId)
                    .dayId(dayId)
                    .status("SUCCESS")
                    .routeType(cachedResult.routeType())
                    .mode(normalizedMode)
                    .totalDistanceMeters(cachedResult.totalDistanceMeters())
                    .directDistanceMeters(cachedResult.directDistanceMeters())
                    .totalDurationSeconds(cachedResult.totalDurationSeconds())
                    .waypoints(validWaypointResponses)
                    .geometryCoordinates(cachedResult.geometryCoordinates())
                    .build();
        }

        logger.debug("Route cache MISS for key: {}. Requesting provider: {}", cacheKey, routingProvider.getProviderName());

        // 10. Call external routing provider (with Haversine fallback on failure/timeout)
        try {
            CachedRouteResult providerResult = routingProvider.calculateRoute(normalizedMode, coordinates);

            if (providerResult != null && "ACTUAL_ROAD".equals(providerResult.routeType())) {
                // Cache ONLY successful road route results
                routeCache.put(cacheKey, providerResult);

                return RouteResponse.builder()
                        .itineraryId(itineraryId)
                        .dayId(dayId)
                        .status("SUCCESS")
                        .routeType(providerResult.routeType())
                        .mode(normalizedMode)
                        .totalDistanceMeters(providerResult.totalDistanceMeters())
                        .directDistanceMeters(providerResult.directDistanceMeters())
                        .totalDurationSeconds(providerResult.totalDurationSeconds())
                        .waypoints(validWaypointResponses)
                        .geometryCoordinates(providerResult.geometryCoordinates())
                        .build();
            }
        } catch (RoutingProviderException ex) {
            logger.warn("Routing provider failed: {} (status: {}). Engaging Haversine fallback.", ex.getMessage(), ex.getStatus());
        } catch (Exception ex) {
            logger.warn("Unexpected routing provider failure: {}. Engaging Haversine fallback.", ex.getMessage());
        }

        // 11. Haversine Straight-Line Fallback (never cached)
        // Strictly return empty geometry: Haversine is only an indicative distance estimate, not a route
        return RouteResponse.builder()
                .itineraryId(itineraryId)
                .dayId(dayId)
                .status("FALLBACK")
                .routeType("ESTIMATED_INDICATIVE")
                .mode(normalizedMode)
                .totalDistanceMeters(null) // Strictly null: Haversine is NOT road distance
                .directDistanceMeters(directDistanceMeters)
                .totalDurationSeconds(null) // Never invent travel time for straight lines
                .waypoints(validWaypointResponses)
                .geometryCoordinates(Collections.emptyList())
                .build();
    }

    private String normalizeAndValidateMode(String mode) {
        if (mode == null || mode.isBlank() || mode.equalsIgnoreCase("driving")) {
            return "driving";
        }
        if (mode.equalsIgnoreCase("walking")) {
            return "walking";
        }
        throw new BadRequestException("Phương thức di chuyển không được hỗ trợ: " + mode);
    }

    private boolean isValidCoordinate(BigDecimal lat, BigDecimal lon) {
        if (lat == null || lon == null) return false;
        double dLat = lat.doubleValue();
        double dLon = lon.doubleValue();
        if (Double.isNaN(dLat) || Double.isInfinite(dLat) || Double.isNaN(dLon) || Double.isInfinite(dLon)) {
            return false;
        }
        return dLat >= -90.0 && dLat <= 90.0 && dLon >= -180.0 && dLon <= 180.0;
    }

    public static String buildRouteCacheKey(String mode, List<WaypointCoordinate> coordinates) {
        String profile = OpenRouteServiceRoutingProvider.mapModeToProfile(mode);

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < coordinates.size(); i++) {
            if (i > 0) sb.append(';');
            WaypointCoordinate coord = coordinates.get(i);
            sb.append(String.format(Locale.US, "%.5f,%.5f", coord.latitude(), coord.longitude()));
        }

        String waypointsCoordsHash = sha256Hex(sb.toString());

        return String.format(Locale.US, "route:%s:%s:%s:%s:%s",
                CACHE_VERSION,
                DEFAULT_PROVIDER_KEY,
                profile,
                EMPTY_OPTIONS_HASH,
                waypointsCoordsHash
        );
    }

    public static String sha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm not available", e);
        }
    }
}

