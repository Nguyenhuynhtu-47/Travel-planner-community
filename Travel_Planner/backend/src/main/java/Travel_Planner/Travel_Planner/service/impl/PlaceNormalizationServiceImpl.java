package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.service.PlaceNormalizationService;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.text.Normalizer;
import java.util.*;
import java.util.regex.Pattern;

@Service
public class PlaceNormalizationServiceImpl implements PlaceNormalizationService {

    private static final Set<String> PROTECTED_COMPOUND_NAMES = Set.of(
            "ho hoan kiem", "ho tay", "vinh ha long", "ba na hills",
            "chua mot cot", "van mieu quoc tu giam", "cho ben thanh",
            "dinh fansipan", "pho co hoi an", "co do hue", "nha tho duc ba",
            "cau rong", "ben nha rong", "thung lung tinh yeu", "nui ba den",
            "suoi tien", "dam sen", "lang bac", "hoang thanh thang long"
    );

    private static final Set<String> CHAIN_BRANDS = Set.of(
            "highlands coffee", "the coffee house", "pho 24", "kfc", "lotteria",
            "mcdonalds", "circle k", "7 eleven", "winmart", "vinmart",
            "ca phe trung nguyen", "cong ca phe", "gogi house", "kichi kichi",
            "phuc long", "starbucks", "jollibee", "pizza hut", "dominos pizza"
    );

    private static final Pattern MULTI_SPACE = Pattern.compile("\\s+");

    @Override
    public String normalizeText(String input) {
        if (input == null || input.isBlank()) {
            return "";
        }
        String s = input.trim().toLowerCase(Locale.ROOT);
        s = s.replace("đ", "d").replace("Đ", "d");
        s = Normalizer.normalize(s, Normalizer.Form.NFD);
        s = s.replaceAll("\\p{M}", "");
        // Remove non-alphanumeric except spaces
        s = s.replaceAll("[^a-z0-9\\s]", " ");
        return MULTI_SPACE.matcher(s).replaceAll(" ").trim();
    }

    @Override
    public String normalizeAddress(String address) {
        if (address == null || address.isBlank()) {
            return "";
        }
        String norm = address.trim();

        // Standardize common Vietnamese city & province abbreviations
        norm = norm.replaceAll("(?i)\\b(tp\\.?\\s*hcm|tp\\.?\\s*hồ\\s*chí\\s*minh|thành\\s*phố\\s*hồ\\s*chí\\s*minh)\\b", "TP. Hồ Chí Minh");
        norm = norm.replaceAll("(?i)\\b(tp\\.?\\s*hà\\s*nội|thành\\s*phố\\s*hà\\s*nội)\\b", "Hà Nội");
        norm = norm.replaceAll("(?i)\\b(tp\\.?\\s*đà\\s*nẵng|thành\\s*phố\\s*đà\\s*nẵng)\\b", "Đà Nẵng");
        norm = norm.replaceAll("(?i)\\b(tp\\.?\\s*hải\\s*phòng|thành\\s*phố\\s*hải\\s*phòng)\\b", "Hải Phòng");
        norm = norm.replaceAll("(?i)\\b(tp\\.?\\s*cần\\s*thơ|thành\\s*phố\\s*cần\\s*thơ)\\b", "Cần Thơ");

        // Standardize District / Ward abbreviations (e.g., "Q.1", "Q. 1", "P. Bến Nghé", "Q.Bình Thạnh")
        // Use negative lookahead to avoid re-matching already expanded words ("Quận", "Phường")
        norm = norm.replaceAll("(?i)\\b(q\\.|q\\b)\\s*(?!uận|uan)(\\d+|[A-Za-zÀ-ỹ]+)", "Quận $2");
        norm = norm.replaceAll("(?i)\\b(p\\.|p\\b)\\s*(?!hường|huong)(\\d+|[A-Za-zÀ-ỹ]+)", "Phường $2");

        return MULTI_SPACE.matcher(norm).replaceAll(" ").trim();
    }

    @Override
    public boolean isProtectedCompoundName(String name) {
        if (name == null || name.isBlank()) {
            return false;
        }
        String norm = normalizeText(name);
        for (String protectedName : PROTECTED_COMPOUND_NAMES) {
            if (norm.equals(protectedName) || norm.contains(protectedName)) {
                return true;
            }
        }
        return false;
    }

