package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.RouteResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.RoutingProviderException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.RoutingProvider;
import Travel_Planner.Travel_Planner.service.impl.RouteServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class RouteServiceTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository itineraryDayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private DestinationRepository destinationRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private MapProperties mapProperties;

    private MockMvc mockMvc;

    private User ownerUser;
    private User otherUser;
    private String ownerToken;
    private String otherToken;

    private Itinerary publicItinerary;
    private ItineraryDay day1;
    private ItineraryDay day2;

    private Destination catalogDestination;
    private Activity act1;
    private Activity act2;
    private Activity act3NoLoc;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        ownerUser = userRepository.save(User.builder()
                .username("route_owner")
                .password(passwordEncoder.encode("Password123!"))
                .email("route_owner@example.com")
                .fullName("Chủ Lịch Trình")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        otherUser = userRepository.save(User.builder()
                .username("route_other")
                .password(passwordEncoder.encode("Password123!"))
                .email("route_other@example.com")
                .fullName("Người Dùng Khác")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        ownerToken = "Bearer " + jwtTokenProvider.generateToken(ownerUser);
        otherToken = "Bearer " + jwtTokenProvider.generateToken(otherUser);

        catalogDestination = destinationRepository.save(Destination.builder()
                .name("Hồ Xuân Hương")
                .address("Trung tâm Đà Lạt")
                .latitude(new BigDecimal("11.9404100"))
                .longitude(new BigDecimal("108.4385600"))
                .status(DestinationStatus.ACTIVE)
                .build());

        publicItinerary = itineraryRepository.save(Itinerary.builder()
                .user(ownerUser)
                .title("Khám Phá Đà Lạt")
                .location("Đà Lạt")
                .totalDays(2)
                .budget(new BigDecimal("2000000"))
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .build());

        day1 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(publicItinerary)
                .dayNumber(1)
                .title("Ngày 1: Check-in")
                .build());

        day2 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(publicItinerary)
                .dayNumber(2)
                .title("Ngày 2: Nghỉ ngơi")
                .build());

        // Stop 1: Catalog Destination (with snapshot coordinates)
        act1 = activityRepository.save(Activity.builder()
                .itineraryDay(day1)
                .destination(catalogDestination)
                .locationName(catalogDestination.getName())
                .locationAddress(catalogDestination.getAddress())
                .latitude(catalogDestination.getLatitude())
                .longitude(catalogDestination.getLongitude())
                .locationProvider("DESTINATION_CATALOG")
                .name("Dạo Hồ Xuân Hương")
                .displayOrder(1)
                .startTime(LocalTime.of(8, 0))
                .endTime(LocalTime.of(9, 30))
                .cost(BigDecimal.ZERO)
                .build());

        // Stop 2: Custom Location
        act2 = activityRepository.save(Activity.builder()
                .itineraryDay(day1)
                .name("Ăn trưa Quán Nướng Chu")
                .customLocationName("Quán Nướng Chu")
                .customAddress("Phạm Ngũ Lão, Đà Lạt")
                .latitude(new BigDecimal("11.9421230"))
                .longitude(new BigDecimal("108.4354210"))
                .displayOrder(2)
                .startTime(LocalTime.of(11, 30))
                .endTime(LocalTime.of(13, 0))
                .cost(new BigDecimal("350000"))
                .build());

        // Stop 3: No Location (should be excluded from route calculation)
        act3NoLoc = activityRepository.save(Activity.builder()
                .itineraryDay(day1)
                .name("Nghỉ ngơi tại khách sạn")
                .displayOrder(3)
                .startTime(LocalTime.of(13, 30))
                .endTime(LocalTime.of(15, 0))
                .cost(BigDecimal.ZERO)
                .build());
    }

    @AfterEach
    void tearDown() {
        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        itineraryRepository.deleteAll();
        destinationRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Nested
    @DisplayName("Waypoint Extraction & Insufficient Waypoints")
    class WaypointExtractionTests {

        @Test
        @DisplayName("Extracts only activities with valid coordinates in display order")
        void testExtractsValidCoordinatesInDisplayOrder() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            when(mockProvider.getProviderName()).thenReturn("OPEN_ROUTE_SERVICE");
            when(mockProvider.isConfigured()).thenReturn(true);
            when(mockProvider.calculateRoute(eq("driving"), anyList()))
                    .thenReturn(new CachedRouteResult(
                            "ACTUAL_ROAD",
                            "OPEN_ROUTE_SERVICE",
                            1200.0,
                            1100.0,
                            300.0,
                            List.of(List.of(108.43856, 11.94041), List.of(108.43542, 11.94212))
                    ));

            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            RouteResponse response = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );

            assertNotNull(response);
            assertEquals("SUCCESS", response.getStatus());
            assertEquals("ACTUAL_ROAD", response.getRouteType());
            assertEquals(2, response.getWaypoints().size());

            // Preserves display order: act1 (order 1), then act2 (order 2)
            assertEquals("Dạo Hồ Xuân Hương", response.getWaypoints().get(0).getName());
            assertEquals(1, response.getWaypoints().get(0).getDisplayOrder());
            assertEquals("Ăn trưa Quán Nướng Chu", response.getWaypoints().get(1).getName());
            assertEquals(2, response.getWaypoints().get(1).getDisplayOrder());

            // Excluded act3NoLoc
            assertFalse(response.getWaypoints().stream().anyMatch(w -> w.getName().contains("Nghỉ ngơi")));
        }

        @Test
        @DisplayName("Routing succeeds using activity snapshot coordinates even if linked destination is HIDDEN or deleted")
        void testRoutingSucceedsWhenDestinationIsHidden() {
            catalogDestination.setStatus(DestinationStatus.HIDDEN);
            destinationRepository.save(catalogDestination);

            RoutingProvider mockProvider = mock(RoutingProvider.class);
            when(mockProvider.getProviderName()).thenReturn("OPEN_ROUTE_SERVICE");
            when(mockProvider.isConfigured()).thenReturn(true);
            when(mockProvider.calculateRoute(eq("driving"), anyList()))
                    .thenReturn(new CachedRouteResult(
                            "ACTUAL_ROAD",
                            "OPEN_ROUTE_SERVICE",
                            2500.0,
                            2400.0,
                            480.0,
                            List.of(List.of(108.43856, 11.94041), List.of(108.43542, 11.94212))
                    ));

            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            RouteResponse response = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );

            assertNotNull(response);
            assertEquals("SUCCESS", response.getStatus());
            assertEquals(2, response.getWaypoints().size());
            assertEquals(act1.getLatitude(), response.getWaypoints().get(0).getLatitude());
            assertEquals(act1.getLongitude(), response.getWaypoints().get(0).getLongitude());
        }

        @Test
        @DisplayName("Returns INSUFFICIENT_WAYPOINTS when day has 0 or 1 located stops")
        void testInsufficientWaypoints() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            // Day 2 has 0 activities
            RouteResponse responseDay2 = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day2.getDayId(), "driving", ownerUser.getUsername()
            );

            assertEquals("INSUFFICIENT_WAYPOINTS", responseDay2.getStatus());
            assertEquals("NONE", responseDay2.getRouteType());
            assertNull(responseDay2.getTotalDistanceMeters());
            assertNull(responseDay2.getTotalDurationSeconds());
            assertNull(responseDay2.getDirectDistanceMeters(), "directDistanceMeters must be null when waypoints are insufficient");
            assertTrue(responseDay2.getWaypoints().isEmpty());
            assertTrue(responseDay2.getGeometryCoordinates().isEmpty());

            verifyNoInteractions(mockProvider);
        }
    }

    @Nested
    @DisplayName("Caffeine Route Caching & SHA-256 Key Determinism")
    class CachingTests {

        @Test
        @DisplayName("Cache hit returns cached road geometry without calling routing provider second time")
        void testCacheHitAvoidsDuplicateProviderCall() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            when(mockProvider.getProviderName()).thenReturn("OPEN_ROUTE_SERVICE");
            when(mockProvider.isConfigured()).thenReturn(true);
            when(mockProvider.calculateRoute(eq("driving"), anyList()))
                    .thenReturn(new CachedRouteResult(
                            "ACTUAL_ROAD",
                            "OPEN_ROUTE_SERVICE",
                            2500.0,
                            2200.0,
                            450.0,
                            List.of(List.of(108.43856, 11.94041), List.of(108.43542, 11.94212))
                    ));

            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            // First call: MISS -> calls mockProvider
            RouteResponse res1 = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );
            assertEquals("SUCCESS", res1.getStatus());
            assertEquals(2500.0, res1.getTotalDistanceMeters());
            verify(mockProvider, times(1)).calculateRoute(eq("driving"), anyList());

            // Second call: HIT -> returns cached result without calling mockProvider again
            RouteResponse res2 = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );
            assertEquals("SUCCESS", res2.getStatus());
            assertEquals(2500.0, res2.getTotalDistanceMeters());
            verify(mockProvider, times(1)).calculateRoute(eq("driving"), anyList());
        }

        @Test
        @DisplayName("Cache key varies when waypoint order is reversed or mode changes")
        void testCacheKeyDeterminism() {
            WaypointCoordinate p1 = new WaypointCoordinate(11.94041, 108.43856);
            WaypointCoordinate p2 = new WaypointCoordinate(11.94212, 108.43542);

            String keyForward = RouteServiceImpl.buildRouteCacheKey("driving", List.of(p1, p2));
            String keyReverse = RouteServiceImpl.buildRouteCacheKey("driving", List.of(p2, p1));
            String keyWalking = RouteServiceImpl.buildRouteCacheKey("walking", List.of(p1, p2));

            assertNotEquals(keyForward, keyReverse, "Reversing waypoint order must change cache key");
            assertNotEquals(keyForward, keyWalking, "Changing mode must change cache key");
            assertTrue(keyForward.startsWith("route:v1:ors:driving-car:"));
            assertTrue(keyWalking.startsWith("route:v1:ors:foot-walking:"));
        }

        @Test
        @DisplayName("Dynamic assembly: Renaming activity updates name in response while reusing cached road geometry")
        void testDynamicAssemblyStaleNameImmunity() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            when(mockProvider.getProviderName()).thenReturn("OPEN_ROUTE_SERVICE");
            when(mockProvider.isConfigured()).thenReturn(true);
            when(mockProvider.calculateRoute(eq("driving"), anyList()))
                    .thenReturn(new CachedRouteResult(
                            "ACTUAL_ROAD",
                            "OPEN_ROUTE_SERVICE",
                            2500.0,
                            2200.0,
                            450.0,
                            List.of(List.of(108.43856, 11.94041), List.of(108.43542, 11.94212))
                    ));

            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            // First call
            RouteResponse res1 = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );
            assertEquals("Dạo Hồ Xuân Hương", res1.getWaypoints().get(0).getName());

            // User updates activity name in database
            act1.setName("Đi dạo quanh Hồ Xuân Hương buổi sáng");
            activityRepository.save(act1);

            // Second call: Cache HIT on coordinates, but dynamic assembly joins the updated activity name!
            RouteResponse res2 = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );
            assertEquals("Đi dạo quanh Hồ Xuân Hương buổi sáng", res2.getWaypoints().get(0).getName());
            assertEquals(2500.0, res2.getTotalDistanceMeters());
            verify(mockProvider, times(1)).calculateRoute(eq("driving"), anyList());
        }

        @Test
        @DisplayName("Cache hit still enforces authorization, soft-delete, and day integrity before cache access")
        void testCacheHitStillEnforcesAuthorizationAndIntegrity() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            when(mockProvider.getProviderName()).thenReturn("OPEN_ROUTE_SERVICE");
            when(mockProvider.isConfigured()).thenReturn(true);
            when(mockProvider.calculateRoute(eq("driving"), anyList()))
                    .thenReturn(new CachedRouteResult(
                            "ACTUAL_ROAD",
                            "OPEN_ROUTE_SERVICE",
                            2500.0,
                            2200.0,
                            450.0,
                            List.of(List.of(108.43856, 11.94041), List.of(108.43542, 11.94212))
                    ));

            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            // 1. Initial warm up: populates the cache
            RouteResponse warmUp = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );
            assertEquals("SUCCESS", warmUp.getStatus());
            assertEquals(1, service.getRouteCache().estimatedSize());

            // 2. Private itinerary created by ownerUser with same coordinates
            Itinerary privateItinerary = itineraryRepository.save(Itinerary.builder()
                    .user(ownerUser)
                    .title("Lịch trình riêng tư")
                    .location("Đà Lạt")
                    .totalDays(1)
                    .budget(new BigDecimal("1000000"))
                    .visibility(Visibility.PRIVATE)
                    .status(ItineraryStatus.ACTIVE)
                    .build());

            ItineraryDay privateDay = itineraryDayRepository.save(ItineraryDay.builder()
                    .itinerary(privateItinerary)
                    .dayNumber(1)
                    .title("Ngày 1 riêng tư")
                    .build());

            // Add activities with same coordinates to target the identical cache key
            activityRepository.save(Activity.builder()
                    .itineraryDay(privateDay)
                    .name("Điểm 1")
                    .destination(catalogDestination)
                    .locationName(catalogDestination.getName())
                    .latitude(catalogDestination.getLatitude())
                    .longitude(catalogDestination.getLongitude())
                    .displayOrder(1)
                    .build());
            activityRepository.save(Activity.builder()
                    .itineraryDay(privateDay)
                    .name("Điểm 2")
                    .latitude(new BigDecimal("11.94212"))
                    .longitude(new BigDecimal("108.43542"))
                    .customLocationName("Custom 2")
                    .displayOrder(2)
                    .build());

            // Even though the route calculation is in cache, otherUser MUST receive 404 for private itinerary
            assertThrows(ResourceNotFoundException.class, () ->
                    service.calculateDayRoute(privateItinerary.getItineraryId(), privateDay.getDayId(), "driving", otherUser.getUsername())
            );

            // Mismatched dayId must throw BadRequestException even if route key is in cache
            assertThrows(BadRequestException.class, () ->
                    service.calculateDayRoute(publicItinerary.getItineraryId(), privateDay.getDayId(), "driving", ownerUser.getUsername())
            );

            // Soft-deleted itinerary must throw ResourceNotFoundException even if route key is in cache
            privateItinerary.setStatus(ItineraryStatus.DELETED);
            itineraryRepository.save(privateItinerary);
            assertThrows(ResourceNotFoundException.class, () ->
                    service.calculateDayRoute(privateItinerary.getItineraryId(), privateDay.getDayId(), "driving", ownerUser.getUsername())
            );
        }
    }

    @Nested
    @DisplayName("Haversine Fallback")
    class HaversineFallbackTests {

        @Test
        @DisplayName("Engages Haversine fallback when provider fails or times out")
        void testHaversineFallbackOnProviderFailure() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            when(mockProvider.getProviderName()).thenReturn("OPEN_ROUTE_SERVICE");
            when(mockProvider.isConfigured()).thenReturn(true);
            when(mockProvider.calculateRoute(eq("driving"), anyList()))
                    .thenThrow(new RoutingProviderException("Timeout connecting to ORS", HttpStatus.GATEWAY_TIMEOUT, true, false));

            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            RouteResponse response = service.calculateDayRoute(
                    publicItinerary.getItineraryId(), day1.getDayId(), "driving", ownerUser.getUsername()
            );

            assertNotNull(response);
            assertEquals("FALLBACK", response.getStatus());
            assertEquals("ESTIMATED_INDICATIVE", response.getRouteType());
            assertNull(response.getTotalDistanceMeters(), "totalDistanceMeters must be null for Haversine straight-line");
            assertNull(response.getTotalDurationSeconds(), "totalDurationSeconds must be null for Haversine fallback");
            assertNotNull(response.getDirectDistanceMeters());
            assertTrue(response.getDirectDistanceMeters() > 0);
            assertTrue(response.getGeometryCoordinates().isEmpty(), "Geometry must be empty for Haversine fallback; fallback never renders a route");

            // Verify fallback is NOT cached
            assertEquals(0, service.getRouteCache().estimatedSize());
        }
    }

    @Nested
    @DisplayName("Mode & Waypoint Validation")
    class ValidationTests {

        @Test
        @DisplayName("Rejects unsupported mode with HTTP 400 Bad Request")
        void testRejectsUnsupportedMode() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            BadRequestException ex = assertThrows(BadRequestException.class, () ->
                    service.calculateDayRoute(publicItinerary.getItineraryId(), day1.getDayId(), "bicycling", ownerUser.getUsername())
            );
            assertTrue(ex.getMessage().contains("không được hỗ trợ"));
        }

        @Test
        @DisplayName("Rejects dayId that does not belong to itineraryId with HTTP 400 Bad Request")
        void testRejectsCrossItineraryDay() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            // Create another itinerary with its own day
            Itinerary otherItinerary = itineraryRepository.save(Itinerary.builder()
                    .user(ownerUser)
                    .title("Hà Nội 1 Ngày")
                    .location("Hà Nội")
                    .totalDays(1)
                    .budget(new BigDecimal("1000000"))
                    .visibility(Visibility.PUBLIC)
                    .status(ItineraryStatus.ACTIVE)
                    .build());

            ItineraryDay otherDay = itineraryDayRepository.save(ItineraryDay.builder()
                    .itinerary(otherItinerary)
                    .dayNumber(1)
                    .title("Ngày 1")
                    .build());

            // Try to pass otherDay.dayId with publicItinerary.itineraryId
            BadRequestException ex = assertThrows(BadRequestException.class, () ->
                    service.calculateDayRoute(publicItinerary.getItineraryId(), otherDay.getDayId(), "driving", ownerUser.getUsername())
            );
            assertTrue(ex.getMessage().contains("không thuộc lịch trình này"));
        }
    }

    @Nested
    @DisplayName("Security & Access Control")
    class SecurityTests {

        @Test
        @DisplayName("Unauthenticated request throws UnauthorizedException")
        void testUnauthenticatedAccess() {
            RoutingProvider mockProvider = mock(RoutingProvider.class);
            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            assertThrows(UnauthorizedException.class, () ->
                    service.calculateDayRoute(publicItinerary.getItineraryId(), day1.getDayId(), "driving", null)
            );
        }

        @Test
        @DisplayName("Non-owner accessing private itinerary receives ResourceNotFoundException (preventing ID enumeration)")
        void testNonOwnerCannotAccessPrivateItinerary() {
            Itinerary privateItinerary = itineraryRepository.save(Itinerary.builder()
                    .user(ownerUser)
                    .title("Lịch Trình Riêng Tư")
                    .location("Huế")
                    .totalDays(1)
                    .budget(new BigDecimal("500000"))
                    .visibility(Visibility.PRIVATE)
                    .status(ItineraryStatus.ACTIVE)
                    .build());

            ItineraryDay privateDay = itineraryDayRepository.save(ItineraryDay.builder()
                    .itinerary(privateItinerary)
                    .dayNumber(1)
                    .title("Ngày 1")
                    .build());

            RoutingProvider mockProvider = mock(RoutingProvider.class);
            RouteServiceImpl service = new RouteServiceImpl(
                    itineraryRepository, itineraryDayRepository, activityRepository,
                    mockProvider, mapProperties
            );

            assertThrows(ResourceNotFoundException.class, () ->
                    service.calculateDayRoute(privateItinerary.getItineraryId(), privateDay.getDayId(), "driving", otherUser.getUsername())
            );

            // Owner can access it successfully
            assertDoesNotThrow(() ->
                    service.calculateDayRoute(privateItinerary.getItineraryId(), privateDay.getDayId(), "driving", ownerUser.getUsername())
            );
        }
    }

    @Nested
    @DisplayName("MockMvc Controller Endpoint Integration")
    class ControllerIntegrationTests {

        @Test
        @DisplayName("GET /api/itineraries/{id}/days/{dayId}/route without auth returns HTTP 401 Unauthorized")
        void testGetRouteEndpointWithoutAuth() throws Exception {
            mockMvc.perform(get("/api/itineraries/{id}/days/{dayId}/route", publicItinerary.getItineraryId(), day1.getDayId()))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("GET /api/itineraries/{id}/days/{dayId}/route with valid auth returns 200 OK")
        void testGetRouteEndpointWithAuth() throws Exception {
            mockMvc.perform(get("/api/itineraries/{id}/days/{dayId}/route", publicItinerary.getItineraryId(), day1.getDayId())
                            .header("Authorization", ownerToken))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.itineraryId", is(publicItinerary.getItineraryId())))
                    .andExpect(jsonPath("$.dayId", is(day1.getDayId())))
                    .andExpect(jsonPath("$.waypoints", hasSize(2)));
        }

        @Test
        @DisplayName("GET /api/itineraries/{id}/days/{dayId}/route with mismatched dayId returns HTTP 400 Bad Request")
        void testGetRouteEndpointCrossDayMismatch() throws Exception {
            Itinerary anotherItinerary = itineraryRepository.save(Itinerary.builder()
                    .user(ownerUser)
                    .title("Lịch trình khác")
                    .location("Hà Nội")
                    .totalDays(1)
                    .budget(new BigDecimal("1000000"))
                    .visibility(Visibility.PUBLIC)
                    .status(ItineraryStatus.ACTIVE)
                    .build());

            ItineraryDay foreignDay = itineraryDayRepository.save(ItineraryDay.builder()
                    .itinerary(anotherItinerary)
                    .dayNumber(1)
                    .title("Ngày 1")
                    .build());

            mockMvc.perform(get("/api/itineraries/{id}/days/{dayId}/route", publicItinerary.getItineraryId(), foreignDay.getDayId())
                            .header("Authorization", ownerToken))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message", containsString("không thuộc lịch trình này")));
        }
    }
}

