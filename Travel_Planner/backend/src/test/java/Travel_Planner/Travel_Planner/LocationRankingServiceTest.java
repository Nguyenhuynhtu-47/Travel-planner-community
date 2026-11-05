package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class LocationRankingServiceTest {

    private LocationRankingServiceImpl rankingService;

    @BeforeEach
    void setUp() {
        rankingService = new LocationRankingServiceImpl();
    }

    @Test
    @DisplayName("City search prioritizes administrative city entity over a restaurant containing the city name")
    void rankResults_citySearch_prioritizesCityOverEatery() {
        LocationSearchResultResponse city = LocationSearchResultResponse.builder()
                .placeId("city_vungtau")
                .name("Vũng Tàu")
                .formattedAddress("Thành phố Vũng Tàu, Bà Rịa - Vũng Tàu, Việt Nam")
                .latitude(10.3460)
                .longitude(107.0843)
                .type("city")
                .category("place")
                .importance(0.65)
                .build();

        LocationSearchResultResponse eatery = LocationSearchResultResponse.builder()
                .placeId("eatery_vungtau")
                .name("Cơm Tấm Vũng Tàu")
                .formattedAddress("Đường Nguyễn Thị Minh Khai, Quận 1, TP.HCM, Việt Nam")
                .latitude(10.7769)
                .longitude(106.7009)
                .type("restaurant")
                .category("amenity")
                .importance(0.10)
                .build();

        // Raw list has eatery first (like previous viewport-biased distance sorting)
        List<LocationSearchResultResponse> raw = List.of(eatery, city);

        List<LocationSearchResultResponse> ranked = rankingService.rankAndDeduplicate(
                "Vũng Tàu", raw, 10.7769, 106.7009, 10);

        assertFalse(ranked.isEmpty());
        assertEquals("Vũng Tàu", ranked.get(0).getName());
        assertEquals("city", ranked.get(0).getType());
    }

    @Test
    @DisplayName("Da Lat query prioritizes Da Lat city over local eatery 'Đà Lạt Ơi'")
    void rankResults_daLatSearch_prioritizesCityOverLocalCafe() {
        LocationSearchResultResponse city = LocationSearchResultResponse.builder()
                .placeId("city_dalat")
                .name("Đà Lạt")
                .formattedAddress("Thành phố Đà Lạt, Lâm Đồng, Việt Nam")
                .latitude(11.9404)
                .longitude(108.4583)
                .type("city")
                .category("place")
                .importance(0.60)
                .build();

        LocationSearchResultResponse cafe = LocationSearchResultResponse.builder()
                .placeId("cafe_dalatoi")
                .name("Đà Lạt Ơi")
                .formattedAddress("Phan Xích Long, Phú Nhuận, TP.HCM")
                .latitude(10.7981)
                .longitude(106.6912)
                .type("cafe")
                .category("amenity")
                .importance(0.05)
                .build();

        List<LocationSearchResultResponse> raw = List.of(cafe, city);

        List<LocationSearchResultResponse> ranked = rankingService.rankAndDeduplicate(
                "Đà Lạt", raw, 10.7981, 106.6912, 10);

        assertEquals("Đà Lạt", ranked.get(0).getName());
        assertEquals("city_dalat", ranked.get(0).getPlaceId());
    }

    @Test
    @DisplayName("Unaccented query 'vung tau' matches accented city name 'Vũng Tàu' at top rank")
    void rankResults_unaccentedQuery_ranksAccentedCityTop() {
        LocationSearchResultResponse city = LocationSearchResultResponse.builder()
                .placeId("city_vt")
                .name("Vũng Tàu")
                .formattedAddress("Bà Rịa - Vũng Tàu, Việt Nam")
                .latitude(10.3460)
                .longitude(107.0843)
                .type("city")
                .category("place")
                .importance(0.65)
                .build();

        List<LocationSearchResultResponse> raw = List.of(city);
        List<LocationSearchResultResponse> ranked = rankingService.rankAndDeduplicate(
                "vung tau", raw, null, null, 10);

        assertEquals(1, ranked.size());
        assertEquals("Vũng Tàu", ranked.get(0).getName());
    }

    @Test
    @DisplayName("POI search prioritizes exact matching bakery over generic entries")
    void rankResults_poiSearch_prioritizesExactPoiMatch() {
        LocationSearchResultResponse bakery = LocationSearchResultResponse.builder()
                .placeId("bakery_coixaygio")
                .name("Tiệm bánh Cối Xay Gió")
                .formattedAddress("Khu Hòa Bình, Phường 1, Đà Lạt")
                .latitude(11.9421)
                .longitude(108.4372)
                .type("bakery")
                .category("shop")
                .importance(0.35)
                .build();

        LocationSearchResultResponse street = LocationSearchResultResponse.builder()
                .placeId("street_coixaygio")
                .name("Đường Cối Xay Gió")
                .formattedAddress("Hà Nội")
                .latitude(21.0285)
                .longitude(105.8542)
                .type("residential")
                .category("highway")
                .importance(0.20)
                .build();

        List<LocationSearchResultResponse> raw = List.of(street, bakery);
        List<LocationSearchResultResponse> ranked = rankingService.rankAndDeduplicate(
                "Tiệm bánh Cối Xay Gió", raw, null, null, 10);

        assertEquals("Tiệm bánh Cối Xay Gió", ranked.get(0).getName());
    }

    @Test
    @DisplayName("Deduplication removes entries with same coordinate proximity and name")
    void rankResults_deduplicatesNearIdenticalEntries() {
        LocationSearchResultResponse entry1 = LocationSearchResultResponse.builder()
                .placeId("id_1")
                .name("Highlands Coffee")
                .formattedAddress("Lê Lợi, Quận 1, TP.HCM")
                .latitude(10.77312)
                .longitude(106.69911)
                .type("cafe")
                .category("amenity")
                .importance(0.3)
                .build();

        LocationSearchResultResponse entry2 = LocationSearchResultResponse.builder()
                .placeId("id_2")
                .name("Highlands Coffee")
                .formattedAddress("Lê Lợi, Bến Nghé, Quận 1")
                .latitude(10.77314) // ~2 meters away
                .longitude(106.69913)
                .type("cafe")
                .category("amenity")
                .importance(0.3)
                .build();

        List<LocationSearchResultResponse> raw = List.of(entry1, entry2);
        List<LocationSearchResultResponse> ranked = rankingService.rankAndDeduplicate(
                "Highlands Coffee", raw, null, null, 10);

        assertEquals(1, ranked.size());
    }

    @Test
    @DisplayName("Administrative query 'Lâm Đồng' ranks Tỉnh Lâm Đồng at top and rejects single-syllable partial matches like Hưng Lâm")
    void rankResults_lamDongSearch_prioritizesProvinceOverPartialVillageMatches() {
        LocationSearchResultResponse hungLam = LocationSearchResultResponse.builder()
                .placeId("hung_lam_id")
                .name("Hưng Lâm")
                .formattedAddress("Hưng Lâm, Xã Đông Hưng, Tỉnh An Giang, Việt Nam")
                .latitude(9.6743)
                .longitude(104.8964)
                .type("village")
                .category("village")
                .importance(0.15)
                .build();

        LocationSearchResultResponse phuLam = LocationSearchResultResponse.builder()
                .placeId("phu_lam_id")
                .name("Phú Lâm")
                .formattedAddress("Phú Lâm, Xã Đông Thái, Tỉnh An Giang, Việt Nam")
                .latitude(9.7347)
                .longitude(105.0530)
                .type("village")
                .category("village")
                .importance(0.15)
                .build();

        LocationSearchResultResponse tinhLamDong = LocationSearchResultResponse.builder()
                .placeId("tinh_lam_dong_id")
                .name("Tỉnh Lâm Đồng")
                .formattedAddress("Tỉnh Lâm Đồng, Việt Nam")
                .latitude(11.6615)
                .longitude(108.1335)
                .type("administrative")
                .category("administrative")
                .importance(0.54)
                .build();

        List<LocationSearchResultResponse> raw = List.of(hungLam, phuLam, tinhLamDong);
        List<LocationSearchResultResponse> ranked = rankingService.rankAndDeduplicate(
                "Lâm Đồng", raw, null, null, 10);

        assertFalse(ranked.isEmpty());
        assertEquals("Tỉnh Lâm Đồng", ranked.get(0).getName());
        assertEquals("tinh_lam_dong_id", ranked.get(0).getPlaceId());
    }
}

