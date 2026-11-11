package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.service.AdministrativeAreaService;
import Travel_Planner.Travel_Planner.service.LocationRankingService;
import Travel_Planner.Travel_Planner.service.PlaceService;
import Travel_Planner.Travel_Planner.service.impl.LocationServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class LocationSearchAndFilteringTest {

    private static final Set<String> QUARANTINED_CODES = Set.of(
            "07294", "07375", "07399", "07444", "07840", "09193",
            "09292", "09313", "09319", "09454", "09475", "09496"
    );

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private AdministrativeAreaMigrationRunner adminMigrationRunner;

    @Autowired
    private AdministrativeAreaRepository administrativeAreaRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private AdministrativeAreaService administrativeAreaService;

    @Autowired
    private PlaceService placeService;

    @Autowired
    private LocationServiceImpl locationService;

    @Autowired
    private LocationRankingService locationRankingService;

    private MockMvc mockMvc;
    private final List<Place> testPlaces = new ArrayList<>();

    private AdministrativeArea hcmProvince;
    private AdministrativeArea benThanhWard;
    private AdministrativeArea daNangProvince;

    @BeforeEach
    void setUp() throws Exception {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        // Ensure administrative catalog is imported
        adminMigrationRunner.migrateAndImport();
        locationService.clearCaches();
        administrativeAreaService.clearCache();

        hcmProvince = administrativeAreaRepository.findByCode("79").orElse(null);
        benThanhWard = administrativeAreaRepository.findByCode("26743").orElse(null);
        daNangProvince = administrativeAreaRepository.findByCode("48").orElse(null);

        // Seed controlled test places for search, filtering & spatial tests
        Place p1 = placeRepository.save(Place.builder()
                .name("Chợ Bến Thành Thử Nghiệm")
                .normalizedName("cho ben thanh thu nghiem")
                .address("Đường Lê Lợi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh")
                .latitude(new BigDecimal("10.7725000"))
                .longitude(new BigDecimal("106.6980000"))
                .category(PlaceCategory.SHOPPING)
                .status(PlaceStatus.ACTIVE)
                .administrativeArea(benThanhWard)
                .build());
        testPlaces.add(p1);

        Place p2 = placeRepository.save(Place.builder()
                .name("Địa Điểm Sài Gòn Thử Nghiệm")
                .normalizedName("dia diem sai gon thu nghiem")
                .address("Trung tâm TP. Hồ Chí Minh")
                .latitude(new BigDecimal("10.7769000"))
                .longitude(new BigDecimal("106.7009000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .administrativeArea(hcmProvince)
                .build());
        testPlaces.add(p2);

        // Ambiguous Place: Bà Nà Hills with administrativeArea = NULL
        Place p3 = placeRepository.save(Place.builder()
                .name("Bà Nà Hills Thử Nghiệm")
                .normalizedName("ba na hills thu nghiem")
                .address("Thôn An Sơn, Xã Hòa Ninh, Huyện Hòa Vang, Thành phố Đà Nẵng")
                .latitude(new BigDecimal("15.9989000"))
                .longitude(new BigDecimal("107.9959000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .administrativeArea(null)
                .build());
        testPlaces.add(p3);

        // Ambiguous Place: Bán Đảo Sơn Trà with administrativeArea = NULL
        Place p4 = placeRepository.save(Place.builder()
                .name("Bán Đảo Sơn Trà Thử Nghiệm")
                .normalizedName("ban dao son tra thu nghiem")
                .address("Bán đảo Sơn Trà, Quận Sơn Trà, Thành phố Đà Nẵng")
                .latitude(new BigDecimal("16.1158000"))
                .longitude(new BigDecimal("108.2750000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .administrativeArea(null)
                .build());
        testPlaces.add(p4);
    }

    @AfterEach
    void tearDown() {
        for (Place p : testPlaces) {
            try {
                if (p.getPlaceId() != null) {
                    placeRepository.deleteById(p.getPlaceId());
                }
            } catch (Exception ignored) {
            }
        }
        testPlaces.clear();
    }

    @Test
    @DisplayName("Admin Search: Exact code query returns matching administrative area")
    void testAdministrativeAreaSearch_ExactCode() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/search")
                        .param("q", "01")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$[0].code", is("01")))
                .andExpect(jsonPath("$[0].name", containsString("Hà Nội")));
    }

    @Test
    @DisplayName("Admin Search: Normalized diacritic-insensitive search works for provinces and communes")
    void testAdministrativeAreaSearch_NormalizedDiacritics() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/search")
                        .param("q", "da nang")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$[0].name", containsString("Đà Nẵng")));
    }

    @Test
    @DisplayName("Quarantine Invariant: All 12 quarantined Northern Bắc Ninh codes are excluded from search")
    void testAdministrativeAreaSearch_QuarantinedExclusion() throws Exception {
        for (String code : QUARANTINED_CODES) {
            mockMvc.perform(get("/api/administrative-areas/search")
                            .param("q", code)
                            .contentType(MediaType.APPLICATION_JSON))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$", hasSize(0)));
        }
    }

    @Test
    @DisplayName("Quarantine Invariant: Children of Bắc Ninh province (24) exclude quarantined units")
    void testAdministrativeAreaChildren_QuarantinedExclusion() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/24/children")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$[*].code", not(hasItem(anyOf(
                        is("07294"), is("07375"), is("07399"), is("07444"),
                        is("07840"), is("09193"), is("09292"), is("09313"),
                        is("09319"), is("09454"), is("09475"), is("09496")
                )))));
    }

    @Test
    @DisplayName("Place Filtering: Province filter matches places in province and child communes/wards")
    void testPlaceFiltering_ProvinceLevelExpansion() throws Exception {
        // TP. Hồ Chí Minh code: 79
        mockMvc.perform(get("/api/places")
                        .param("administrativeAreaCode", "79")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(greaterThanOrEqualTo(2))))
                .andExpect(jsonPath("$.content[*].name", hasItem(containsString("Bến Thành"))))
                .andExpect(jsonPath("$.content[*].name", hasItem(containsString("Sài Gòn"))));
    }

    @Test
    @DisplayName("Place Filtering: Commune/ward filter matches only places in that specific ward")
    void testPlaceFiltering_CommuneLevel() throws Exception {
        // Phường Bến Thành code: 26743
        mockMvc.perform(get("/api/places")
                        .param("administrativeAreaCode", "26743")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name", containsString("Bến Thành")));
    }

    @Test
    @DisplayName("Place Filtering: Filtering with a quarantined code returns empty page")
    void testPlaceFiltering_QuarantinedCode_ReturnsEmpty() throws Exception {
        mockMvc.perform(get("/api/places")
                        .param("administrativeAreaCode", "07294")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)))
                .andExpect(jsonPath("$.totalElements", is(0)));
    }

    @Test
    @DisplayName("Place Filtering: Ambiguous places are excluded when filtering by administrativeAreaCode")
    void testPlaceFiltering_AmbiguousPlacesIsolation() throws Exception {
        // Query Đà Nẵng (48) - Ambiguous places have adminArea = null, so they must NOT appear
        mockMvc.perform(get("/api/places")
                        .param("administrativeAreaCode", "48")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[*].name", not(hasItem(containsString("Bà Nà Hills")))))
                .andExpect(jsonPath("$.content[*].name", not(hasItem(containsString("Sơn Trà")))));

        // But direct keyword search WITHOUT administrative filter matches ambiguous places
        mockMvc.perform(get("/api/places")
                        .param("keyword", "Bà Nà Hills Thử Nghiệm")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name", containsString("Bà Nà Hills")))
                .andExpect(jsonPath("$.content[0].administrativeArea", nullValue()));
    }

    @Test
    @DisplayName("Place Filtering: Endpoint /api/administrative-areas/{code}/places returns places")
    void testAdministrativeAreaPlacesEndpoint() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/79/places")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(greaterThanOrEqualTo(2))));

        // Quarantined area code returns empty
        mockMvc.perform(get("/api/administrative-areas/07294/places")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)));
    }

    @Test
    @DisplayName("Place Filtering: Combined filter with category and keyword")
    void testPlaceFiltering_CombinedCategoryKeyword() throws Exception {
        mockMvc.perform(get("/api/places")
                        .param("administrativeAreaCode", "79")
                        .param("category", "SHOPPING")
                        .param("keyword", "Bến Thành")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name", containsString("Bến Thành")));
    }

    @Test
    @DisplayName("Internal Catalog: Priority 1 returns canonical places with SYSTEM provider and 1.0 importance")
    void testLocationSearch_InternalCanonicalPriority() {
        List<LocationSearchResultResponse> results = locationService.searchInternalCatalog("Chợ Bến Thành Thử Nghiệm", 5);
        assertNotNull(results);
        assertFalse(results.isEmpty());

        LocationSearchResultResponse first = results.get(0);
        assertEquals("SYSTEM", first.getProvider());
        assertEquals(1.0, first.getImportance());
        assertEquals("place", first.getType());
        assertTrue(first.getName().contains("Bến Thành"));
    }

    @Test
    @DisplayName("Internal Catalog: Priority 2 returns administrative areas excluding quarantined ones")
    void testLocationSearch_InternalAdministrativeAreas() {
        List<LocationSearchResultResponse> results = locationService.searchInternalCatalog("Hà Nội", 5);
        assertNotNull(results);
        assertFalse(results.isEmpty());

        boolean hasAdmin = results.stream().anyMatch(r -> "administrative".equals(r.getType()) && "SYSTEM".equals(r.getProvider()));
        assertTrue(hasAdmin, "Expected administrative area in internal catalog results");

        // Quarantined code must never be returned
        for (String qCode : QUARANTINED_CODES) {
            List<LocationSearchResultResponse> qResults = locationService.searchInternalCatalog(qCode, 5);
            boolean containsQ = qResults.stream().anyMatch(r -> r.getPlaceId() != null && r.getPlaceId().contains(qCode));
            assertFalse(containsQ, "Quarantined code " + qCode + " must not be returned by searchInternalCatalog");
        }
    }

    @Test
    @DisplayName("Spatial Discovery: searchPlaces with radius returns nearby places ordered by distance")
    void testSpatialDiscovery_RadiusFiltering() {
        // Coordinates near Chợ Bến Thành: 10.7725, 106.6980
        Page<PlaceResponse> page = placeService.searchPlaces(
                null,
                null,
                10.7725,
                106.6980,
                5.0, // 5 km radius
                PageRequest.of(0, 10)
        );

        assertNotNull(page);
        assertFalse(page.getContent().isEmpty());
        // Closest place should be Chợ Bến Thành Thử Nghiệm
        PlaceResponse first = page.getContent().get(0);
        assertNotNull(first.getLatitude());
        assertNotNull(first.getLongitude());
        assertTrue(first.getName().contains("Bến Thành"));
    }

    @Test
    @DisplayName("POI Ranking: Administrative boundary is penalized and does not displace real POI in POI query")
    void testPoiQueryRanking_AdministrativePenalizedAndNoSystemBoost() {
        LocationSearchResultResponse adminBoundary = LocationSearchResultResponse.builder()
                .placeId("admin_89")
                .name("Tỉnh An Giang")
                .formattedAddress("Tỉnh An Giang, Việt Nam")
                .latitude(10.5)
                .longitude(105.1)
                .category("boundary")
                .type("administrative")
                .importance(0.8)
                .provider("SYSTEM")
                .isLocalityFallback(true)
                .build();

        LocationSearchResultResponse poiItem = LocationSearchResultResponse.builder()
                .placeId("osm_12345")
                .name("Quán Cơm Tấm Cây Điệp Long Xuyên")
                .formattedAddress("Đường Lý Tự Trọng, Mỹ Long, Long Xuyên, An Giang")
                .latitude(10.38)
                .longitude(105.43)
                .category("food")
                .type("restaurant")
                .importance(0.6)
                .provider("LOCATION_IQ")
                .isLocalityFallback(false)
                .build();

        List<LocationSearchResultResponse> ranked = locationRankingService.rankAndDeduplicate(
                "cơm tấm Long Xuyên",
                List.of(adminBoundary, poiItem),
                null,
                null,
                5
        );

        assertNotNull(ranked);
        assertEquals(2, ranked.size());
        assertEquals("Quán Cơm Tấm Cây Điệp Long Xuyên", ranked.get(0).getName(),
                "Real restaurant POI must rank ahead of administrative boundary in POI query");
        assertEquals("Tỉnh An Giang", ranked.get(1).getName());
    }

    @Test
    @DisplayName("Spatial Discovery: Radius validation throws BadRequestException for radius <= 0 or > 500")
    void testSpatialDiscovery_RadiusValidation() {
        assertThrows(BadRequestException.class, () -> placeService.searchPlaces(
                null, null, null, null, 10.77, 106.69, -1.0, PageRequest.of(0, 10)
        ));

        assertThrows(BadRequestException.class, () -> placeService.searchPlaces(
                null, null, null, null, 10.77, 106.69, 501.0, PageRequest.of(0, 10)
        ));

        assertThrows(BadRequestException.class, () -> placeService.searchPlaces(
                null, null, null, null, null, 106.69, 10.0, PageRequest.of(0, 10)
        ));
    }

    @Test
    @DisplayName("Spatial Discovery: Polar coordinate search clamps bounds safely without division by zero")
    void testSpatialDiscovery_PolarCoordinateClamping() {
        // Query near North Pole (lat=89.9999) must not throw ArithmeticException / division by zero
        Page<PlaceResponse> page = placeService.searchPlaces(
                null, null, null, null, 89.9999, 106.69, 10.0, PageRequest.of(0, 10)
        );
        assertNotNull(page);
    }

    @Test
    @DisplayName("Spatial API: GET /api/places with negative radius returns 400 Bad Request")
    void testSpatialEndpoint_InvalidRadiusThrowsBadRequest() throws Exception {
        mockMvc.perform(get("/api/places")
                        .param("latitude", "10.7725")
                        .param("longitude", "106.6980")
                        .param("radiusKm", "-5.0")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest());
    }
}
