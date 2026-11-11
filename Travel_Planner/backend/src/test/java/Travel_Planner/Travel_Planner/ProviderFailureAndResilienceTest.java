package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.location.GeographicTargetArea;
import Travel_Planner.Travel_Planner.dto.location.ParsedLocationQuery;
import Travel_Planner.Travel_Planner.dto.location.SearchIntent;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.service.GeocodingProvider;
import Travel_Planner.Travel_Planner.service.GeographicFilterService;
import Travel_Planner.Travel_Planner.service.LocationRankingService;
import Travel_Planner.Travel_Planner.service.QueryUnderstandingService;
import Travel_Planner.Travel_Planner.service.impl.HereGeocodingProvider;
import Travel_Planner.Travel_Planner.service.impl.LocationIqGeocodingProvider;
import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.LocationServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.TomTomPlacesProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import java.math.BigDecimal;
import java.net.SocketTimeoutException;
import java.util.Collections;
import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

public class ProviderFailureAndResilienceTest {

    private LocationIqGeocodingProvider locationIqProvider;
    private HereGeocodingProvider hereProvider;
    private TomTomPlacesProvider tomTomProvider;
    private PlaceRepository placeRepository;
    private AdministrativeAreaRepository administrativeAreaRepository;
    private QueryUnderstandingService queryUnderstandingService;
    private GeographicFilterService geographicFilterService;
    private LocationRankingService rankingService;

    @BeforeEach
    void setUp() {
        placeRepository = mock(PlaceRepository.class);
        administrativeAreaRepository = mock(AdministrativeAreaRepository.class);
        queryUnderstandingService = mock(QueryUnderstandingService.class);
        geographicFilterService = mock(GeographicFilterService.class);
        rankingService = new LocationRankingServiceImpl();
    }

    @Test
    @DisplayName("Task 4.1: Missing API key returns empty list gracefully without throwing exception")
    void testMissingApiKey_ReturnsEmptyList() {
        MapProperties props = new MapProperties();
        props.getGeocoding().setApiKey(""); // unconfigured
        LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(RestClient.builder().build(), props);

        assertFalse(provider.isConfigured());
        List<LocationSearchResultResponse> results = provider.search("Hà Nội", 5, null, null);
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    @DisplayName("Task 4.2: LocationIQ HTTP 4xx client error is handled cleanly without crash")
    void testLocationIq_Http4xxHandled() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();

        MapProperties props = new MapProperties();
        props.getGeocoding().setApiKey("test_key");
        props.getGeocoding().setBaseUrl("https://us1.locationiq.com/v1");

        LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(builder.build(), props);

        // 404 Not Found (e.g. no geocode matches)
        server.expect(requestTo(containsString("/search")))
                .andRespond(withStatus(HttpStatus.NOT_FOUND));

        // When /search returns 404, supplemental autocomplete is attempted
        server.expect(requestTo(containsString("/autocomplete")))
                .andRespond(withStatus(HttpStatus.NOT_FOUND));

        List<LocationSearchResultResponse> results = provider.search("unknown place", 5, null, null);
        server.verify();
        assertNotNull(results);
        assertTrue(results.isEmpty(), "HTTP 404 should result in empty list, not an exception");
    }

    @Test
    @DisplayName("Task 4.3: LocationIQ HTTP 5xx server error throws structured AppException (502 Bad Gateway)")
    void testLocationIq_Http5xxThrowsAppException() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();

        MapProperties props = new MapProperties();
        props.getGeocoding().setApiKey("test_key");
        props.getGeocoding().setBaseUrl("https://us1.locationiq.com/v1");

        LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(builder.build(), props);

        server.expect(requestTo(containsString("/search")))
                .andRespond(withStatus(HttpStatus.INTERNAL_SERVER_ERROR));

