package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.location.GeographicTargetArea;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.service.GeographicFilterService;
import Travel_Planner.Travel_Planner.service.impl.GeographicFilterServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("Geographic Filter Service Unit Tests")
class GeographicFilterServiceTest {

    private GeographicFilterService filterService;
    private GeographicTargetArea longXuyenTarget;

    @BeforeEach
    void setUp() {
        filterService = new GeographicFilterServiceImpl();

        // Long Xuyên, An Giang target area
        // Center: 10.37196, 105.41491
        // Bbox: [10.30307, 10.43969, 105.36051, 105.49606]
        longXuyenTarget = GeographicTargetArea.builder()
                .queryName("Long Xuyên")
                .resolvedName("Thành phố Long Xuyên, Long Xuyên, Phường Long Xuyên, Tỉnh An Giang, Việt Nam")
                .centerLat(10.37196)
                .centerLon(105.41491)
                .boundingBox(List.of(10.30307, 10.43969, 105.36051, 105.49606))
                .maxRadiusKm(15.0)
                .targetType("city")
                .stateOrProvince("Tỉnh An Giang")
                .build();
    }

    @Test
    @DisplayName("Keeps candidate within target area and same province")
    void shouldKeepCandidateWithinTargetArea() {
        LocationSearchResultResponse localPlace = LocationSearchResultResponse.builder()
                .placeId("lx_1")
                .name("Cơm Hai Thuế")
                .formattedAddress("245/3, Lương Văn Cù, Long Xuyên, Tỉnh An Giang, Việt Nam")
                .latitude(10.3799)
                .longitude(105.4424)
                .category("restaurant")
                .provider("LOCATION_IQ")
                .build();

        List<LocationSearchResultResponse> passed = filterService.filter(List.of(localPlace), longXuyenTarget);

        assertThat(passed).hasSize(1);
        assertThat(passed.get(0).getName()).isEqualTo("Cơm Hai Thuế");
    }

    @Test
    @DisplayName("Discards candidate 175km away in TP.HCM even if name contains 'Long Xuyên'")
    void shouldDiscardDistantCandidateFromDifferentCity() {
        LocationSearchResultResponse saigonPlace = LocationSearchResultResponse.builder()
                .placeId("sg_1")
                .name("Long Xuyên Quán 2 - Cơm Tấm Bánh Tằm Bì")
                .formattedAddress("Đường số 45, Phường Khánh Hội, Thành phố Thủ Đức, Thành phố Hồ Chí Minh, Việt Nam")
                .latitude(10.7592)
                .longitude(106.6994)
                .category("restaurant")
                .provider("LOCATION_IQ")
                .build();

        List<LocationSearchResultResponse> passed = filterService.filter(List.of(saigonPlace), longXuyenTarget);

        assertThat(passed).isEmpty();
    }

    @Test
    @DisplayName("Discards candidate with NaN or null coordinates")
    void shouldDiscardCandidateWithInvalidCoordinates() {
        LocationSearchResultResponse invalidCoords = LocationSearchResultResponse.builder()
                .placeId("inv_1")
                .name("Quán ảo")
                .formattedAddress("Long Xuyên, An Giang")
                .latitude(Double.NaN)
                .longitude(105.44)
                .build();

        List<LocationSearchResultResponse> passed = filterService.filter(List.of(invalidCoords), longXuyenTarget);

        assertThat(passed).isEmpty();
    }

    @Test
    @DisplayName("Discards candidate with conflicting province name beyond 15km")
    void shouldDiscardCrossProvinceMismatch() {
        // Place coordinates around 25km away but in Can Tho with explicit Can Tho in address
        LocationSearchResultResponse canThoPlace = LocationSearchResultResponse.builder()
                .placeId("ct_1")
                .name("Quán Cơm Cần Thơ")
                .formattedAddress("Quốc lộ 91, Quận Ô Môn, Thành phố Cần Thơ, Việt Nam")
                .latitude(10.1200)
                .longitude(105.6200)
                .build();

        List<LocationSearchResultResponse> passed = filterService.filter(List.of(canThoPlace), longXuyenTarget);

        assertThat(passed).isEmpty();
    }

    @Test
    @DisplayName("Deduplicates candidates with identical coordinates")
    void shouldDeduplicateIdenticalCoordinates() {
        LocationSearchResultResponse item1 = LocationSearchResultResponse.builder()
                .placeId("p_1")
                .name("Quán A")
                .formattedAddress("Long Xuyên, An Giang")
                .latitude(10.375)
                .longitude(105.435)
                .build();

        LocationSearchResultResponse item2 = LocationSearchResultResponse.builder()
                .placeId("p_2")
                .name("Quán A Branch")
                .formattedAddress("Long Xuyên, An Giang")
                .latitude(10.375)
                .longitude(105.435)
                .build();

        List<LocationSearchResultResponse> passed = filterService.filter(List.of(item1, item2), longXuyenTarget);

        assertThat(passed).hasSize(1);
    }
}

