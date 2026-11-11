package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.service.PlaceNormalizationService;
import Travel_Planner.Travel_Planner.service.impl.PlaceNormalizationServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

public class PlaceNormalizationServiceTest {

    private PlaceNormalizationService normalizationService;

    @BeforeEach
    void setUp() {
        normalizationService = new PlaceNormalizationServiceImpl();
    }

    @Test
    @DisplayName("Vietnamese text normalization strips diacritics, lowercase and removes special characters")
    void testNormalizeText() {
        assertEquals("chua mot cot", normalizationService.normalizeText("Chùa Một Cột"));
        assertEquals("ho hoan kiem pho co ha noi", normalizationService.normalizeText("Hồ Hoàn Kiếm & Phố Cổ Hà Nội"));
        assertEquals("ba na hills da nang", normalizationService.normalizeText("Bà Nà Hills, Đà Nẵng!"));
        assertEquals("dinh fansipan", normalizationService.normalizeText("Đỉnh Fansipan"));
        assertEquals("", normalizationService.normalizeText("   "));
        assertEquals("", normalizationService.normalizeText(null));
    }

    @Test
    @DisplayName("Address normalization standardizes common Vietnamese city and district abbreviations")
    void testNormalizeAddress() {
        String addr1 = normalizationService.normalizeAddress("123 Nguyễn Huệ, P. Bến Nghé, Q.1, TP.HCM");
        assertTrue(addr1.contains("Quận 1"));
        assertTrue(addr1.contains("Phường Bến Nghé"));
        assertTrue(addr1.contains("TP. Hồ Chí Minh"));

        String addr2 = normalizationService.normalizeAddress("58 Quốc Tử Giám, Đống Đa, TP Hà Nội");
        assertTrue(addr2.contains("Hà Nội"));

        String addr3 = normalizationService.normalizeAddress("Bà Nà, TP. Đà Nẵng");
        assertTrue(addr3.contains("Đà Nẵng"));
    }

    @Test
    @DisplayName("Protected compound place names are detected and protected from corruption")
    void testProtectedCompoundNames() {
        assertTrue(normalizationService.isProtectedCompoundName("Hồ Hoàn Kiếm"));
        assertTrue(normalizationService.isProtectedCompoundName("Vịnh Hạ Long"));
        assertTrue(normalizationService.isProtectedCompoundName("Bà Nà Hills"));
        assertTrue(normalizationService.isProtectedCompoundName("Đỉnh Fansipan"));
        assertTrue(normalizationService.isProtectedCompoundName("Chùa Một Cột"));

        assertFalse(normalizationService.isProtectedCompoundName("Quán cơm bình dân"));
        assertFalse(normalizationService.isProtectedCompoundName("Khách sạn Ánh Dương"));
    }

    @Test
    @DisplayName("Distinct branches of the same chain business are separated and NOT merged")
    void testDifferentBranchesNotMerged() {
        // Same chain: "Highlands Coffee", but different locations > 100m away
        boolean different1 = normalizationService.isDifferentBranch(
                "Highlands Coffee - Nhà Hát Lớn",
                "Highlands Coffee - Hàm Cá Mập",
                "1 Tràng Tiền, Hoàn Kiếm",
                "1 Đinh Tiên Hoàng, Hoàn Kiếm",
                450.0 // 450 meters apart
        );
        assertTrue(different1, "Chain branches 450m apart must be treated as different branches");

        // Same chain brand at different street numbers even if nearby
        boolean different2 = normalizationService.isDifferentBranch(
                "Circle K",
                "Circle K",
                "12 Bát Đàn, Hoàn Kiếm",
                "45 Hàng Gai, Hoàn Kiếm",
                80.0
        );
        assertTrue(different2, "Chain branches with distinct street numbers must be treated as different branches");

        // Non-chain local store at same address/location
        boolean samePlace = normalizationService.isDifferentBranch(
                "Nhà sách Tiền Phong",
                "Nhà sách Tiền Phong",
                "175 Nguyễn Thái Học",
                "175 Nguyễn Thái Học",
                10.0
        );
        assertFalse(samePlace, "Same non-chain store at same address is not a different branch");
    }

