package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.location.GeographicTargetArea;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.service.GeographicFilterService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class GeographicFilterServiceImpl implements GeographicFilterService {

    private static final Logger logger = LoggerFactory.getLogger(GeographicFilterServiceImpl.class);

    private static final double EARTH_RADIUS_KM = 6371.0;
    private static final double BBOX_BUFFER_DEGREES = 0.025; // ~2.7 km buffer around edges

    // Major administrative regions for detecting cross-province false positives
    private static final List<String> KNOWN_REGIONS = List.of(
            "ho chi minh", "sai gon", "ha noi", "da nang", "hai phong", "can tho",
            "an giang", "vung tau", "ba ria", "da lat", "lam dong", "nha trang", "khanh hoa",
            "hue", "hoi an", "quang nam", "binh duong", "dong nai", "phu quoc", "kien giang",
            "dak lak", "buon ma thuot", "tien giang", "my tho", "ben tre", "vinh long",
            "dong thap", "soc trang", "bac lieu", "ca mau", "binh thuan", "phan thiet",
            "ninh thuan", "phan rang", "quang ninh", "ha long", "lao cai", "sapa"
    );

    @Override
    public List<LocationSearchResultResponse> filter(List<LocationSearchResultResponse> candidates, GeographicTargetArea targetArea) {
        if (candidates == null || candidates.isEmpty()) {
            return Collections.emptyList();
        }

        if (targetArea == null) {
            return candidates;
        }

        double centerLat = targetArea.getCenterLat();
        double centerLon = targetArea.getCenterLon();
        double maxRadiusKm = targetArea.getMaxRadiusKm() > 0 ? targetArea.getMaxRadiusKm() * 1.25 : 20.0;
        List<Double> bbox = targetArea.getBoundingBox();

        String targetContextNorm = buildTargetContextNormalized(targetArea);

        List<LocationSearchResultResponse> passed = new ArrayList<>();
        Set<String> seenCoordKeys = new HashSet<>();

        for (LocationSearchResultResponse candidate : candidates) {
            if (candidate == null) {
                continue;
            }

            Double lat = candidate.getLatitude();
            Double lon = candidate.getLongitude();

            // 1. Coordinate validity check
            if (lat == null || lon == null || !Double.isFinite(lat) || !Double.isFinite(lon)
                    || lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
                logger.debug("Discarded candidate '{}': invalid coordinates ({}, {})", candidate.getName(), lat, lon);
                continue;
            }

            // 2. Radial Haversine distance check
            double distanceKm = haversineDistanceKm(centerLat, centerLon, lat, lon);
            if (distanceKm > maxRadiusKm) {
                logger.debug("Discarded candidate '{}' at ({}, {}): distance {:.2f} km exceeds max radius {:.2f} km",
                        candidate.getName(), lat, lon, distanceKm, maxRadiusKm);
                continue;
            }

            // 3. Bounding box check (with buffer) if target area has bbox
            if (bbox != null && bbox.size() == 4) {
                double minLat = Math.min(bbox.get(0), bbox.get(1)) - BBOX_BUFFER_DEGREES;
                double maxLat = Math.max(bbox.get(0), bbox.get(1)) + BBOX_BUFFER_DEGREES;
                double minLon = Math.min(bbox.get(2), bbox.get(3)) - BBOX_BUFFER_DEGREES;
                double maxLon = Math.max(bbox.get(2), bbox.get(3)) + BBOX_BUFFER_DEGREES;

                if (lat < minLat || lat > maxLat || lon < minLon || lon > maxLon) {
                    // If outside bounding box and distance is also not very close (> 5 km), discard
                    if (distanceKm > 5.0) {
                        logger.debug("Discarded candidate '{}' at ({}, {}): outside bbox [{}, {}, {}, {}]",
                                candidate.getName(), lat, lon, minLat, maxLat, minLon, maxLon);
                        continue;
                    }
                }
            }

            // 4. Cross-province mismatch check
            if (isCrossProvinceMismatch(candidate, targetContextNorm, distanceKm)) {
                logger.debug("Discarded candidate '{}' ({}) due to cross-province mismatch with target '{}'",
                        candidate.getName(), candidate.getFormattedAddress(), targetContextNorm);
                continue;
            }

            // 5. Duplicate coordinate check
            String coordKey = String.format(Locale.ROOT, "%.3f:%.3f", lat, lon);
            if (seenCoordKeys.add(coordKey)) {
                passed.add(candidate);
            }
        }

        return passed;
    }

    private boolean isCrossProvinceMismatch(LocationSearchResultResponse candidate, String targetContextNorm, double distanceKm) {
        // Only trigger cross-province check if distance is at least 15 km away from center
        if (distanceKm < 15.0) {
            return false;
        }

        String addressNorm = QueryUnderstandingServiceImpl.normalize(candidate.getFormattedAddress());
        if (addressNorm.isBlank()) {
            return false;
        }

        for (String region : KNOWN_REGIONS) {
            if (addressNorm.contains(region)) {
                // If candidate address mentions this region, but target area does NOT contain this region
                if (!targetContextNorm.contains(region)) {
                    return true;
                }
            }
        }

        return false;
    }

    private String buildTargetContextNormalized(GeographicTargetArea targetArea) {
        StringBuilder sb = new StringBuilder();
        if (targetArea.getQueryName() != null) {
            sb.append(targetArea.getQueryName()).append(" ");
        }
        if (targetArea.getResolvedName() != null) {
            sb.append(targetArea.getResolvedName()).append(" ");
        }
        if (targetArea.getStateOrProvince() != null) {
            sb.append(targetArea.getStateOrProvince()).append(" ");
        }
        return QueryUnderstandingServiceImpl.normalize(sb.toString());
    }

    public static double haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double rLat1 = Math.toRadians(lat1);
        double rLat2 = Math.toRadians(lat2);

        double a = Math.sin(dLat / 2.0) * Math.sin(dLat / 2.0) +
                Math.cos(rLat1) * Math.cos(rLat2) *
                        Math.sin(dLon / 2.0) * Math.sin(dLon / 2.0);

        double c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
        return EARTH_RADIUS_KM * c;
    }
}

