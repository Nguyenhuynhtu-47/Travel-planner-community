package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.ClientIpResolver;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.GeocodingProvider;
import Travel_Planner.Travel_Planner.service.LocationRateLimiter;
import Travel_Planner.Travel_Planner.service.impl.LocationIqGeocodingProvider;
import Travel_Planner.Travel_Planner.service.impl.LocationServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.client.RestClient;
import org.springframework.web.context.WebApplicationContext;

import java.net.SocketTimeoutException;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withException;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class LocationServiceTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private LocationRateLimiter locationRateLimiter;

    @Autowired
    private LocationServiceImpl locationService;

    @Autowired
    private ClientIpResolver clientIpResolver;

    private MockMvc mockMvc;
    private User testUser;
    private String testUserToken;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        locationRateLimiter.clear();
        locationService.clearCaches();

        testUser = userRepository.save(User.builder()
                .username("location_tester")
                .password(passwordEncoder.encode("Password123!"))
                .email("location_tester@example.com")
                .fullName("Người Thử Nghiệm Vị Trí")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        testUserToken = "Bearer " + jwtTokenProvider.generateToken(testUser);
    }

    @AfterEach
    void tearDown() {
        locationRateLimiter.clear();
        locationService.clearCaches();
        userRepository.delete(testUser);
    }

    // ========================================================
    // 1. QUERY VALIDATION & NORMALIZATION
    // ========================================================

    @Nested
    @DisplayName("Location Search Query Validation")
    class SearchQueryValidationTests {

        @Test
        @DisplayName("Search with query shorter than 2 characters throws BadRequestException")
        void search_queryTooShort_badRequest() throws Exception {
            mockMvc.perform(get("/api/locations/search")
                            .param("query", "a"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("từ 2 đến 100 ký tự")));
        }

        @Test
        @DisplayName("Search with blank or whitespace-only query throws BadRequestException")
        void search_queryBlank_badRequest() throws Exception {
            mockMvc.perform(get("/api/locations/search")
                            .param("query", "   "))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("không được để trống")));
        }

        @Test
        @DisplayName("Search with query exceeding 100 characters throws BadRequestException")
        void search_queryTooLong_badRequest() throws Exception {
            String longQuery = "a".repeat(101);
            mockMvc.perform(get("/api/locations/search")
                            .param("query", longQuery))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("từ 2 đến 100 ký tự")));
        }

        @Test
        @DisplayName("Search with limit < 1 or > 20 throws BadRequestException")
        void search_invalidLimit_badRequest() throws Exception {
            mockMvc.perform(get("/api/locations/search")
                            .param("query", "Hà Nội")
                            .param("limit", "0"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("limit")));

            mockMvc.perform(get("/api/locations/search")
                            .param("query", "Hà Nội")
                            .param("limit", "25"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("limit")));
        }

        @Test
        @DisplayName("Search with out-of-bounds latitude/longitude throws BadRequestException")
        void search_outOfBoundsCoordinates_badRequest() throws Exception {
            mockMvc.perform(get("/api/locations/search")
                            .param("query", "Hồ Gươm")
                            .param("latitude", "95.0")
                            .param("longitude", "105.8"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("latitude")));

            mockMvc.perform(get("/api/locations/search")
                            .param("query", "Hồ Gươm")
                            .param("latitude", "21.0")
                            .param("longitude", "190.0"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("longitude")));
        }

        @Test
        @DisplayName("Valid search returns 200 OK with list")
        void search_validQuery_ok() throws Exception {
            mockMvc.perform(get("/api/locations/search")
                            .param("query", "Hồ Gươm")
                            .accept(MediaType.APPLICATION_JSON))
                    .andExpect(status().isOk())
                    .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON));
        }
    }

    // ========================================================
    // 2. REVERSE GEOCODING VALIDATION
    // ========================================================

    @Nested
    @DisplayName("Reverse Geocoding Validation")
    class ReverseGeocodingValidationTests {

        @Test
        @DisplayName("Reverse geocoding with missing coordinates throws BadRequestException")
        void reverse_missingCoordinates_badRequest() throws Exception {
            mockMvc.perform(get("/api/locations/reverse-geocode")
                            .param("latitude", "21.0285"))
                    .andExpect(status().isBadRequest());

            mockMvc.perform(get("/api/locations/reverse-geocode")
                            .param("longitude", "105.8544"))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("Reverse geocoding with latitude out of [-90..90] throws BadRequestException")
        void reverse_latitudeOutOfBounds_badRequest() throws Exception {
            mockMvc.perform(get("/api/locations/reverse-geocode")
                            .param("latitude", "91.0")
                            .param("longitude", "105.8544"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("latitude")));
        }

        @Test
        @DisplayName("Reverse geocoding with longitude out of [-180..180] throws BadRequestException")
        void reverse_longitudeOutOfBounds_badRequest() throws Exception {
            mockMvc.perform(get("/api/locations/reverse-geocode")
                            .param("latitude", "21.0285")
                            .param("longitude", "-185.0"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("longitude")));
        }
    }

    // ========================================================
    // 3. CAFFEINE CACHING VERIFICATION
    // ========================================================

    @Nested
    @DisplayName("Caffeine In-Memory Caching (24h TTL, 500 max entries)")
    class CaffeineCachingTests {

        @Test
        @DisplayName("Repeated search queries hit Caffeine cache and do not re-invoke upstream provider")
        void search_caching_hit() {
            AtomicInteger callCount = new AtomicInteger(0);
            GeocodingProvider mockProvider = new GeocodingProvider() {
                @Override
                public String getProviderName() {
                    return "MOCK";
                }

                @Override
                public boolean isConfigured() {
                    return true;
                }

                @Override
                public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {
                    callCount.incrementAndGet();
                    return List.of(LocationSearchResultResponse.builder()
                            .placeId("mock_1")
                            .name("Chợ Bến Thành")
                            .formattedAddress("Quận 1, TP.HCM")
                            .latitude(10.7721)
                            .longitude(106.6983)
                            .category("tourism")
                            .provider("MOCK")
                            .build());
                }

                @Override
                public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {
                    return null;
                }
            };

            LocationServiceImpl customService = new LocationServiceImpl(mockProvider);
            assertEquals(0, customService.getSearchCacheSize());

            // First call -> Cache MISS -> invokes provider
            List<LocationSearchResultResponse> result1 = customService.searchLocations("Chợ Bến Thành", 10, null, null);
            assertEquals(1, callCount.get());
            assertEquals(1, result1.size());
            assertEquals(1, customService.getSearchCacheSize());

            // Second call with same normalized query -> Cache HIT -> does NOT invoke provider
            List<LocationSearchResultResponse> result2 = customService.searchLocations("  Chợ Bến Thành  ", 10, null, null);
            assertEquals(1, callCount.get());
            assertEquals("Chợ Bến Thành", result2.get(0).getName());

            // Third call with case-insensitive variation -> Cache HIT
            List<LocationSearchResultResponse> result3 = customService.searchLocations("chợ bến thành", 10, null, null);
            assertEquals(1, callCount.get());
            assertEquals("Chợ Bến Thành", result3.get(0).getName());
        }

        @Test
        @DisplayName("Repeated reverse geocode hits Caffeine cache and returns cached result")
        void reverse_caching_hit() {
            AtomicInteger callCount = new AtomicInteger(0);
            GeocodingProvider mockProvider = new GeocodingProvider() {
                @Override
                public String getProviderName() {
                    return "MOCK";
                }

                @Override
                public boolean isConfigured() {
                    return true;
                }

                @Override
                public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {
                    return Collections.emptyList();
                }

                @Override
                public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {
                    callCount.incrementAndGet();
                    return LocationSearchResultResponse.builder()
                            .placeId("mock_node_99")
                            .name("Nhà Hát Lớn")
                            .formattedAddress("Số 1 Tràng Tiền, Hoàn Kiếm, Hà Nội")
                            .latitude(latitude)
                            .longitude(longitude)
                            .category("amenity")
                            .provider("MOCK")
                            .build();
                }
            };

            LocationServiceImpl customService = new LocationServiceImpl(mockProvider);

            // First call -> MISS
            LocationSearchResultResponse r1 = customService.reverseGeocode(21.0245, 105.8576);
            assertEquals(1, callCount.get());
            assertEquals("Nhà Hát Lớn", r1.getName());

            // Second call with same coordinates -> HIT
            LocationSearchResultResponse r2 = customService.reverseGeocode(21.0245, 105.8576);
            assertEquals(1, callCount.get());
            assertEquals("Nhà Hát Lớn", r2.getName());
        }

        @Test
        @DisplayName("Coordinate rounding consistency: minor coordinate jitter hits same cache key and passes rounded coords to provider")
        void reverse_coordinateRounding_cacheHitAndProviderConsistency() {
            AtomicInteger callCount = new AtomicInteger(0);
            double[] passedCoords = new double[2];

            GeocodingProvider mockProvider = new GeocodingProvider() {
                @Override
                public String getProviderName() {
                    return "MOCK";
                }

                @Override
                public boolean isConfigured() {
                    return true;
                }

                @Override
                public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {
                    return Collections.emptyList();
                }

                @Override
                public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {
                    callCount.incrementAndGet();
                    passedCoords[0] = latitude;
                    passedCoords[1] = longitude;
                    return LocationSearchResultResponse.builder()
                            .placeId("mock_hoang_thanh")
                            .name("Hoàng Thành Thăng Long")
                            .formattedAddress("19C Hoàng Diệu, Ba Đình, Hà Nội")
                            .latitude(latitude)
                            .longitude(longitude)
                            .category("tourism")
                            .provider("MOCK")
                            .build();
                }
            };

            LocationServiceImpl customService = new LocationServiceImpl(mockProvider);

            // First call with 21.033511, 105.843212
            LocationSearchResultResponse r1 = customService.reverseGeocode(21.033511, 105.843212);
            assertEquals(1, callCount.get());
            // Verify coordinates sent to provider are rounded to 5 decimal places: 21.03351, 105.84321
            assertEquals(21.03351, passedCoords[0], 0.000001);
            assertEquals(105.84321, passedCoords[1], 0.000001);

            // Second call with jitter within ~1 meter: 21.033514, 105.843214 -> rounds to same 21.03351, 105.84321
            LocationSearchResultResponse r2 = customService.reverseGeocode(21.033514, 105.843214);
            assertEquals(1, callCount.get(), "Must be a cache HIT because rounded coordinates match exactly");
            assertEquals("Hoàng Thành Thăng Long", r2.getName());
        }

        @Test
        @DisplayName("Unconfigured provider does not write results to Caffeine cache")
        void unconfiguredProvider_doesNotPopulateCache() {
            GeocodingProvider unconfiguredProvider = new GeocodingProvider() {
                @Override
                public String getProviderName() {
                    return "UNCONFIGURED_MOCK";
                }

                @Override
                public boolean isConfigured() {
                    return false;
                }

                @Override
                public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {
                    return Collections.emptyList();
                }

                @Override
                public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {
                    return null;
                }
            };

            LocationServiceImpl customService = new LocationServiceImpl(unconfiguredProvider);

            // Search when unconfigured
            List<LocationSearchResultResponse> searchRes = customService.searchLocations("Hà Nội", 10, null, null);
            assertTrue(searchRes.isEmpty());
            assertEquals(0, customService.getSearchCacheSize(), "Search cache must not store entries when provider is unconfigured");

            // Reverse geocode when unconfigured throws ResourceNotFoundException without caching
            assertThrows(ResourceNotFoundException.class, () -> customService.reverseGeocode(21.0, 105.0));
            assertEquals(0, customService.getReverseCacheSize(), "Reverse cache must not store entries when provider is unconfigured");
        }
    }

    // ========================================================
    // 4. BUCKET4J DUAL-TIER RATE LIMITING
    // ========================================================

    @Nested
    @DisplayName("Bucket4j Dual-Tier Rate Limiting")
    class RateLimitingTests {

        @Test
        @DisplayName("Guest rate limit allows 30 requests/min and rejects 31st with HTTP 429")
        void rateLimiter_guestThreshold() {
            String guestKey = "ip:198.51.100.42";
            locationRateLimiter.reset(guestKey);

            // Consume 30 tokens successfully
            for (int i = 0; i < 30; i++) {
                assertTrue(locationRateLimiter.tryConsume(guestKey, false),
                        "Guest request #" + (i + 1) + " should be allowed");
            }

            // 31st request is rejected
            assertFalse(locationRateLimiter.tryConsume(guestKey, false),
                    "Guest request #31 should be rejected due to rate limit");
        }

        @Test
        @DisplayName("Authenticated rate limit allows 60 requests/min and rejects 61st with HTTP 429")
        void rateLimiter_authenticatedThreshold() {
            String userKey = "auth:user:" + testUser.getUserId();
            locationRateLimiter.reset(userKey);

            // Consume 60 tokens successfully
            for (int i = 0; i < 60; i++) {
                assertTrue(locationRateLimiter.tryConsume(userKey, true),
                        "Authenticated request #" + (i + 1) + " should be allowed");
            }

            // 61st request is rejected
            assertFalse(locationRateLimiter.tryConsume(userKey, true),
                    "Authenticated request #61 should be rejected due to rate limit");
        }

        @Test
        @DisplayName("Key isolation: Consuming guest tokens does not affect authenticated user budget")
        void rateLimiter_keyIsolation() {
            String guestKey = "ip:198.51.100.99";
            String userKey = "auth:user:888";
            locationRateLimiter.reset(guestKey);
            locationRateLimiter.reset(userKey);

            // Exhaust guest bucket
            for (int i = 0; i < 30; i++) {
                locationRateLimiter.tryConsume(guestKey, false);
            }
            assertFalse(locationRateLimiter.tryConsume(guestKey, false));

            // User bucket remains fully available (60 tokens)
            assertEquals(60, locationRateLimiter.getAvailableTokens(userKey, true));
            assertTrue(locationRateLimiter.tryConsume(userKey, true));
        }

        @Test
        @DisplayName("HTTP Endpoint returns 429 Too Many Requests when rate limit is exceeded")
        void endpoint_rateLimitExceeded_returns429() throws Exception {
            String uniqueIp = "192.0.2.100";

            // Exhaust 30 tokens for this client IP
            for (int i = 0; i < 30; i++) {
                mockMvc.perform(get("/api/locations/search")
                                .param("query", "Hà Nội")
                                .with(request -> {
                                    request.setRemoteAddr(uniqueIp);
                                    return request;
                                }))
                        .andExpect(status().isOk());
            }

            // 31st request returns 429
            mockMvc.perform(get("/api/locations/search")
                            .param("query", "Hà Nội")
                            .with(request -> {
                                request.setRemoteAddr(uniqueIp);
                                return request;
                            }))
                    .andExpect(status().isTooManyRequests())
                    .andExpect(jsonPath("$.status").value(429))
                    .andExpect(jsonPath("$.message").value(containsString("quá nhiều yêu cầu")));
        }
    }

    // ========================================================
    // 5. TRUSTED REVERSE-PROXY IP RESOLUTION
    // ========================================================

    @Nested
    @DisplayName("Trusted Reverse-Proxy Client IP Resolution")
    class TrustedProxyTests {

        @Test
        @DisplayName("Trusts X-Forwarded-For when direct remoteAddr is a configured trusted proxy")
        void resolveIp_trustedProxy_usesForwardedHeader() {
            MockHttpServletRequest request = new MockHttpServletRequest();
            request.setRemoteAddr("127.0.0.1"); // Trusted proxy
            request.addHeader("X-Forwarded-For", "203.0.113.195, 10.0.0.1");

            String clientIp = clientIpResolver.resolveClientIp(request);
            assertEquals("203.0.113.195", clientIp);
        }

        @Test
        @DisplayName("Rejects X-Forwarded-For when direct remoteAddr is NOT in trusted proxies (anti-spoofing)")
        void resolveIp_untrustedDirectIp_ignoresForwardedHeader() {
            MockHttpServletRequest request = new MockHttpServletRequest();
            request.setRemoteAddr("198.51.100.5"); // Untrusted direct connection
            request.addHeader("X-Forwarded-For", "1.2.3.4"); // Spoofed header attempt

            String clientIp = clientIpResolver.resolveClientIp(request);
            assertEquals("198.51.100.5", clientIp,
                    "Must ignore X-Forwarded-For when remote address is not a trusted proxy");
        }

        @Test
        @DisplayName("Supports IPv6 loopback variants in trusted proxy check")
        void resolveIp_ipv6Loopback_trusted() {
            MockHttpServletRequest request = new MockHttpServletRequest();
            request.setRemoteAddr("0:0:0:0:0:0:0:1");
            request.addHeader("X-Forwarded-For", "198.51.100.77");

            String clientIp = clientIpResolver.resolveClientIp(request);
            assertEquals("198.51.100.77", clientIp);
        }

        @Test
        @DisplayName("Cleans ports, bracketed IPv6, and quotes in X-Forwarded-For")
        void resolveIp_portsAndQuotesAndBrackets_cleaned() {
            MockHttpServletRequest req1 = new MockHttpServletRequest();
            req1.setRemoteAddr("127.0.0.1");
            req1.addHeader("X-Forwarded-For", "198.51.100.1:8080");
            assertEquals("198.51.100.1", clientIpResolver.resolveClientIp(req1));

            MockHttpServletRequest req2 = new MockHttpServletRequest();
            req2.setRemoteAddr("127.0.0.1");
            req2.addHeader("X-Forwarded-For", "\"[2001:db8::1]:8080\"");
            assertEquals("2001:db8::1", clientIpResolver.resolveClientIp(req2));

            MockHttpServletRequest req3 = new MockHttpServletRequest();
            req3.setRemoteAddr("127.0.0.1");
            req3.addHeader("X-Forwarded-For", "\"203.0.113.50\"");
            assertEquals("203.0.113.50", clientIpResolver.resolveClientIp(req3));
        }

        @Test
        @DisplayName("Skips malformed, empty, and unknown entries in multi-value X-Forwarded-For")
        void resolveIp_malformedAndUnknownParts_skipsToFirstValid() {
            MockHttpServletRequest req = new MockHttpServletRequest();
            req.setRemoteAddr("127.0.0.1");
            req.addHeader("X-Forwarded-For", ",   , unknown, 203.0.113.88, 10.0.0.1");
            assertEquals("203.0.113.88", clientIpResolver.resolveClientIp(req));
        }
    }

    // ========================================================
    // 6. PROVIDER GRACEFUL FAILURE & SECRET SAFETY
    // ========================================================

    @Nested
    @DisplayName("Provider Graceful Failure & Secret Protection")
    class GracefulFailureTests {

        @Test
        @DisplayName("When API key is not configured, search returns empty list without throwing")
        void provider_unconfiguredKey_returnsEmptyList() {
            MapProperties props = new MapProperties();
            props.getGeocoding().setApiKey(""); // unconfigured

            LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(
                    RestClient.builder(), props);

            assertFalse(provider.isConfigured());
            List<LocationSearchResultResponse> results = provider.search("Đà Lạt", 10, null, null);
            assertNotNull(results);
            assertTrue(results.isEmpty());

            LocationSearchResultResponse reverse = provider.reverseGeocode(11.94, 108.43);
            assertNull(reverse);
        }

        @Test
        @DisplayName("API Key is never leaked into API responses or error structures")
        void apiKey_neverExposedInOutput() throws Exception {
            mockMvc.perform(get("/api/locations/search")
                            .param("query", "Đà Nẵng"))
                    .andExpect(status().isOk())
                    .andExpect(content().string(not(containsString("key="))))
                    .andExpect(content().string(not(containsString("pk."))));
        }

        @Test
        @DisplayName("LocationIQ 404 Not Found returns empty list without error (genuine empty results)")
        void provider_upstream404_returnsEmptyList() {
            RestClient.Builder builder = RestClient.builder();
            MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
            RestClient restClient = builder.build();

            MapProperties props = new MapProperties();
            props.getGeocoding().setApiKey("test_pk_123");
            LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(restClient, props);

            server.expect(requestTo(containsString("/v1/autocomplete")))
                    .andRespond(withStatus(HttpStatus.NOT_FOUND));

            List<LocationSearchResultResponse> results = provider.search("DiaDiemKhongCoThat123", 10, null, null);
            assertNotNull(results);
            assertTrue(results.isEmpty());
            server.verify();
        }

        @Test
        @DisplayName("LocationIQ 429 Too Many Requests translates to RateLimitExceededException (HTTP 429)")
        void provider_upstream429_throwsRateLimitExceeded() {
            RestClient.Builder builder = RestClient.builder();
            MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
            RestClient restClient = builder.build();

            MapProperties props = new MapProperties();
            props.getGeocoding().setApiKey("test_pk_123");
            LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(restClient, props);

            server.expect(requestTo(containsString("/v1/autocomplete")))
                    .andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS));

            RateLimitExceededException ex = assertThrows(RateLimitExceededException.class,
                    () -> provider.search("Đà Nẵng", 10, null, null));
            assertEquals(HttpStatus.TOO_MANY_REQUESTS, ex.getStatus());
            server.verify();
        }

        @Test
        @DisplayName("LocationIQ 5xx Server Error translates to AppException with BAD_GATEWAY")
        void provider_upstream5xx_throwsBadGateway() {
            RestClient.Builder builder = RestClient.builder();
            MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
            RestClient restClient = builder.build();

            MapProperties props = new MapProperties();
            props.getGeocoding().setApiKey("test_pk_123");
            LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(restClient, props);

            server.expect(requestTo(containsString("/v1/reverse")))
                    .andRespond(withStatus(HttpStatus.BAD_GATEWAY));

            AppException ex = assertThrows(AppException.class,
                    () -> provider.reverseGeocode(21.0, 105.0));
            assertEquals(HttpStatus.BAD_GATEWAY, ex.getStatus());
            server.verify();
        }

        @Test
        @DisplayName("LocationIQ upstream timeout translates to AppException with GATEWAY_TIMEOUT")
        void provider_upstreamTimeout_throwsGatewayTimeout() {
            RestClient.Builder builder = RestClient.builder();
            MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
            RestClient restClient = builder.build();

            MapProperties props = new MapProperties();
            props.getGeocoding().setApiKey("test_pk_123");
            LocationIqGeocodingProvider provider = new LocationIqGeocodingProvider(restClient, props);

            server.expect(requestTo(containsString("/v1/autocomplete")))
                    .andRespond(withException(new SocketTimeoutException("Read timed out")));

            AppException ex = assertThrows(AppException.class,
                    () -> provider.search("Huế", 10, null, null));
            assertEquals(HttpStatus.GATEWAY_TIMEOUT, ex.getStatus());
            server.verify();
        }
    }
}

