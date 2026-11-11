package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class LocationDeduplicationTest {

    private LocationRankingServiceImpl rankingService;

    @BeforeEach
    void setUp() {
        rankingService = new LocationRankingServiceImpl();
    }

    @Test
    @DisplayName("Task 3.1: Same place from two different providers keeps only one result")
    void testSamePlaceTwoProviders_KeepsOne() {
        LocationSearchResultResponse fromLocationIq = LocationSearchResultResponse.builder()
                .placeId("liq_101")
                .name("Chợ Bến Thành")
                .formattedAddress("Đường Lê Lợi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh")
                .latitude(10.7725)
                .longitude(106.6980)
                .category("shop")
                .type("marketplace")
                .importance(0.8)
                .provider("LOCATION_IQ")
                .build();

        LocationSearchResultResponse fromHere = LocationSearchResultResponse.builder()
                .placeId("here_202")
                .name("Chợ Bến Thành")
                .formattedAddress("Đường Lê Lợi, Bến Thành, Quận 1, Hồ Chí Minh")
                .latitude(10.7726) // ~11 meters away
                .longitude(106.6981)
                .category("shop")
                .type("marketplace")
                .importance(0.7)
                .provider("HERE")
                .build();

        List<LocationSearchResultResponse> result = rankingService.rankAndDeduplicate(
                "Chợ Bến Thành",
                List.of(fromLocationIq, fromHere),
                null,
                null,
                10
        );

        assertNotNull(result);
        assertEquals(1, result.size(), "Duplicate place across providers within 110m must be merged into 1 result");
        assertEquals("liq_101", result.get(0).getPlaceId());
    }

    @Test
    @DisplayName("Task 3.2: Two different businesses located within < 110m are both kept")
    void testTwoDifferentBusinessesWithin110m_BothKept() {
        // Cafe and Pho shop 25 meters apart on same street
        LocationSearchResultResponse shopA = LocationSearchResultResponse.builder()
                .placeId("shop_a")
                .name("Highlands Coffee")
                .formattedAddress("12 Lê Lợi, Bến Nghé, Quận 1")
                .latitude(10.77250)
                .longitude(106.69800)
                .category("amenity")
                .type("cafe")
                .importance(0.7)
                .provider("LOCATION_IQ")
                .build();

        LocationSearchResultResponse shopB = LocationSearchResultResponse.builder()
                .placeId("shop_b")
                .name("Phở 24")
                .formattedAddress("14 Lê Lợi, Bến Nghé, Quận 1")
                .latitude(10.77265) // ~20m distance
                .longitude(106.69815)
                .category("amenity")
                .type("restaurant")
                .importance(0.7)
                .provider("LOCATION_IQ")
                .build();

        List<LocationSearchResultResponse> result = rankingService.rankAndDeduplicate(
                "Lê Lợi",
                List.of(shopA, shopB),
                null,
                null,
                10
        );

        assertNotNull(result);
        assertEquals(2, result.size(), "Two different businesses within 110m must NOT be merged; both must be kept");
        assertTrue(result.stream().anyMatch(r -> r.getName().equals("Highlands Coffee")));
        assertTrue(result.stream().anyMatch(r -> r.getName().equals("Phở 24")));
    }

    @Test
    @DisplayName("Task 3.3: Two results with same name but distinct addresses are not automatically merged")
    void testSameNameDistinctAddresses_NotMerged() {
        // Chain stores with identical name within 80m of each other on distinct street corners
        LocationSearchResultResponse branch1 = LocationSearchResultResponse.builder()
                .placeId("ck_1")
                .name("Circle K")
                .formattedAddress("12 Đường Lê Lợi, Phường Bến Nghé, Quận 1")
                .latitude(10.7725)
                .longitude(106.6980)
                .category("shop")
                .type("convenience")
                .importance(0.6)
                .provider("LOCATION_IQ")
                .build();

        LocationSearchResultResponse branch2 = LocationSearchResultResponse.builder()
                .placeId("ck_2")
                .name("Circle K")
                .formattedAddress("45 Đường Pasteur, Phường Bến Nghé, Quận 1")
                .latitude(10.7728) // ~40m away
                .longitude(106.6983)
                .category("shop")
                .type("convenience")
                .importance(0.6)
                .provider("LOCATION_IQ")
                .build();

        List<LocationSearchResultResponse> result = rankingService.rankAndDeduplicate(
                "Circle K",
                List.of(branch1, branch2),
                null,
                null,
                10
        );

        assertNotNull(result);
        assertEquals(2, result.size(), "Same-name branches with distinct street addresses must NOT be merged");
    }

    @Test
    @DisplayName("Task 3.4: Same provider identity (placeId) is deduplicated immediately")
    void testSameProviderIdentity_Deduplicated() {
        LocationSearchResultResponse item1 = LocationSearchResultResponse.builder()
                .placeId("osm_123456")
                .name("Nhà Thờ Đức Bà")
                .formattedAddress("1 Công xã Paris, Bến Nghé, Quận 1")
                .latitude(10.7798)
                .longitude(106.6990)
                .category("tourism")
                .type("attraction")
                .provider("LOCATION_IQ")
                .build();

        LocationSearchResultResponse item2 = LocationSearchResultResponse.builder()
                .placeId("osm_123456") // Same placeId
                .name("Nhà Thờ Đức Bà Sài Gòn")
                .formattedAddress("Công xã Paris, Quận 1")
                .latitude(10.7798)
                .longitude(106.6990)
                .category("tourism")
                .type("attraction")
                .provider("LOCATION_IQ")
                .build();

        List<LocationSearchResultResponse> result = rankingService.rankAndDeduplicate(
                "Nhà Thờ Đức Bà",
                List.of(item1, item2),
                null,
                null,
                10
        );

        assertNotNull(result);
        assertEquals(1, result.size(), "Same provider placeId must be deduplicated to 1 result");
        assertEquals("osm_123456", result.get(0).getPlaceId());
    }

    @Test
    @DisplayName("Task 3.5: External result matching canonical Place prioritizes canonical SYSTEM Place")
    void testExternalMatchesCanonicalPlace_PrioritizesSystemPlace() {
        LocationSearchResultResponse externalResult = LocationSearchResultResponse.builder()
                .placeId("ext_999")
                .name("Dinh Độc Lập")
                .formattedAddress("135 Nam Kỳ Khởi Nghĩa, Bến Thành, Quận 1")
                .latitude(10.7769)
                .longitude(106.6953)
                .category("attraction")
                .type("historic")
                .importance(0.8)
                .provider("LOCATION_IQ")
                .build();

        LocationSearchResultResponse canonicalPlace = LocationSearchResultResponse.builder()
                .placeId("place_1")
                .name("Dinh Độc Lập")
                .formattedAddress("135 Nam Kỳ Khởi Nghĩa, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh")
                .latitude(10.7770)
                .longitude(106.6954)
                .category("HISTORICAL")
                .type("place")
                .importance(1.0)
                .provider("SYSTEM")
                .build();

        // Pass external first, canonical second to verify canonical replaces external
        List<LocationSearchResultResponse> result = rankingService.rankAndDeduplicate(
                "Dinh Độc Lập",
                List.of(externalResult, canonicalPlace),
                null,
                null,
                10
        );

        assertNotNull(result);
        assertEquals(1, result.size(), "Duplicate between canonical Place and external provider must keep 1 result");
        assertEquals("SYSTEM", result.get(0).getProvider(), "Canonical SYSTEM place must be prioritized over external result");
        assertEquals("place_1", result.get(0).getPlaceId());
    }
}

