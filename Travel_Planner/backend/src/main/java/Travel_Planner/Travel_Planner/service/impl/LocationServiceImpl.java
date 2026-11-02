package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.service.GeocodingProvider;
import Travel_Planner.Travel_Planner.service.LocationService;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

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

    private final GeocodingProvider geocodingProvider;

    public LocationServiceImpl(GeocodingProvider geocodingProvider) {
        this.geocodingProvider = geocodingProvider;
    }

    @Override
    public List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude) {
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

        logger.debug("Location search cache MISS for key: {}. Calling provider: {}", cacheKey, geocodingProvider.getProviderName());
        List<LocationSearchResultResponse> results = geocodingProvider.search(trimmed, effectiveLimit, normalizedLat, normalizedLon);
        if (results == null) {
            results = Collections.emptyList();
        }

        // Cache results only if the provider is configured (avoids caching unconfigured empty lists across server reconfigs)
        if (geocodingProvider.isConfigured()) {
            searchCache.put(cacheKey, results);
        }

        return results;
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

        logger.debug("Location reverse geocode cache MISS for key: {}. Calling provider: {}", cacheKey, geocodingProvider.getProviderName());
        LocationSearchResultResponse result = geocodingProvider.reverseGeocode(roundedLat, roundedLon);
        if (result == null) {
            throw new ResourceNotFoundException("Không tìm thấy thông tin địa điểm tại tọa độ đã chọn");
        }

        if (geocodingProvider.isConfigured()) {
            reverseCache.put(cacheKey, result);
        }
        return result;
    }

    public void clearCaches() {
        searchCache.invalidateAll();
        reverseCache.invalidateAll();
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
