package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.location.GeographicTargetArea;
import Travel_Planner.Travel_Planner.dto.location.ParsedLocationQuery;
import Travel_Planner.Travel_Planner.dto.location.SearchIntent;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.service.GeocodingProvider;
import Travel_Planner.Travel_Planner.service.GeographicFilterService;
import Travel_Planner.Travel_Planner.service.LocationRankingService;
import Travel_Planner.Travel_Planner.service.LocationService;
import Travel_Planner.Travel_Planner.service.QueryUnderstandingService;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
public class LocationServiceImpl implements LocationService {

    private static final Logger logger = LoggerFactory.getLogger(LocationServiceImpl.class);

    private static final double MIN_LATITUDE = -90.0;
    private static final double MAX_LATITUDE = 90.0;
    private static final double MIN_LONGITUDE = -180.0;
    private static final double MAX_LONGITUDE = 180.0;

    private static final int DEFAULT_LIMIT = 10;
    private static final int MAX_LIMIT = 20;

    // In-memory Caffeine caches: max 500 entries, 24-hour TTL (strictly adhering to LocationIQ <= 48h restriction)
    private final Cache<String, List<LocationSearchResultResponse>> searchCache = Caffeine.newBuilder()
            .maximumSize(500)
            .expireAfterWrite(Duration.ofHours(24))
            .build();

    private final Cache<String, LocationSearchResultResponse> reverseCache = Caffeine.newBuilder()
            .maximumSize(500)
            .expireAfterWrite(Duration.ofHours(24))
            .build();
    private final Cache<String, List<LocationSearchResultResponse>> nearbyCache = Caffeine.newBuilder()
            .maximumSize(500)
            .expireAfterWrite(Duration.ofHours(24))
            .build();

    private final GeocodingProvider primaryProvider;
    private final HereGeocodingProvider hereGeocodingProvider;
    private final LocationRankingService locationRankingService;
    private final QueryUnderstandingService queryUnderstandingService;
    private final GeographicFilterService geographicFilterService;
    private final TomTomPlacesProvider tomTomProvider;

    @Autowired
    public LocationServiceImpl(
            LocationIqGeocodingProvider locationIqProvider,
            HereGeocodingProvider hereGeocodingProvider,
            LocationRankingService locationRankingService,
            QueryUnderstandingService queryUnderstandingService,
            GeographicFilterService geographicFilterService,
            TomTomPlacesProvider tomTomProvider) {
        this.primaryProvider = locationIqProvider;
        this.hereGeocodingProvider = hereGeocodingProvider;
        this.locationRankingService = locationRankingService;
        this.queryUnderstandingService = queryUnderstandingService;
        this.geographicFilterService = geographicFilterService;
        this.tomTomProvider = tomTomProvider;
    }

    public LocationServiceImpl(GeocodingProvider geocodingProvider) {
        this.primaryProvider = geocodingProvider;
        this.hereGeocodingProvider = null;
        this.locationRankingService = new LocationRankingServiceImpl();
        this.queryUnderstandingService = new QueryUnderstandingServiceImpl();
        this.geographicFilterService = new GeographicFilterServiceImpl();
        this.tomTomProvider = null;
    }

    public LocationServiceImpl(GeocodingProvider geocodingProvider, LocationRankingService locationRankingService) {
        this.primaryProvider = geocodingProvider;
        this.hereGeocodingProvider = null;
        this.locationRankingService = locationRankingService;
        this.queryUnderstandingService = new QueryUnderstandingServiceImpl();
        this.geographicFilterService = new GeographicFilterServiceImpl();
        this.tomTomProvider = null;
    }

    public LocationServiceImpl(
            GeocodingProvider primaryProvider,
            HereGeocodingProvider hereGeocodingProvider,
            LocationRankingService locationRankingService,
            QueryUnderstandingService queryUnderstandingService,
            GeographicFilterService geographicFilterService) {
        this.primaryProvider = primaryProvider;
        this.hereGeocodingProvider = hereGeocodingProvider;
        this.locationRankingService = locationRankingService;
        this.queryUnderstandingService = queryUnderstandingService;
        this.geographicFilterService = geographicFilterService;
        this.tomTomProvider = null;
    }