    @Override
    public boolean isDifferentBranch(String name1, String name2, String addr1, String addr2, double distanceMeters) {
        String norm1 = normalizeText(name1);
        String norm2 = normalizeText(name2);

        boolean isChain1 = CHAIN_BRANDS.stream().anyMatch(norm1::contains);
        boolean isChain2 = CHAIN_BRANDS.stream().anyMatch(norm2::contains);

        if (isChain1 && isChain2) {
            // If it is a known chain brand:
            // 1. If distance > 100 meters, they are distinct physical branches!
            if (distanceMeters > 100.0) {
                return true;
            }
            // 2. If addresses specify different streets or house numbers, they are distinct
            String normAddr1 = normalizeText(addr1);
            String normAddr2 = normalizeText(addr2);
            if (!normAddr1.isEmpty() && !normAddr2.isEmpty() && !normAddr1.equals(normAddr2)) {
                // Check if they mention different street numbers or street names
                return hasDistinctAddressTokens(normAddr1, normAddr2);
            }
        }
        return false;
    }

    private boolean hasDistinctAddressTokens(String addr1, String addr2) {
        String[] tokens1 = addr1.split("\\s+");
        String[] tokens2 = addr2.split("\\s+");
        Set<String> set1 = new HashSet<>(Arrays.asList(tokens1));
        Set<String> set2 = new HashSet<>(Arrays.asList(tokens2));

        // Find numbers (potential street numbers) in both
        Set<String> numbers1 = new HashSet<>();
        Set<String> numbers2 = new HashSet<>();
        for (String t : set1) if (t.matches("\\d+")) numbers1.add(t);
        for (String t : set2) if (t.matches("\\d+")) numbers2.add(t);

        if (!numbers1.isEmpty() && !numbers2.isEmpty() && Collections.disjoint(numbers1, numbers2)) {
            return true; // e.g. "49 bat dan" vs "55 bat dan"
        }
        return false;
    }

    @Override
    public double calculateMatchConfidence(Place existingPlace,
                                           String incomingName,
                                           String incomingAddress,
                                           BigDecimal incomingLat,
                                           BigDecimal incomingLon,
                                           PlaceCategory incomingCategory) {
        if (existingPlace == null || incomingLat == null || incomingLon == null) {
            return 0.0;
        }

        double distanceMeters = haversineDistanceMeters(
                existingPlace.getLatitude().doubleValue(),
                existingPlace.getLongitude().doubleValue(),
                incomingLat.doubleValue(),
                incomingLon.doubleValue()
        );

        // Rule 1: Spatial threshold - If > 300 meters apart, definitely NOT the same physical place
        if (distanceMeters > 300.0) {
            return 0.0;
        }

        // Rule 2: Chain brand branch check - distinct branches of the same chain must never be merged
        if (isDifferentBranch(existingPlace.getName(), incomingName,
                existingPlace.getAddress(), incomingAddress, distanceMeters)) {
            return 0.0;
        }

        // Rule 3: Name similarity score
        double nameScore = computeNameSimilarity(existingPlace.getName(), incomingName);
        if (nameScore < 0.3) {
            // Completely different names (e.g. "Tiệm Vàng" vs "Quán Phở") even if within 10 meters: never merge
            return 0.0;
        }

        // Rule 4: Proximity score
        double proximityScore;
        if (distanceMeters <= 50.0) {
            proximityScore = 1.0;
        } else if (distanceMeters <= 100.0) {
            proximityScore = 0.8;
        } else if (distanceMeters <= 200.0) {
            proximityScore = 0.5;
        } else {
            proximityScore = 0.2;
        }

        // Rule 5: Address similarity score
        double addressScore = computeAddressSimilarity(existingPlace.getAddress(), incomingAddress);

        // Rule 6: Category compatibility score
        double categoryScore = computeCategoryScore(existingPlace.getCategory(), incomingCategory);

        // Weighted confidence calculation
        double confidence = (0.45 * nameScore) + (0.35 * proximityScore) + (0.10 * addressScore) + (0.10 * categoryScore);
        return Math.min(1.0, Math.max(0.0, confidence));
    }