        AppException ex = assertThrows(AppException.class, () ->
                provider.search("Đà Nẵng", 5, null, null));
        assertEquals(HttpStatus.BAD_GATEWAY, ex.getStatus());
    }

    @Test
    @DisplayName("Task 4.4: LocationIQ Timeout throws structured AppException (504 Gateway Timeout)")
    void testLocationIq_TimeoutThrowsGatewayTimeout() {
        RestClient mockClient = mock(RestClient.class);
        RestClient.RequestHeadersUriSpec uriSpec = mock(RestClient.RequestHeadersUriSpec.class);
        when(mockClient.get()).thenReturn(uriSpec);
        when(uriSpec.uri(any(java.net.URI.class))).thenReturn(uriSpec);
        when(uriSpec.retrieve()).thenThrow(new ResourceAccessException("Read timed out", new SocketTimeoutException()));

        MapProperties props = new MapProperties();
        props.getGeocoding().setApiKey("test_key");

        LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(mockClient, props);

        AppException ex = assertThrows(AppException.class, () ->
                provider.search("Sa Pa", 5, null, null));
        assertEquals(HttpStatus.GATEWAY_TIMEOUT, ex.getStatus());
    }

    @Test
    @DisplayName("Task 4.5: Empty JSON response parses safely as empty list")
    void testEmptyJsonResponse_ReturnsEmptyList() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();

        MapProperties props = new MapProperties();
        props.getGeocoding().setApiKey("test_key");
        props.getGeocoding().setBaseUrl("https://us1.locationiq.com/v1");

        LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(builder.build(), props);

        server.expect(requestTo(containsString("/search")))
                .andRespond(withSuccess("[]", MediaType.APPLICATION_JSON));
        server.expect(requestTo(containsString("/autocomplete")))
                .andRespond(withSuccess("[]", MediaType.APPLICATION_JSON));

        List<LocationSearchResultResponse> results = provider.search("query", 5, null, null);
        server.verify();
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    @DisplayName("Task 4.6: Malformed JSON response is caught and handled safely")
    void testMalformedJsonResponse_HandledSafely() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();

        MapProperties props = new MapProperties();
        props.getGeocoding().setApiKey("test_key");
        props.getGeocoding().setBaseUrl("https://us1.locationiq.com/v1");

        LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(builder.build(), props);

        server.expect(requestTo(containsString("/search")))
                .andRespond(withSuccess("{\"unexpected\":\"object_not_array\"}", MediaType.APPLICATION_JSON));
        server.expect(requestTo(containsString("/autocomplete")))
                .andRespond(withSuccess("{\"unexpected\":\"object_not_array\"}", MediaType.APPLICATION_JSON));

        List<LocationSearchResultResponse> results = provider.search("query", 5, null, null);
        server.verify();
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    @DisplayName("Task 4.7: Two-stage search: Primary provider fails, secondary HERE provider succeeds")
    void testTwoStageSearch_PrimaryFails_SecondaryHereSucceeds() {
        LocationIqGeocodingProvider primaryMock = mock(LocationIqGeocodingProvider.class);
        HereGeocodingProvider hereMock = mock(HereGeocodingProvider.class);

        when(primaryMock.isConfigured()).thenReturn(true);
        when(primaryMock.getProviderName()).thenReturn("LOCATION_IQ");
        when(hereMock.isConfigured()).thenReturn(true);
        when(hereMock.getProviderName()).thenReturn("HERE");

        // Query setup
        ParsedLocationQuery parsed = ParsedLocationQuery.builder()
                .originalQuery("cơm tấm Long Xuyên")
                .searchKeyword("cơm tấm")
                .locationQuery("Long Xuyên")
                .placeCategory("FOOD")
                .searchIntent(SearchIntent.POI_IN_LOCATION)
                .build();
        when(queryUnderstandingService.parseQuery("cơm tấm Long Xuyên")).thenReturn(parsed);

        // Target area resolution
        GeographicTargetArea targetArea = GeographicTargetArea.builder()
                .queryName("Long Xuyên")
                .resolvedName("Thành phố Long Xuyên, An Giang")
                .centerLat(10.38)
                .centerLon(105.43)
                .boundingBox(List.of(10.30, 10.45, 105.35, 105.50))
                .maxRadiusKm(15.0)
                .build();
        when(primaryMock.search(eq("Long Xuyên"), anyInt(), any(), any())).thenReturn(List.of(
                LocationSearchResultResponse.builder()
                        .placeId("lx_area")
                        .name("Long Xuyên")
                        .latitude(10.38)
                        .longitude(105.43)
                        .boundingBox(List.of(10.30, 10.45, 105.35, 105.50))
                        .build()
        ));

        // Primary searchInArea throws network exception
        when(primaryMock.searchInArea(anyString(), anyInt(), anyDouble(), anyDouble(), anyList(), anyInt()))
                .thenThrow(new RuntimeException("LocationIQ connection dropped"));

        // HERE searchInArea succeeds
        LocationSearchResultResponse hereItem = LocationSearchResultResponse.builder()
                .placeId("here_food_1")
                .name("Quán Cơm Tấm Cây Điệp")
                .formattedAddress("Lý Tự Trọng, Mỹ Long, Long Xuyên")
                .latitude(10.382)
                .longitude(105.435)
                .category("food")
                .type("restaurant")
                .provider("HERE")
                .build();
        when(hereMock.searchInArea(anyString(), anyInt(), anyDouble(), anyDouble(), anyList(), anyInt()))
                .thenReturn(List.of(hereItem));
        when(geographicFilterService.filter(anyList(), any())).thenReturn(List.of(hereItem));

        LocationServiceImpl service = new LocationServiceImpl(
                primaryMock, hereMock, rankingService, queryUnderstandingService, geographicFilterService, null, null, null
        );

        List<LocationSearchResultResponse> results = service.searchLocations("cơm tấm Long Xuyên", 5, null, null, null, null);
        assertNotNull(results);
        assertFalse(results.isEmpty());
        assertEquals("here_food_1", results.get(0).getPlaceId());
        assertEquals("HERE", results.get(0).getProvider());
    }

    @Test
    @DisplayName("Task 4.8: External provider fails, but internal catalog has candidates -> returns internal without HTTP 500")
    void testExternalFails_InternalCandidatesReturnedWithout500() {
        LocationIqGeocodingProvider primaryMock = mock(LocationIqGeocodingProvider.class);
        when(primaryMock.isConfigured()).thenReturn(true);
        when(primaryMock.search(anyString(), anyInt(), any(), any()))
                .thenThrow(new AppException("Provider 500 error", HttpStatus.BAD_GATEWAY));

        ParsedLocationQuery parsed = ParsedLocationQuery.builder()
                .originalQuery("Bến Thành")
                .searchIntent(SearchIntent.SPECIFIC_PLACE)
                .build();
        when(queryUnderstandingService.parseQuery("Bến Thành")).thenReturn(parsed);

        // Place repo returns 1 internal place
        Place p = Place.builder()
                .placeId(1L)
                .name("Chợ Bến Thành")
                .address("Quận 1, TP. HCM")
                .latitude(new BigDecimal("10.7725"))
                .longitude(new BigDecimal("106.6980"))
                .status(PlaceStatus.ACTIVE)
                .category(PlaceCategory.SHOPPING)
                .build();
        when(placeRepository.searchPlaces(anyString(), anyString(), any(), any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(p)));

        LocationServiceImpl service = new LocationServiceImpl(
                primaryMock, null, rankingService, queryUnderstandingService, geographicFilterService, null, placeRepository, null
        );

        // When external fails, service catches AppException and returns internal candidates!
        List<LocationSearchResultResponse> results = service.searchLocations("Bến Thành", 5, null, null, null, null);
        assertNotNull(results);
        assertEquals(1, results.size());
        assertEquals("place_1", results.get(0).getPlaceId());
        assertEquals("SYSTEM", results.get(0).getProvider());
    }

    @Test
    @DisplayName("Task 4.9: Internal catalog satisfies limit -> does NOT call external provider at all")
    void testInternalCatalogSatisfiesLimit_ExternalProviderNotCalled() {
        LocationIqGeocodingProvider primaryMock = mock(LocationIqGeocodingProvider.class);
        ParsedLocationQuery parsed = ParsedLocationQuery.builder()
                .originalQuery("Hà Nội")
                .searchIntent(SearchIntent.LOCALITY)
                .build();
        when(queryUnderstandingService.parseQuery("Hà Nội")).thenReturn(parsed);

        Place p1 = Place.builder()
                .placeId(1L)
                .name("Hồ Hoàn Kiếm")
                .latitude(new BigDecimal("21.0285"))
                .longitude(new BigDecimal("105.8542"))
                .status(PlaceStatus.ACTIVE)
                .category(PlaceCategory.ATTRACTION)
                .build();
        Place p2 = Place.builder()
                .placeId(2L)
                .name("Văn Miếu")
                .latitude(new BigDecimal("21.0290"))
                .longitude(new BigDecimal("105.8360"))
                .status(PlaceStatus.ACTIVE)
                .category(PlaceCategory.ATTRACTION)
                .build();

        // 2 internal places return when limit=2
        when(placeRepository.searchPlaces(anyString(), anyString(), any(), any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(p1, p2)));

        LocationServiceImpl service = new LocationServiceImpl(
                primaryMock, null, rankingService, queryUnderstandingService, geographicFilterService, null, placeRepository, null
        );

        List<LocationSearchResultResponse> results = service.searchLocations("Hà Nội", 2, null, null, null, null);
        assertNotNull(results);
        assertEquals(2, results.size());

        // Verify primary provider was NEVER invoked!
        verify(primaryMock, never()).search(anyString(), anyInt(), any(), any());
    }
}