    @Test
    @DisplayName("Deduplication matching confidence: Exact match and close proximity produces high confidence")
    void testHighConfidenceMatch() {
        Place existing = Place.builder()
                .placeId(10L)
                .name("Chùa Một Cột")
                .address("Ba Đình, Hà Nội")
                .latitude(new BigDecimal("21.0358000"))
                .longitude(new BigDecimal("105.8335000"))
                .category(PlaceCategory.ATTRACTION)
                .build();

        double confidence = normalizationService.calculateMatchConfidence(
                existing,
                "Chùa Một Cột (Hà Nội)",
                "Đội Cấn, Ba Đình, Hà Nội",
                new BigDecimal("21.0358100"), // ~1 meter apart
                new BigDecimal("105.8335200"),
                PlaceCategory.ATTRACTION
        );

        assertTrue(confidence >= 0.85, "Match confidence must be >= 0.85 for very close matching venue, actual: " + confidence);
    }

    @Test
    @DisplayName("Deduplication matching confidence: Distinct businesses near each other yield 0 confidence")
    void testDistinctBusinessesZeroConfidence() {
        Place existing = Place.builder()
                .placeId(20L)
                .name("Tiệm Vàng Mi Hồng")
                .address("306 Bùi Hữu Nghĩa, Bình Thạnh")
                .latitude(new BigDecimal("10.8012000"))
                .longitude(new BigDecimal("106.6975000"))
                .category(PlaceCategory.SHOPPING)
                .build();

        // A totally different business 15 meters away
        double confidence = normalizationService.calculateMatchConfidence(
                existing,
                "Quán Phở Hòa",
                "308 Bùi Hữu Nghĩa, Bình Thạnh",
                new BigDecimal("10.8012100"),
                new BigDecimal("106.6975200"),
                PlaceCategory.RESTAURANT
        );

        assertEquals(0.0, confidence, "Distinct nearby businesses must have 0.0 match confidence to prevent false merging");
    }

    @Test
    @DisplayName("Deduplication matching confidence: Locations > 300m apart yield 0 confidence")
    void testFarLocationsZeroConfidence() {
        Place existing = Place.builder()
                .placeId(30L)
                .name("Bảo tàng Chứng tích Chiến tranh")
                .address("28 Võ Văn Tần, Quận 3")
                .latitude(new BigDecimal("10.7794000"))
                .longitude(new BigDecimal("106.6923000"))
                .category(PlaceCategory.ATTRACTION)
                .build();

        double confidence = normalizationService.calculateMatchConfidence(
                existing,
                "Bảo tàng Chứng tích Chiến tranh",
                "Quận 3, TP. Hồ Chí Minh",
                new BigDecimal("10.7850000"), // ~700 meters away
                new BigDecimal("106.6990000"),
                PlaceCategory.ATTRACTION
        );

        assertEquals(0.0, confidence, "Locations > 300m apart must yield 0 confidence");
    }

    @Test
    @DisplayName("Category mapping correctly categorizes provider raw types into canonical PlaceCategory")
    void testMapProviderCategory() {
        assertEquals(PlaceCategory.ATTRACTION, normalizationService.mapProviderCategory("tourism", "museum"));
        assertEquals(PlaceCategory.ATTRACTION, normalizationService.mapProviderCategory("historic", "monument"));
        assertEquals(PlaceCategory.RESTAURANT, normalizationService.mapProviderCategory("amenity", "restaurant"));
        assertEquals(PlaceCategory.CAFE, normalizationService.mapProviderCategory("amenity", "cafe"));
        assertEquals(PlaceCategory.HOTEL, normalizationService.mapProviderCategory("tourism", "hotel"));
        assertEquals(PlaceCategory.SHOPPING, normalizationService.mapProviderCategory("shop", "supermarket"));
        assertEquals(PlaceCategory.ENTERTAINMENT, normalizationService.mapProviderCategory("leisure", "theme_park"));
        assertEquals(PlaceCategory.OTHER, normalizationService.mapProviderCategory("unknown", "misc"));
    }
}