    private double computeNameSimilarity(String name1, String name2) {
        String norm1 = normalizeText(name1);
        String norm2 = normalizeText(name2);
        if (norm1.isEmpty() || norm2.isEmpty()) return 0.0;
        if (norm1.equals(norm2)) return 1.0;

        if (norm1.contains(norm2) || norm2.contains(norm1)) {
            return 0.85;
        }

        Set<String> words1 = new HashSet<>(Arrays.asList(norm1.split("\\s+")));
        Set<String> words2 = new HashSet<>(Arrays.asList(norm2.split("\\s+")));

        Set<String> intersection = new HashSet<>(words1);
        intersection.retainAll(words2);

        Set<String> union = new HashSet<>(words1);
        union.addAll(words2);

        if (union.isEmpty()) return 0.0;
        return (double) intersection.size() / union.size();
    }

    private double computeAddressSimilarity(String addr1, String addr2) {
        String norm1 = normalizeText(addr1);
        String norm2 = normalizeText(addr2);
        if (norm1.isEmpty() || norm2.isEmpty()) return 0.5; // Neutral if one lacks address
        if (norm1.equals(norm2)) return 1.0;

        Set<String> words1 = new HashSet<>(Arrays.asList(norm1.split("\\s+")));
        Set<String> words2 = new HashSet<>(Arrays.asList(norm2.split("\\s+")));

        Set<String> intersection = new HashSet<>(words1);
        intersection.retainAll(words2);

        Set<String> union = new HashSet<>(words1);
        union.addAll(words2);

        if (union.isEmpty()) return 0.0;
        return (double) intersection.size() / union.size();
    }

    private double computeCategoryScore(PlaceCategory cat1, PlaceCategory cat2) {
        if (cat1 == null || cat2 == null) return 0.7; // Neutral
        if (cat1 == cat2) return 1.0;
        if (cat1 == PlaceCategory.OTHER || cat2 == PlaceCategory.OTHER) return 0.8;
        // Compatible pairs (e.g. RESTAURANT and CAFE)
        if ((cat1 == PlaceCategory.RESTAURANT && cat2 == PlaceCategory.CAFE) ||
            (cat1 == PlaceCategory.CAFE && cat2 == PlaceCategory.RESTAURANT)) {
            return 0.9;
        }
        return 0.4; // Distinct categories
    }

    @Override
    public PlaceCategory mapProviderCategory(String rawCategory, String rawType) {
        String cat = rawCategory != null ? rawCategory.toLowerCase(Locale.ROOT) : "";
        String type = rawType != null ? rawType.toLowerCase(Locale.ROOT) : "";

        // Check specific hospitality / food / shop / leisure categories before generic "tourism"
        if (cat.contains("hotel") || type.contains("hotel") || type.contains("motel") ||
            type.contains("hostel") || type.contains("guest_house") || cat.contains("accommodation")) {
            return PlaceCategory.HOTEL;
        }
        if (cat.contains("cafe") || type.contains("cafe") || type.contains("coffee") ||
            type.contains("tea") || type.contains("bakery")) {
            return PlaceCategory.CAFE;
        }
        if (cat.contains("restaurant") || type.contains("restaurant") || type.contains("food") ||
            type.contains("fast_food") || type.contains("food_court") || cat.contains("eat-drink")) {
            return PlaceCategory.RESTAURANT;
        }
        if (cat.contains("shop") || type.contains("supermarket") || type.contains("mall") ||
            type.contains("marketplace") || type.contains("convenience") || cat.contains("shopping")) {
            return PlaceCategory.SHOPPING;
        }
        if (type.contains("cinema") || type.contains("theatre") || type.contains("nightclub") ||
            type.contains("theme_park") || cat.contains("leisure")) {
            return PlaceCategory.ENTERTAINMENT;
        }
        if (cat.contains("tourism") || type.contains("attraction") || type.contains("museum") ||
            type.contains("monument") || type.contains("historic") || type.contains("viewpoint") ||
            cat.contains("sight") || cat.contains("landmark")) {
            return PlaceCategory.ATTRACTION;
        }
        return PlaceCategory.OTHER;
    }

    @Override
    public double haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
        double R = 6371000.0; // Earth radius in meters
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}

