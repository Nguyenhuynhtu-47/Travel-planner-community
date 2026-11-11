package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.service.LocationRankingService;
import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class LocationRankingServiceImpl implements LocationRankingService {

    private static final Pattern SERVICE_KEYWORDS_PATTERN = Pattern.compile(
            "\\b(quan|cà phê|ca phe|cafe|nha hang|nhà hàng|restaurant|khach san|khách sạn|hotel|tiem banh|tiệm bánh|bakery|nha thuoc|nhà thuốc|pharmacy|sieu thi|siêu thị|supermarket|cho|chợ|market|benh vien|bệnh viện|hospital|truong|trường|school|com|cơm|com tam|cơm tấm|pho|phở|bun|bún|bun bo|bún bò|lau|lẩu|banh mi|bánh mì|hu tieu|hủ tiếu|nem nuong|nem nướng|an uong|ăn uống|tra sua|trà sữa)\\b",
            Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE
    );

    private static final Set<String> INCOMPATIBLE_FOOD_TYPES = Set.of(
            "mobile_phone", "electronics", "car", "car_repair", "clothes",
            "motorcycle", "laundry", "optician", "beauty", "hairdresser",
            "florist", "furniture", "hardware", "atm", "bank", "fuel", "gas"
    );

    private static final Pattern REGION_PREPOSITION_PATTERN = Pattern.compile(
            "(?:ở|o|tại|tai|gần|gan|in|near|at)\\s+([^,]+)",
            Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE
    );

    @Override
    public List<LocationSearchResultResponse> rankAndDeduplicate(
            String query,
            List<LocationSearchResultResponse> results,
            Double viewportLat,
            Double viewportLon,
            int limit) {

        if (results == null || results.isEmpty()) {
            return Collections.emptyList();
        }

        String normQuery = normalizeText(query);
        boolean isCityQuery = isAdministrativeOrCityQuery(normQuery);
        String specifiedRegion = extractSpecifiedRegion(query);
        String normSpecifiedRegion = specifiedRegion != null ? normalizeText(specifiedRegion) : null;

        List<ScoredResult> scoredList = new ArrayList<>();
        Set<String> seenPlaceIds = new HashSet<>();

        for (LocationSearchResultResponse item : results) {
            if (item == null || item.getLatitude() == null || item.getLongitude() == null) {
                continue;
            }

            // Deduplicate by placeId
            if (item.getPlaceId() != null && !item.getPlaceId().isBlank()) {
                if (!seenPlaceIds.add(item.getPlaceId().trim())) {
                    continue;
                }
            }

            // Check duplicate against already admitted items
            boolean isDuplicate = false;
            int duplicateIndex = -1;
            for (int i = 0; i < scoredList.size(); i++) {
                LocationSearchResultResponse existing = scoredList.get(i).item();
                if (isDuplicateOf(item, existing)) {
                    isDuplicate = true;
                    duplicateIndex = i;
                    break;
                }
            }

            if (isDuplicate) {
                // If the new item is from SYSTEM (canonical Place) while existing is external,
                // replace existing with canonical SYSTEM Place to prioritize canonical catalog!
                if ("SYSTEM".equalsIgnoreCase(item.getProvider())
                        && !"SYSTEM".equalsIgnoreCase(scoredList.get(duplicateIndex).item().getProvider())) {
                    double score = calculateScore(
                            normQuery,
                            isCityQuery,
                            normSpecifiedRegion,
                            item,
                            viewportLat,
                            viewportLon
                    );
                    scoredList.set(duplicateIndex, new ScoredResult(item, score));
                }
                continue;
            }

            double score = calculateScore(
                    normQuery,
                    isCityQuery,
                    normSpecifiedRegion,
                    item,
                    viewportLat,
                    viewportLon
            );

            scoredList.add(new ScoredResult(item, score));
        }

        // Sort descending by score
        scoredList.sort(Comparator.comparingDouble(ScoredResult::score).reversed());

        int effectiveLimit = Math.max(1, limit);
        List<LocationSearchResultResponse> output = new ArrayList<>();
        for (int i = 0; i < scoredList.size() && output.size() < effectiveLimit; i++) {
            output.add(scoredList.get(i).item());
        }

        return output;
    }

    private double calculateScore(
            String normQuery,
            boolean isCityQuery,
            String normSpecifiedRegion,
            LocationSearchResultResponse item,
            Double viewportLat,
            Double viewportLon) {

        double score = 0.0;
        String normName = normalizeText(item.getName());
        String normAddress = normalizeText(item.getFormattedAddress());
        String type = item.getType() != null ? item.getType().toLowerCase(Locale.ROOT) : "";
        String category = item.getCategory() != null ? item.getCategory().toLowerCase(Locale.ROOT) : "";

        // 1. Name Match Quality
        String cleanQuery = stripAdministrativePrefix(normQuery);
        boolean isGenericService = isGenericServiceWord(cleanQuery.isEmpty() ? normQuery : cleanQuery);

        if (isGenericService) {
            // For generic service/dish queries (e.g. "bánh mì", "cơm tấm", "quán cà phê"),
            // named establishments (e.g. "Bánh Mì Huynh Hoa", "Quán Cà Phê Mộc") are far more relevant
            // than bare unverified nodes whose name is literally just the generic word itself.
            if (normName.startsWith(cleanQuery + " ") || normName.endsWith(" " + cleanQuery)
                    || normName.startsWith(normQuery + " ") || normName.endsWith(" " + normQuery)) {
                score += 70.0; // Named venue with category prefix (e.g. "Bánh Mì Huynh Hoa")
            } else if (normName.contains(cleanQuery) || normName.contains(normQuery)) {
                score += 50.0;
            } else if (normName.equals(normQuery) || (!cleanQuery.isEmpty() && normName.equals(cleanQuery))) {
                score += 30.0; // Bare literal node (e.g. node named "bánh mì")
            }
        } else {
            if (normName.equals(normQuery) || (!cleanQuery.isEmpty() && normName.equals(cleanQuery))) {
                score += 70.0; // Exact match (e.g. "Vũng Tàu" == "Vũng Tàu", "Tỉnh Lâm Đồng" == "Lâm Đồng")
            } else if (normName.startsWith(normQuery + " ") || normName.endsWith(" " + normQuery)
                    || (!cleanQuery.isEmpty() && (normName.startsWith(cleanQuery + " ") || normName.endsWith(" " + cleanQuery)))) {
                score += 35.0; // e.g. "Tỉnh Lâm Đồng" ends with " Lâm Đồng"
            } else if (normName.contains(normQuery) || (!cleanQuery.isEmpty() && normName.contains(cleanQuery))) {
                score += 20.0;
            }
        }

        // 2. Entity Type vs Search Intent
        boolean isItemAdminPlace = isAdministrativePlace(type, category);
        if (isCityQuery) {
            boolean nameMatchesAdministrative = normName.equals(normQuery)
                    || (!cleanQuery.isEmpty() && normName.equals(cleanQuery))
                    || (!cleanQuery.isEmpty() && normName.contains(cleanQuery))
                    || normQuery.contains(normName);

            if (nameMatchesAdministrative) {
                if (isItemAdminPlace) {
                    score += 65.0; // Huge boost for the matching administrative entity
                } else if (isFoodOrCommercialPlace(type, category)) {
                    score -= 45.0; // Heavy penalty for random restaurants named after a city
                }
            } else {
                // If searching for an administrative unit (e.g. "Lâm Đồng"),
                // candidates whose names do not contain the administrative query
                // (e.g. "Hưng Lâm", "Phú Lâm" sharing only a single isolated syllable "Lâm")
                // must be heavily penalized so they never outrank the true administrative region.
                if (isItemAdminPlace) {
                    score -= 60.0;
                } else {
                    score -= 40.0;
                }
            }
        } else {
            // Service / POI search intent
            if (matchesServiceIntent(normQuery, type, category)) {
                score += 45.0;
            }
            // Incompatible commercial type penalty for food searches (e.g. mobile phone shops like Ngocankhang.com)
            if (isFoodIntent(normQuery) && isIncompatibleFoodType(type, category)) {
                score -= 100.0;
            }
            // Administrative boundaries are not POIs; apply penalty so they never outrank real venues
            if (isItemAdminPlace) {
                score -= 30.0;
            }
        }

        // 3. Regional Alignment (when query specified "ở Đà Lạt", "tại Vũng Tàu", etc.)
        if (normSpecifiedRegion != null && !normSpecifiedRegion.isBlank()) {
            if (normAddress.contains(normSpecifiedRegion) || normName.contains(normSpecifiedRegion)) {
                score += 40.0;
            } else {
                score -= 40.0; // Penalize places outside the user-specified region
            }
        }

        // 4. Provider Importance
        if (item.getImportance() != null) {
            score += item.getImportance() * 25.0;
        }
        if ("SYSTEM".equalsIgnoreCase(item.getProvider())) {
            // Apply SYSTEM boost to canonical places; only boost administrative boundaries when user intended an administrative/city query
            if (!isItemAdminPlace || isCityQuery) {
                score += 50.0;
            }
        }

        // 5. Viewport Proximity Tie-Breaker (Only for generic queries without explicit region)
        if (!isCityQuery && normSpecifiedRegion == null && viewportLat != null && viewportLon != null) {
            double distanceKm = haversineDistance(viewportLat, viewportLon, item.getLatitude(), item.getLongitude());
            if (distanceKm <= 30.0) {
                // Modest boost (max +10 points) for places near current map camera
                score += (30.0 - distanceKm) / 3.0;
            }
        }

        return score;
    }

    private boolean isAdministrativeOrCityQuery(String normQuery) {
        if (SERVICE_KEYWORDS_PATTERN.matcher(normQuery).find()) {
            return false;
        }
        // Count words
        String[] words = normQuery.split("\\s+");
        return words.length <= 4;
    }

    private boolean isAdministrativePlace(String type, String category) {
        return "city".equals(type) || "town".equals(type) || "village".equals(type)
                || "administrative".equals(type) || "boundary".equals(type)
                || "state".equals(type) || "province".equals(type)
                || "country".equals(type) || "municipality".equals(type)
                || "historic".equals(type) || "place".equals(category)
                || "boundary".equals(category);
    }

    private boolean isFoodOrCommercialPlace(String type, String category) {
        return "restaurant".equals(type) || "fast_food".equals(type) || "cafe".equals(type)
                || "food_court".equals(type) || "bus_stop".equals(type) || "motorway".equals(type)
                || "motorway_link".equals(type) || "logistics".equals(type) || "shop".equals(category)
                || "amenity".equals(category);
    }

    private boolean matchesServiceIntent(String normQuery, String type, String category) {
        if (normQuery.contains("ca phe") || normQuery.contains("cafe") || normQuery.contains("coffee")) {
            return "cafe".equals(type) || "coffee".equals(type) || "cafe".equals(category);
        }
        if (normQuery.contains("tiem banh") || normQuery.contains("bakery")) {
            return "bakery".equals(type) || "pastry".equals(type) || "bakery".equals(category);
        }
        if (normQuery.contains("nha thuoc") || normQuery.contains("pharmacy")) {
            return "pharmacy".equals(type) || "chemist".equals(type) || "pharmacy".equals(category);
        }
        if (normQuery.contains("khach san") || normQuery.contains("hotel")) {
            return "hotel".equals(type) || "motel".equals(type) || "guest_house".equals(type) || "hostel".equals(type);
        }
        if (normQuery.contains("nha hang") || normQuery.contains("restaurant") || normQuery.contains("quan an")
                || normQuery.contains("com") || normQuery.contains("pho") || normQuery.contains("bun")
                || normQuery.contains("lau") || normQuery.contains("banh mi") || normQuery.contains("nem nuong")
                || normQuery.contains("hu tieu") || normQuery.contains("food")) {
            return "restaurant".equals(type) || "fast_food".equals(type) || "food_court".equals(type)
                    || "cafe".equals(type) || "bakery".equals(type) || "food".equals(category);
        }
        return false;
    }

    private boolean isFoodIntent(String normQuery) {
        return normQuery.contains("com") || normQuery.contains("pho") || normQuery.contains("bun")
                || normQuery.contains("lau") || normQuery.contains("nha hang") || normQuery.contains("quan")
                || normQuery.contains("restaurant") || normQuery.contains("food") || normQuery.contains("banh mi")
                || normQuery.contains("nem nuong") || normQuery.contains("hu tieu");
    }

    private boolean isIncompatibleFoodType(String type, String category) {
        return INCOMPATIBLE_FOOD_TYPES.contains(type) || "telecommunication".equals(category);
    }

    private String extractSpecifiedRegion(String query) {
        Matcher m = REGION_PREPOSITION_PATTERN.matcher(query);
        if (m.find()) {
            return m.group(1).trim();
        }
        if (query.contains(",")) {
            String[] parts = query.split(",");
            if (parts.length > 1) {
                return parts[parts.length - 1].trim();
            }
        }
        return null;
    }

    public static String normalizeText(String input) {
        if (input == null || input.isBlank()) {
            return "";
        }
        String s = input.trim().toLowerCase(Locale.ROOT);
        s = s.replace("đ", "d").replace("Đ", "d");
        s = Normalizer.normalize(s, Normalizer.Form.NFD);
        s = s.replaceAll("\\p{M}", "");
        return s.replaceAll("\\s+", " ").trim();
    }

    private boolean isGenericServiceWord(String norm) {
        if (norm == null || norm.isBlank()) return false;
        return SERVICE_KEYWORDS_PATTERN.matcher(norm).find() || norm.equals("banh mi") || norm.equals("com tam");
    }

    private String stripAdministrativePrefix(String norm) {
        if (norm == null) return "";
        return norm.replaceAll("^(thanh pho|tp\\.?|tinh|quan|huyen|thi xa|thi tran|phuong|xa)\\s+", "").trim();
    }

    private double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
        double R = 6371.0; // Earth radius in km
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    private boolean isDuplicateOf(LocationSearchResultResponse item, LocationSearchResultResponse existing) {
        if (item.getPlaceId() != null && existing.getPlaceId() != null
                && item.getPlaceId().trim().equalsIgnoreCase(existing.getPlaceId().trim())) {
            return true;
        }

        String normName1 = normalizeText(item.getName());
        String normName2 = normalizeText(existing.getName());
        if (!normName1.equals(normName2)) {
            // Different names (e.g. Shop A vs Shop B): never deduplicate, even if within 10m!
            return false;
        }

        double distanceKm = haversineDistance(
                item.getLatitude(), item.getLongitude(),
                existing.getLatitude(), existing.getLongitude()
        );

        // Distance greater than 110m (~0.11 km): geographically distinct!
        if (distanceKm > 0.110) {
            return false;
        }

        // Within 110m and identical name: check if addresses indicate distinct physical locations
        if (hasDistinctAddresses(item.getFormattedAddress(), existing.getFormattedAddress())) {
            return false;
        }

        return true;
    }

    private boolean hasDistinctAddresses(String addr1, String addr2) {
        if (addr1 == null || addr2 == null || addr1.isBlank() || addr2.isBlank()) {
            return false;
        }
        String norm1 = normalizeText(addr1).replaceAll("[^a-z0-9\\s]", " ");
        String norm2 = normalizeText(addr2).replaceAll("[^a-z0-9\\s]", " ");
        if (norm1.equals(norm2)) {
            return false;
        }

        Set<String> numbers1 = extractHouseNumbers(norm1);
        Set<String> numbers2 = extractHouseNumbers(norm2);

        // If both have explicit house numbers and they don't share any -> distinct physical addresses!
        if (!numbers1.isEmpty() && !numbers2.isEmpty() && Collections.disjoint(numbers1, numbers2)) {
            return true;
        }

        // Check if distinct street names are mentioned (e.g. "le loi" vs "pasteur")
        boolean hasLeLoi1 = norm1.contains("le loi");
        boolean hasLeLoi2 = norm2.contains("le loi");
        boolean hasPasteur1 = norm1.contains("pasteur");
        boolean hasPasteur2 = norm2.contains("pasteur");
        if ((hasLeLoi1 && !hasLeLoi2 && hasPasteur2) || (hasPasteur1 && !hasPasteur2 && hasLeLoi2)) {
            return true;
        }

        return false;
    }

    private Set<String> extractHouseNumbers(String cleanAddr) {
        Set<String> houseNumbers = new HashSet<>();
        String[] tokens = cleanAddr.trim().split("\\s+");
        for (int i = 0; i < tokens.length; i++) {
            String token = tokens[i];
            if (token.matches("\\d+[a-z]?")) {
                if (i > 0) {
                    String prev = tokens[i - 1];
                    if (prev.equals("quan") || prev.equals("q") || prev.equals("phuong") || prev.equals("p")
                            || prev.equals("to") || prev.equals("kp") || prev.equals("ap") || prev.equals("xa")
                            || prev.equals("huyen") || prev.equals("tang") || prev.equals("tp")) {
                        continue;
                    }
                }
                houseNumbers.add(token);
            }
        }
        return houseNumbers;
    }

    private record ScoredResult(LocationSearchResultResponse item, double score) {
    }
}

