package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.location.ParsedLocationQuery;
import Travel_Planner.Travel_Planner.dto.location.SearchIntent;
import Travel_Planner.Travel_Planner.service.QueryUnderstandingService;
import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class QueryUnderstandingServiceImpl implements QueryUnderstandingService {

    // Regex for preposition splitting: e.g. "cơm tấm ở Long Xuyên", "tiệm bánh gần Hồ Gươm"
    private static final Pattern PREPOSITION_PATTERN = Pattern.compile(
            "(?i)^(.*?)\\s+(?:ở|tại|tai|gần|gan|near|khu\\s+vực|khu\\s+vuc|quanh)\\s+(.+)$"
    );

    // Administrative prefixes that strongly denote a locality search
    private static final Pattern ADMINISTRATIVE_PREFIX_PATTERN = Pattern.compile(
            "(?i)^(thành\\s+phố|thanh\\s+pho|tp\\.?|tỉnh|tinh|quận|quan|huyện|huyen|thị\\s+xã|thi\\s+xa|thị\\s+trấn|thi\\s+tran|phường|phuong|xã|xa|đảo|dao)\\s+(.+)$"
    );

    // Known administrative regions, provinces, and major cities across Vietnam
    private static final Set<String> KNOWN_ADMINISTRATIVE_REGIONS = Set.of(
            "an giang", "ba ria", "vung tau", "ba ria - vung tau", "ba ria vung tau",
            "bac giang", "bac kan", "bac lieu", "bac ninh", "ben tre", "binh dinh", "quy nhon",
            "binh duong", "binh phuoc", "binh thuan", "phan thiet", "ca mau", "can tho",
            "cao bang", "da nang", "dak lak", "buon ma thuot", "dak nong", "dien bien",
            "dong nai", "bien hoa", "dong thap", "cao lanh", "sa dec", "gia lai", "pleiku",
            "ha giang", "ha nam", "ha noi", "ha tinh", "hai duong", "hai phong", "hau giang",
            "hoa binh", "hung yen", "khanh hoa", "nha trang", "cam ranh", "kien giang", "rach gia",
            "ha tien", "phu quoc", "kon tum", "lai chau", "lam dong", "da lat", "bao loc",
            "lang son", "lao cai", "sa pa", "sapa", "long an", "tan an", "nam dinh", "nghe an",
            "vinh", "ninh binh", "ninh thuan", "phan rang", "phu tho", "viet tri", "phu yen",
            "tuy hoa", "quang binh", "dong hoi", "quang nam", "tam ky", "hoi an", "quang ngai",
            "quang ninh", "ha long", "cam pha", "mong cai", "quang tri", "dong ha", "soc trang",
            "son la", "tay ninh", "thai binh", "thai nguyen", "thanh hoa", "thua thien hue", "hue",
            "tien giang", "my tho", "tra vinh", "tuyen quang", "vinh long", "vinh phuc", "yen bai",
            "ho chi minh", "sai gon", "thu duc", "long xuyen", "chau doc"
    );

    // Well-known standalone Vietnamese specialty dishes that contain geographic names
    // but should NOT be parsed as searching inside that city (e.g. "bún bò Huế" is a dish name).
    private static final Set<String> PROTECTED_COMPOUND_DISHES = Set.of(
            "bun bo hue",
            "pho ha noi",
            "mi quang",
            "banh canh trang bang",
            "nem nuong nha trang",
            "banh khot vung tau",
            "cha ca la vong",
            "bun cha ha noi",
            "com ga tam ky",
            "banh da cua hai phong",
            "bun ca soc trang",
            "hu tieu my tho",
            "hu tieu nam vang",
            "banh pia soc trang",
            "ga doi phu tho",
            "vit quay lang son",
            "banh cuon thanh tri",
            "banh gai ninh giang"
    );

    // Ordered category prefix entries (longest to shortest) to match activities and services
    private record CategoryPrefix(String normalizedPrefix, String category) {}

    private static final List<CategoryPrefix> CATEGORY_PREFIXES = List.of(
            // Food & Dining
            new CategoryPrefix("quan ca phe", "CAFE"),
            new CategoryPrefix("quan com tam", "FOOD"),
            new CategoryPrefix("quan an vat", "FOOD"),
            new CategoryPrefix("tiem banh mi", "BAKERY"),
            new CategoryPrefix("cua hang tien loi", "SUPERMARKET"),
            new CategoryPrefix("trung tam thuong mai", "SUPERMARKET"),
            new CategoryPrefix("khu du lich", "ATTRACTION"),
            new CategoryPrefix("diem du lich", "ATTRACTION"),
            new CategoryPrefix("hieu thuoc", "PHARMACY"),
            new CategoryPrefix("phong kham", "PHARMACY"),
            new CategoryPrefix("nha thuoc", "PHARMACY"),
            new CategoryPrefix("benh vien", "PHARMACY"),
            new CategoryPrefix("khach san", "STAY"),
            new CategoryPrefix("nha nghi", "STAY"),
            new CategoryPrefix("homestay", "STAY"),
            new CategoryPrefix("resort", "STAY"),
            new CategoryPrefix("hostel", "STAY"),
            new CategoryPrefix("motel", "STAY"),
            new CategoryPrefix("hotel", "STAY"),
            new CategoryPrefix("tiem banh", "BAKERY"),
            new CategoryPrefix("banh ngot", "BAKERY"),
            new CategoryPrefix("bakery", "BAKERY"),
            new CategoryPrefix("sieu thi", "SUPERMARKET"),
            new CategoryPrefix("supermarket", "SUPERMARKET"),
            new CategoryPrefix("tap hoa", "SUPERMARKET"),
            new CategoryPrefix("com tam", "FOOD"),
            new CategoryPrefix("quan com", "FOOD"),
            new CategoryPrefix("quan an", "FOOD"),
            new CategoryPrefix("nha hang", "FOOD"),
            new CategoryPrefix("hai san", "FOOD"),
            new CategoryPrefix("quan nhau", "FOOD"),
            new CategoryPrefix("quan nuoc", "CAFE"),
            new CategoryPrefix("quan pho", "FOOD"),
            new CategoryPrefix("quan bun", "FOOD"),
            new CategoryPrefix("quan bar", "CAFE"),
            new CategoryPrefix("an vat", "FOOD"),
            new CategoryPrefix("banh mi", "FOOD"),
            new CategoryPrefix("ca phe", "CAFE"),
            new CategoryPrefix("tra sua", "CAFE"),
            new CategoryPrefix("nuoc ep", "CAFE"),
            new CategoryPrefix("coffee", "CAFE"),
            new CategoryPrefix("cafe", "CAFE"),
            new CategoryPrefix("quan", "FOOD"),
            new CategoryPrefix("com", "FOOD"),
            new CategoryPrefix("pho", "FOOD"),
            new CategoryPrefix("bun", "FOOD"),
            new CategoryPrefix("lau", "FOOD"),
            new CategoryPrefix("chay", "FOOD"),
            new CategoryPrefix("mall", "SUPERMARKET"),
            new CategoryPrefix("bar", "CAFE"),
            new CategoryPrefix("pub", "CAFE")
    );

    @Override
    public ParsedLocationQuery parseQuery(String rawQuery) {
        if (rawQuery == null || rawQuery.isBlank()) {
            return ParsedLocationQuery.builder()
                    .originalQuery("")
                    .normalizedQuery("")
                    .searchKeyword("")
                    .searchIntent(SearchIntent.GENERIC_POI)
                    .build();
        }

        String original = rawQuery.trim();
        String normalized = normalize(original);

        // 1. Check if the query is a protected compound dish name (e.g. "bún bò Huế")
        if (PROTECTED_COMPOUND_DISHES.contains(normalized)) {
            return ParsedLocationQuery.builder()
                    .originalQuery(original)
                    .normalizedQuery(normalized)
                    .searchKeyword(original)
                    .locationQuery(null)
                    .placeCategory("FOOD")
                    .searchIntent(SearchIntent.GENERIC_POI)
                    .build();
        }

        // 2. Explicit preposition check: e.g. "cơm tấm ở Long Xuyên", "tiệm bánh gần Hồ Gươm"
        Matcher prepMatcher = PREPOSITION_PATTERN.matcher(original);
        if (prepMatcher.find()) {
            String left = prepMatcher.group(1).trim();
            String right = prepMatcher.group(2).trim();

            if (!left.isBlank() && right.length() >= 2) {
                String leftNorm = normalize(left);
                String category = resolveCategoryFromText(leftNorm);

                if (isAdministrativeLocality(left, leftNorm)) {
                    return ParsedLocationQuery.builder()
                            .originalQuery(original)
                            .normalizedQuery(normalized)
                            .searchKeyword(left)
                            .locationQuery(right)
                            .placeCategory(null)
                            .searchIntent(SearchIntent.LOCALITY)
                            .build();
                }

                return ParsedLocationQuery.builder()
                    .originalQuery(original)
                    .normalizedQuery(normalized)
                    .searchKeyword(left)
                    .locationQuery(right)
                    .placeCategory(category)
                    .searchIntent(SearchIntent.POI_IN_LOCATION)
                    .build();
            }
        }

        // 3. Comma-separated format: e.g. "cơm tấm, Long Xuyên" or "Highlands Coffee, Lê Lợi"
        if (original.contains(",")) {
            String[] parts = original.split(",");
            if (parts.length >= 2) {
                String left = parts[0].trim();
                String right = parts[parts.length - 1].trim();
                if (!left.isBlank() && right.length() >= 2) {
                    String leftNorm = normalize(left);
                    String category = resolveCategoryFromText(leftNorm);

                    // If left is an administrative region (e.g. "Lâm Đồng", "Quận 1", "Tỉnh Lâm Đồng"),
                    // it is not a POI. Classify as LOCALITY rather than searching for an administrative unit inside a locality.
                    if (isAdministrativeLocality(left, leftNorm)) {
                        return ParsedLocationQuery.builder()
                                .originalQuery(original)
                                .normalizedQuery(normalized)
                                .searchKeyword(left)
                                .locationQuery(right)
                                .placeCategory(null)
                                .searchIntent(SearchIntent.LOCALITY)
                                .build();
                    }

                    return ParsedLocationQuery.builder()
                            .originalQuery(original)
                            .normalizedQuery(normalized)
                            .searchKeyword(left)
                            .locationQuery(right)
                            .placeCategory(category)
                            .searchIntent(SearchIntent.POI_IN_LOCATION)
                            .build();
                }
            }
        }

        // 4. Exact generic category or dish check (e.g. "cơm tấm", "quán cà phê", "khách sạn", "nhà hàng")
        String detectedCategory = resolveCategoryFromText(normalized);
        if (detectedCategory != null && isGenericCategoryWord(normalized)) {
            return ParsedLocationQuery.builder()
                    .originalQuery(original)
                    .normalizedQuery(normalized)
                    .searchKeyword(original)
                    .locationQuery(null)
                    .placeCategory(detectedCategory)
                    .searchIntent(SearchIntent.GENERIC_POI)
                    .build();
        }

        // 5. Implicit compound pattern: [Service/Category Prefix] + [Location] (e.g. "cơm tấm Long Xuyên", "cafe Đà Lạt")
        for (CategoryPrefix cp : CATEGORY_PREFIXES) {
            String prefixWithSpace = cp.normalizedPrefix() + " ";
            if (normalized.startsWith(prefixWithSpace)) {
                int prefixWordCount = cp.normalizedPrefix().split("\\s+").length;
                String[] origWords = original.split("\\s+");

                if (origWords.length > prefixWordCount) {
                    StringBuilder kwBuilder = new StringBuilder();
                    for (int i = 0; i < prefixWordCount; i++) {
                        if (i > 0) kwBuilder.append(" ");
                        kwBuilder.append(origWords[i]);
                    }
                    String keyword = kwBuilder.toString();

                    StringBuilder locBuilder = new StringBuilder();
                    for (int i = prefixWordCount; i < origWords.length; i++) {
                        if (locBuilder.length() > 0) locBuilder.append(" ");
                        locBuilder.append(origWords[i]);
                    }
                    String location = locBuilder.toString();

                    if (location.length() >= 2) {
                        String remainderNorm = normalize(location);
                        if (!isGenericCategoryWord(remainderNorm) && !isFoodModifier(remainderNorm)) {
                            return ParsedLocationQuery.builder()
                                    .originalQuery(original)
                                    .normalizedQuery(normalized)
                                    .searchKeyword(keyword)
                                    .locationQuery(location)
                                    .placeCategory(cp.category())
                                    .searchIntent(SearchIntent.POI_IN_LOCATION)
                                    .build();
                        }
                    }
                }
            }
        }

        // 6. Explicit administrative locality prefix (e.g. "Thành phố Long Xuyên", "Quận 1", "Tỉnh Lâm Đồng")
        Matcher adminMatcher = ADMINISTRATIVE_PREFIX_PATTERN.matcher(original);
        if (adminMatcher.matches()) {
            return ParsedLocationQuery.builder()
                    .originalQuery(original)
                    .normalizedQuery(normalized)
                    .searchKeyword(original)
                    .locationQuery(original)
                    .placeCategory(null)
                    .searchIntent(SearchIntent.LOCALITY)
                    .build();
        }

        // 7. Short standalone queries without service keywords default to Locality or Specific Place
        if (isLikelyLocalityOrLandmark(normalized)) {
            return ParsedLocationQuery.builder()
                    .originalQuery(original)
                    .normalizedQuery(normalized)
                    .searchKeyword(original)
                    .locationQuery(original)
                    .placeCategory(null)
                    .searchIntent(SearchIntent.LOCALITY)
                    .build();
        }

        // 8. Default fallback: Specific place or general search query
        return ParsedLocationQuery.builder()
                .originalQuery(original)
                .normalizedQuery(normalized)
                .searchKeyword(original)
                .locationQuery(null)
                .placeCategory(detectedCategory)
                .searchIntent(SearchIntent.SPECIFIC_PLACE)
                .build();
    }

    private boolean isAdministrativeLocality(String raw, String normalized) {
        if (raw == null || normalized == null) return false;
        if (ADMINISTRATIVE_PREFIX_PATTERN.matcher(raw).matches()) {
            return true;
        }
        if (KNOWN_ADMINISTRATIVE_REGIONS.contains(normalized)) {
            return true;
        }
        // Strip common administrative words if present
        String stripped = normalized.replaceAll("^(thanh pho|tp\\.?|tinh|quan|huyen|thi xa|thi tran|phuong|xa)\\s+", "").trim();
        return KNOWN_ADMINISTRATIVE_REGIONS.contains(stripped);
    }

    private String resolveCategoryFromText(String normalizedText) {
        for (CategoryPrefix cp : CATEGORY_PREFIXES) {
            if (normalizedText.equals(cp.normalizedPrefix()) ||
                    normalizedText.startsWith(cp.normalizedPrefix() + " ") ||
                    normalizedText.endsWith(" " + cp.normalizedPrefix()) ||
                    normalizedText.contains(" " + cp.normalizedPrefix() + " ")) {
                return cp.category();
            }
        }
        return null;
    }

    private boolean isGenericCategoryWord(String normalized) {
        for (CategoryPrefix cp : CATEGORY_PREFIXES) {
            if (normalized.equals(cp.normalizedPrefix())) {
                return true;
            }
        }
        return normalized.equals("an uong") || normalized.equals("am thuc") || normalized.equals("dia diem");
    }

    private boolean isLikelyLocalityOrLandmark(String normalized) {
        int wordCount = normalized.split("\\s+").length;
        if (wordCount > 4) {
            return false;
        }
        // If it doesn't contain any service/commercial prefix, treat as place
        for (CategoryPrefix cp : CATEGORY_PREFIXES) {
            if (normalized.startsWith(cp.normalizedPrefix() + " ") || normalized.equals(cp.normalizedPrefix())) {
                return false;
            }
        }
        return true;
    }

    private static final Set<String> FOOD_MODIFIERS = Set.of(
            "tam", "ga", "bo", "suon", "nieu", "rang", "cha", "dau", "rieu", "ca",
            "vit", "heo", "nam", "chay", "nuong", "chien", "xao", "kho", "hap", "luoc",
            "thap cam", "dac biet", "chua cay", "hai san", "cay", "trung", "nuoc",
            "mam", "muoi", "chao", "thit", "trung cut", "xoi"
    );

    private boolean isFoodModifier(String normalized) {
        return FOOD_MODIFIERS.contains(normalized);
    }

    public static String normalize(String input) {
        if (input == null || input.isBlank()) {
            return "";
        }
        String s = input.trim().toLowerCase(Locale.ROOT);
        s = s.replace("đ", "d").replace("Đ", "d");
        s = Normalizer.normalize(s, Normalizer.Form.NFD);
        s = s.replaceAll("\\p{M}", "");
        return s.replaceAll("\\s+", " ").trim();
    }
}