    @Override
    public List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude) {
        return searchLocations(query, limit, latitude, longitude, "LOCATION_IQ", null);
    }

    /** Unified client entry point. Provider choice is server configuration; client geo-bias is intentionally ignored. */
    @Override
    public List<LocationSearchResultResponse> searchLocationsUnified(String query, Integer limit, String mode, String sessionId) {
        String normalizedMode = mode == null ? "SUGGEST" : mode.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("SUGGEST", "SEARCH").contains(normalizedMode)) {
            throw new BadRequestException("Chế độ tìm kiếm địa điểm không hợp lệ");
        }
        if (tomTomProvider != null && tomTomProvider.isEnabled()) {
            String trimmed = query == null ? "" : query.trim();
            int resultLimit = limit == null ? DEFAULT_LIMIT : limit;
            if (trimmed.length() < 2 || trimmed.length() > 100) throw new BadRequestException("Từ khóa tìm kiếm phải có từ 2 đến 100 ký tự");
            if (resultLimit < 1 || resultLimit > MAX_LIMIT) throw new BadRequestException("Số lượng kết quả (limit) phải từ 1 đến " + MAX_LIMIT);
            return "SEARCH".equals(normalizedMode)
                    ? tomTomProvider.discover(trimmed, null, null, null, sessionId)
                    : tomTomProvider.suggest(trimmed, resultLimit, null, null, sessionId);
        }
        return searchLocations(query, limit, (Double) null, (Double) null, "LOCATION_IQ", sessionId);
    }

    @Override
    public List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude, String provider, String sessionId) {
        if ("TOMTOM".equalsIgnoreCase(provider)) {
            if (tomTomProvider == null || !tomTomProvider.isEnabled()) throw new AppException("Tìm kiếm TomTom chưa được bật trên máy chủ", org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE);
            String trimmedQuery = query == null ? "" : query.trim();
            if (trimmedQuery.length() < 2 || trimmedQuery.length() > 100) throw new BadRequestException("Từ khóa tìm kiếm phải có từ 2 đến 100 ký tự");
            int resultLimit = limit == null ? DEFAULT_LIMIT : limit;
            if (resultLimit < 1 || resultLimit > MAX_LIMIT) throw new BadRequestException("Số lượng kết quả (limit) phải từ 1 đến " + MAX_LIMIT);
            validateOptionalCoordinates(latitude, longitude);
            return tomTomProvider.suggest(trimmedQuery, resultLimit, latitude, longitude, sessionId);
        }
        if (query == null || query.isBlank()) {
            throw new BadRequestException("Từ khóa tìm kiếm không được để trống");
        }

        String trimmed = query.trim();
        if (trimmed.length() < 2 || trimmed.length() > 100) {
            throw new BadRequestException("Từ khóa tìm kiếm phải có từ 2 đến 100 ký tự");
        }

        int effectiveLimit = limit != null ? limit : DEFAULT_LIMIT;
        if (effectiveLimit < 1 || effectiveLimit > MAX_LIMIT) {
            throw new BadRequestException("Số lượng kết quả (limit) phải từ 1 đến " + MAX_LIMIT);
        }

        Double normalizedLat = null;
        if (latitude != null) {
            if (latitude < MIN_LATITUDE || latitude > MAX_LATITUDE) {
                throw new BadRequestException("Tọa độ vĩ độ (latitude) phải nằm trong khoảng từ -90.0 đến 90.0");
            }
            normalizedLat = BigDecimal.valueOf(latitude).setScale(5, RoundingMode.HALF_UP).doubleValue();
        }

        Double normalizedLon = null;
        if (longitude != null) {
            if (longitude < MIN_LONGITUDE || longitude > MAX_LONGITUDE) {
                throw new BadRequestException("Tọa độ kinh độ (longitude) phải nằm trong khoảng từ -180.0 đến 180.0");
            }
            normalizedLon = BigDecimal.valueOf(longitude).setScale(5, RoundingMode.HALF_UP).doubleValue();
        }

        String cacheKey = buildSearchCacheKey(trimmed, effectiveLimit, normalizedLat, normalizedLon);
        List<LocationSearchResultResponse> cached = searchCache.getIfPresent(cacheKey);
        if (cached != null) {
            logger.debug("Location search cache HIT for key: {}", cacheKey);
            return cached;
        }

        logger.debug("Location search cache MISS for key: {}. Parsing query understanding", cacheKey);
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery(trimmed);
        int fetchLimit = Math.min(effectiveLimit * 2, 20);
        List<LocationSearchResultResponse> results;

        // Two-Stage Search: Query has explicit target area and POI search intent
        if (parsed.hasExplicitLocation() && parsed.getSearchIntent() == SearchIntent.POI_IN_LOCATION) {
            logger.debug("Executing Two-Stage Search for keyword='{}', location='{}'",
                    parsed.getSearchKeyword(), parsed.getLocationQuery());

            GeographicTargetArea targetArea = resolveTargetArea(parsed.getLocationQuery());
            if (targetArea != null) {
                List<LocationSearchResultResponse> rawCandidates = new ArrayList<>();
                int radiusMeters = (int) (targetArea.getMaxRadiusKm() * 1000);

                // Stage B.1: Primary search bounded inside target area
                try {
                    List<LocationSearchResultResponse> inArea = primaryProvider.searchInArea(
                            parsed.getSearchKeyword(), fetchLimit, targetArea.getCenterLat(), targetArea.getCenterLon(),
                            targetArea.getBoundingBox(), radiusMeters);
                    if (inArea != null) {
                        rawCandidates.addAll(inArea);
                    }
                } catch (Exception ex) {
                    logger.debug("Primary searchInArea error: {}", ex.getMessage());
                }

                // Stage B.2: Root keyword fallback if candidate list is sparse and keyword is multi-word
                if (rawCandidates.size() < 2 && parsed.getSearchKeyword().contains(" ")) {
                    String rootWord = parsed.getSearchKeyword().split("\\s+")[0].trim();
                    if (rootWord.length() >= 3) {
                        try {
                            List<LocationSearchResultResponse> rootResults = primaryProvider.searchInArea(
                                    rootWord, fetchLimit, targetArea.getCenterLat(), targetArea.getCenterLon(),
                                    targetArea.getBoundingBox(), radiusMeters);
                            if (rootResults != null) {
                                rawCandidates.addAll(rootResults);
                            }
                        } catch (Exception ex) {
                            logger.debug("Primary root word searchInArea error: {}", ex.getMessage());
                        }
                    }
                }

                // Stage B.3: If candidate list is still sparse (< 2) and intent is FOOD, try generic food fallback in area
                if (rawCandidates.size() < 2 && "FOOD".equalsIgnoreCase(parsed.getPlaceCategory())) {
                    try {
                        List<LocationSearchResultResponse> foodFallbacks = primaryProvider.searchInArea(
                                "quán ăn", fetchLimit, targetArea.getCenterLat(), targetArea.getCenterLon(),
                                targetArea.getBoundingBox(), radiusMeters);
                        if (foodFallbacks != null) {
                            rawCandidates.addAll(foodFallbacks);
                        }
                    } catch (Exception ex) {
                        logger.debug("Primary food fallback searchInArea error: {}", ex.getMessage());
                    }
                }

                // Stage B.4: Combined search (keyword + location) biased to target coordinates
                try {
                    List<LocationSearchResultResponse> combined = primaryProvider.search(
                            parsed.getSearchKeyword() + " " + parsed.getLocationQuery(),
                            fetchLimit, targetArea.getCenterLat(), targetArea.getCenterLon());
                    if (combined != null) {
                        rawCandidates.addAll(combined);
                    }
                } catch (Exception ex) {
                    logger.debug("Primary combined search error: {}", ex.getMessage());
                }

                // Stage B.4: Secondary HERE provider search in area if configured
                if (hereGeocodingProvider != null && hereGeocodingProvider.isConfigured()) {
                    try {
                        List<LocationSearchResultResponse> hereResults = hereGeocodingProvider.searchInArea(
                                parsed.getSearchKeyword(), fetchLimit, targetArea.getCenterLat(), targetArea.getCenterLon(),
                                targetArea.getBoundingBox(), radiusMeters);
                        if (hereResults != null) {
                            rawCandidates.addAll(hereResults);
                        }
                    } catch (Exception ex) {
                        logger.debug("HERE searchInArea error: {}", ex.getMessage());
                    }
                }

                // Stage B.5: Filter out incompatible commercial types if intent is FOOD
                if ("FOOD".equalsIgnoreCase(parsed.getPlaceCategory())) {
                    rawCandidates.removeIf(this::isIncompatibleFoodCandidate);
                }

                // Stage B.6: Strict Geographic Filtering
                List<LocationSearchResultResponse> filtered = geographicFilterService.filter(rawCandidates, targetArea);

                if (!filtered.isEmpty()) {
                    results = locationRankingService.rankAndDeduplicate(
                            trimmed,
                            filtered,
                            targetArea.getCenterLat(),
                            targetArea.getCenterLon(),
                            effectiveLimit
                    );
                } else {
                    // Safe Fallback: return the target locality itself so the map camera navigates to the requested region
                    // without exposing out-of-bounds cross-province false positives.
                    LocationSearchResultResponse localityFallback = LocationSearchResultResponse.builder()
                            .placeId("locality_" + System.currentTimeMillis())
                            .name(targetArea.getQueryName() + " (Khu vực)")
                            .formattedAddress(targetArea.getResolvedName())
                            .latitude(targetArea.getCenterLat())
                            .longitude(targetArea.getCenterLon())
                            .category("locality")
                            .type("locality")
                            .importance(1.0)
                            .boundingBox(targetArea.getBoundingBox())
                            .provider(primaryProvider.getProviderName())
                            .isLocalityFallback(true)
                            .build();
                    results = List.of(localityFallback);
                }
            } else {
                results = executeStandardSearch(trimmed, fetchLimit, effectiveLimit, normalizedLat, normalizedLon);
            }
        } else {
            results = executeStandardSearch(trimmed, fetchLimit, effectiveLimit, normalizedLat, normalizedLon);
        }

        // Cache results if at least one provider is configured
        if ((primaryProvider != null && primaryProvider.isConfigured())
                || (hereGeocodingProvider != null && hereGeocodingProvider.isConfigured())) {
            searchCache.put(cacheKey, results);
        }

        return results;
    }

    private List<LocationSearchResultResponse> executeStandardSearch(
            String query, int fetchLimit, int effectiveLimit, Double normalizedLat, Double normalizedLon) {
        List<LocationSearchResultResponse> rawResults = new ArrayList<>();

        // 1. Primary provider search (LocationIQ)
        try {
            List<LocationSearchResultResponse> primaryResults = primaryProvider.search(query, fetchLimit, normalizedLat, normalizedLon);
            if (primaryResults != null) {
                rawResults.addAll(primaryResults);
            }
        } catch (AppException ex) {
            if (hereGeocodingProvider == null || !hereGeocodingProvider.isConfigured()) {
                throw ex;
            }
            logger.warn("Primary geocoding provider failed, falling back to secondary: {}", ex.getMessage());
        }

        // 2. Secondary provider search (HERE) if configured
        if (hereGeocodingProvider != null && hereGeocodingProvider.isConfigured()) {
            try {
                List<LocationSearchResultResponse> hereResults = hereGeocodingProvider.search(query, fetchLimit, normalizedLat, normalizedLon);
                if (hereResults != null) {
                    rawResults.addAll(hereResults);
                }
            } catch (Exception ex) {
                logger.warn("HERE geocoding provider search error: {}", ex.getMessage());
            }
        }

        // 3. Semantic Ranking & Deduplication
        return locationRankingService.rankAndDeduplicate(
                query,
                rawResults,
                normalizedLat,
                normalizedLon,
                effectiveLimit
        );
    }

    private GeographicTargetArea resolveTargetArea(String locationQuery) {
        if (locationQuery == null || locationQuery.isBlank()) {
            return null;
        }

        try {
            List<LocationSearchResultResponse> locResults = primaryProvider.search(locationQuery, 3, null, null);
            if ((locResults == null || locResults.isEmpty()) && hereGeocodingProvider != null && hereGeocodingProvider.isConfigured()) {
                locResults = hereGeocodingProvider.search(locationQuery, 3, null, null);
            }
            if (locResults == null || locResults.isEmpty()) {
                return null;
            }

            LocationSearchResultResponse top = locResults.get(0);
            List<Double> bbox = top.getBoundingBox();
            double centerLat = top.getLatitude();
            double centerLon = top.getLongitude();

            double calculatedRadius = 15.0;
            if (bbox != null && bbox.size() == 4) {
                double d1 = GeographicFilterServiceImpl.haversineDistanceKm(centerLat, centerLon, bbox.get(0), bbox.get(2));
                double d2 = GeographicFilterServiceImpl.haversineDistanceKm(centerLat, centerLon, bbox.get(0), bbox.get(3));
                double d3 = GeographicFilterServiceImpl.haversineDistanceKm(centerLat, centerLon, bbox.get(1), bbox.get(2));
                double d4 = GeographicFilterServiceImpl.haversineDistanceKm(centerLat, centerLon, bbox.get(1), bbox.get(3));
                double maxD = Math.max(Math.max(d1, d2), Math.max(d3, d4));
                calculatedRadius = Math.max(maxD, 8.0);
            } else {
                String type = top.getType() != null ? top.getType().toLowerCase(Locale.ROOT) : "";
                if (type.contains("district") || type.contains("quận") || type.contains("huyện")) {
                    calculatedRadius = 8.0;
                } else if (type.contains("water") || type.contains("lake") || type.contains("park")) {
                    calculatedRadius = 3.5;
                } else {
                    calculatedRadius = 15.0;
                }
            }

            String state = extractProvince(top.getFormattedAddress());

            return GeographicTargetArea.builder()
                    .queryName(locationQuery)
                    .resolvedName(top.getFormattedAddress())
                    .centerLat(centerLat)
                    .centerLon(centerLon)
                    .boundingBox(bbox)
                    .maxRadiusKm(calculatedRadius)
                    .targetType(top.getType())
                    .stateOrProvince(state)
                    .build();
        } catch (Exception ex) {
            logger.warn("Error resolving geographic target area for '{}': {}", locationQuery, ex.getMessage());
            return null;
        }
    }

    private static final Set<String> INCOMPATIBLE_FOOD_TYPES = Set.of(
            "mobile_phone", "electronics", "car", "car_repair", "clothes",
            "motorcycle", "laundry", "optician", "beauty", "hairdresser",
            "florist", "furniture", "hardware", "atm", "bank", "fuel", "gas"
    );

    private boolean isIncompatibleFoodCandidate(LocationSearchResultResponse candidate) {
        if (candidate == null) return false;
        String type = candidate.getType() != null ? candidate.getType().toLowerCase(Locale.ROOT) : "";
        String cat = candidate.getCategory() != null ? candidate.getCategory().toLowerCase(Locale.ROOT) : "";
        return INCOMPATIBLE_FOOD_TYPES.contains(type) || "telecommunication".equals(cat);
    }

    private String extractProvince(String formattedAddress) {
        if (formattedAddress == null) {
            return null;
        }
        String[] parts = formattedAddress.split(",");
        for (int i = parts.length - 1; i >= 0; i--) {
            String p = parts[i].trim();
            String lower = p.toLowerCase(Locale.ROOT);
            if (lower.contains("tỉnh") || lower.contains("thành phố") || lower.contains("tp.") || lower.contains("tp ")) {
                return p;
            }
        }
        return null;
    }

    @Override
    public LocationSearchResultResponse resolveTomTomPlace(String type, String id, String sessionId) {
        if (tomTomProvider == null || !tomTomProvider.isEnabled()) throw new AppException("Tìm kiếm TomTom chưa được bật trên máy chủ", org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE);
        return tomTomProvider.details(type, id, sessionId);
    }

    private void validateOptionalCoordinates(Double latitude, Double longitude) {
        if ((latitude == null) != (longitude == null)) {
            throw new BadRequestException("Tọa độ tìm kiếm không hợp lệ");
        }
        if (latitude != null && (!Double.isFinite(latitude) || !Double.isFinite(longitude)
                || latitude < MIN_LATITUDE || latitude > MAX_LATITUDE
                || longitude < MIN_LONGITUDE || longitude > MAX_LONGITUDE)) {
            throw new BadRequestException("Tọa độ tìm kiếm không hợp lệ");
        }
    }

    @Override
    public LocationSearchResultResponse reverseGeocode(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) {
            throw new BadRequestException("Tọa độ latitude và longitude là bắt buộc");
        }

        if (latitude < MIN_LATITUDE || latitude > MAX_LATITUDE) {
            throw new BadRequestException("Tọa độ vĩ độ (latitude) phải nằm trong khoảng từ -90.0 đến 90.0");
        }

        if (longitude < MIN_LONGITUDE || longitude > MAX_LONGITUDE) {
            throw new BadRequestException("Tọa độ kinh độ (longitude) phải nằm trong khoảng từ -180.0 đến 180.0");
        }

        // Round coordinates to 5 decimal places (~1.1 meter resolution) to avoid key jitter and precision collisions
        double roundedLat = BigDecimal.valueOf(latitude).setScale(5, RoundingMode.HALF_UP).doubleValue();
        double roundedLon = BigDecimal.valueOf(longitude).setScale(5, RoundingMode.HALF_UP).doubleValue();

        String cacheKey = String.format(Locale.ROOT, "reverse:%.5f:%.5f", roundedLat, roundedLon);
        LocationSearchResultResponse cached = reverseCache.getIfPresent(cacheKey);
        if (cached != null) {
            logger.debug("Location reverse geocode cache HIT for key: {}", cacheKey);
            return cached;
        }

        logger.debug("Location reverse geocode cache MISS for key: {}. Calling provider: {}", cacheKey, primaryProvider.getProviderName());
        LocationSearchResultResponse result = primaryProvider.reverseGeocode(roundedLat, roundedLon);
        if (result == null && hereGeocodingProvider != null && hereGeocodingProvider.isConfigured()) {
            result = hereGeocodingProvider.reverseGeocode(roundedLat, roundedLon);
        }
        if (result == null) {
            throw new ResourceNotFoundException("Không tìm thấy thông tin địa điểm tại tọa độ đã chọn");
        }

        if (primaryProvider.isConfigured() || (hereGeocodingProvider != null && hereGeocodingProvider.isConfigured())) {
            reverseCache.put(cacheKey, result);
        }
        return result;
    }

    @Override
    public List<LocationSearchResultResponse> searchNearby(Double latitude, Double longitude, String category,
                                                            Integer radiusMeters, Integer limit) {
        if (latitude == null || longitude == null || !Double.isFinite(latitude) || !Double.isFinite(longitude)
                || latitude < MIN_LATITUDE || latitude > MAX_LATITUDE
                || longitude < MIN_LONGITUDE || longitude > MAX_LONGITUDE) {
            throw new BadRequestException("Vui lòng chọn tọa độ hợp lệ trên bản đồ");
        }
        int effectiveRadius = radiusMeters == null ? 2000 : radiusMeters;
        int effectiveLimit = limit == null ? DEFAULT_LIMIT : limit;
        if (effectiveRadius < 100 || effectiveRadius > 10000) {
            throw new BadRequestException("Bán kính tìm kiếm phải từ 100 đến 10000 mét");
        }
        if (effectiveLimit < 1 || effectiveLimit > MAX_LIMIT) {
            throw new BadRequestException("Số lượng kết quả phải từ 1 đến " + MAX_LIMIT);
        }
        String normalizedCategory = category == null || category.isBlank()
                ? "ALL" : category.trim().toUpperCase(Locale.ROOT);
        if (!List.of("ALL", "ATTRACTION", "FOOD", "CAFE", "STAY").contains(normalizedCategory)) {
            throw new BadRequestException("Loại địa điểm không được hỗ trợ");
        }
        double lat = BigDecimal.valueOf(latitude).setScale(4, RoundingMode.HALF_UP).doubleValue();
        double lon = BigDecimal.valueOf(longitude).setScale(4, RoundingMode.HALF_UP).doubleValue();
        String key = String.format(Locale.ROOT, "nearby:%s:%.4f:%.4f:%d:%d", normalizedCategory, lat, lon, effectiveRadius, effectiveLimit);
        List<LocationSearchResultResponse> cached = nearbyCache.getIfPresent(key);
        if (cached != null) return cached;
        List<LocationSearchResultResponse> result = primaryProvider.searchNearby(lat, lon, normalizedCategory, effectiveRadius, effectiveLimit);
        if (result == null) result = Collections.emptyList();
        if (primaryProvider.isConfigured()) nearbyCache.put(key, result);
        return result;
    }

    public void clearCaches() {
        searchCache.invalidateAll();
        reverseCache.invalidateAll();
        nearbyCache.invalidateAll();
    }

    public long getSearchCacheSize() {
        return searchCache.estimatedSize();
    }

    public long getReverseCacheSize() {
        return reverseCache.estimatedSize();
    }

    private String buildSearchCacheKey(String query, int limit, Double latitude, Double longitude) {
        String latStr = latitude != null ? String.format(Locale.ROOT, "%.5f", latitude) : "none";
        String lonStr = longitude != null ? String.format(Locale.ROOT, "%.5f", longitude) : "none";
        return "search:" + query.toLowerCase(Locale.ROOT) + ":" + limit + ":" + latStr + ":" + lonStr;
    }
}
