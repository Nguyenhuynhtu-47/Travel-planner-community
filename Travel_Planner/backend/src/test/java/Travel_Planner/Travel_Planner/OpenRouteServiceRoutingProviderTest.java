package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.RoutingProviderException;
import Travel_Planner.Travel_Planner.model.CachedRouteResult;
import Travel_Planner.Travel_Planner.model.WaypointCoordinate;
import Travel_Planner.Travel_Planner.service.impl.OpenRouteServiceRoutingProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import java.net.SocketTimeoutException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

class OpenRouteServiceRoutingProviderTest {

    private MapProperties mapProperties;
    private RestClient.Builder restClientBuilder;
    private MockRestServiceServer mockServer;
    private OpenRouteServiceRoutingProvider provider;

    private static final String SAMPLE_ORS_GEOJSON = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "LineString",
                    "coordinates": [
                      [105.85444, 21.02851],
                      [105.84500, 21.02900],
                      [105.83605, 21.02935]
                    ]
                  },
                  "properties": {
                    "summary": {
                      "distance": 4250.5,
                      "duration": 720.0
                    }
                  }
                }
              ]
            }
            """;

    @BeforeEach
    void setUp() {
        mapProperties = new MapProperties();
        mapProperties.getRouting().setApiKey("test-ors-api-key");
        mapProperties.getRouting().setBaseUrl("https://api.openrouteservice.org");
        mapProperties.getRouting().setTimeoutMs(4000);
        mapProperties.getRouting().setMaxWaypoints(50);

        restClientBuilder = RestClient.builder();
        mockServer = MockRestServiceServer.bindTo(restClientBuilder).build();
        RestClient restClient = restClientBuilder.build();
        provider = new OpenRouteServiceRoutingProvider(restClient, mapProperties);
    }

    @Test
    @DisplayName("isConfigured returns true when apiKey is populated, false when blank")
    void testIsConfigured() {
        assertTrue(provider.isConfigured());

        mapProperties.getRouting().setApiKey("");
        assertFalse(provider.isConfigured());

        mapProperties.getRouting().setApiKey("   ");
        assertFalse(provider.isConfigured());
    }

    @Test
    @DisplayName("calculateRoute successfully parses ORS GeoJSON response")
    void testCalculateRouteSuccess() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.02851, 105.85444),
                new WaypointCoordinate(21.02935, 105.83605)
        );

        mockServer.expect(requestTo("https://api.openrouteservice.org/v2/directions/driving-car/geojson"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header("Authorization", "test-ors-api-key"))
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andRespond(withSuccess(SAMPLE_ORS_GEOJSON, MediaType.parseMediaType("application/geo+json")));

        CachedRouteResult result = provider.calculateRoute("driving", waypoints);

        mockServer.verify();
        assertNotNull(result);
        assertEquals("ACTUAL_ROAD", result.routeType());
        assertEquals("OPEN_ROUTE_SERVICE", result.provider());
        assertEquals(4250.5, result.totalDistanceMeters());
        assertEquals(720.0, result.totalDurationSeconds());
        assertNotNull(result.directDistanceMeters());
        assertTrue(result.directDistanceMeters() > 0);
        assertEquals(3, result.geometryCoordinates().size());

        // Verify GeoJSON coordinate order: [lon, lat]
        assertEquals(105.85444, result.geometryCoordinates().get(0).get(0));
        assertEquals(21.02851, result.geometryCoordinates().get(0).get(1));
    }

    @Test
    @DisplayName("calculateRoute maps walking mode to foot-walking profile")
    void testCalculateRouteWalkingMode() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.02851, 105.85444),
                new WaypointCoordinate(21.02935, 105.83605)
        );

        mockServer.expect(requestTo("https://api.openrouteservice.org/v2/directions/foot-walking/geojson"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess(SAMPLE_ORS_GEOJSON, MediaType.parseMediaType("application/geo+json")));

        CachedRouteResult result = provider.calculateRoute("walking", waypoints);

        mockServer.verify();
        assertNotNull(result);
        assertEquals("ACTUAL_ROAD", result.routeType());
    }

    @Test
    @DisplayName("calculateRoute throws BadRequestException for unsupported mode")
    void testCalculateRouteUnsupportedMode() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.02851, 105.85444),
                new WaypointCoordinate(21.02935, 105.83605)
        );

        BadRequestException ex = assertThrows(BadRequestException.class,
                () -> provider.calculateRoute("flying", waypoints));
        assertTrue(ex.getMessage().contains("không được hỗ trợ"));
    }

    @Test
    @DisplayName("calculateRoute throws BadRequestException when waypoints < 2")
    void testCalculateRouteFewerThanTwoWaypoints() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.02851, 105.85444)
        );

        assertThrows(BadRequestException.class, () -> provider.calculateRoute("driving", waypoints));
        assertThrows(BadRequestException.class, () -> provider.calculateRoute("driving", List.of()));
        assertThrows(BadRequestException.class, () -> provider.calculateRoute("driving", null));
    }

    @Test
    @DisplayName("calculateRoute throws BadRequestException when waypoints exceed maxWaypoints")
    void testCalculateRouteExceedsMaxWaypoints() {
        mapProperties.getRouting().setMaxWaypoints(3);
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.01, 105.01),
                new WaypointCoordinate(21.02, 105.02),
                new WaypointCoordinate(21.03, 105.03),
                new WaypointCoordinate(21.04, 105.04)
        );

        BadRequestException ex = assertThrows(BadRequestException.class,
                () -> provider.calculateRoute("driving", waypoints));
        assertTrue(ex.getMessage().contains("vượt quá giới hạn"));
    }

    @Test
    @DisplayName("calculateRoute throws RoutingProviderException when unconfigured")
    void testCalculateRouteUnconfigured() {
        mapProperties.getRouting().setApiKey("");
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.01, 105.01),
                new WaypointCoordinate(21.02, 105.02)
        );

        RoutingProviderException ex = assertThrows(RoutingProviderException.class,
                () -> provider.calculateRoute("driving", waypoints));
        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, ex.getStatus());
    }

    @Test
    @DisplayName("calculateRoute handles HTTP 429 rate limit")
    void testCalculateRouteRateLimit() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.01, 105.01),
                new WaypointCoordinate(21.02, 105.02)
        );

        mockServer.expect(requestTo("https://api.openrouteservice.org/v2/directions/driving-car/geojson"))
                .andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS));

        RoutingProviderException ex = assertThrows(RoutingProviderException.class,
                () -> provider.calculateRoute("driving", waypoints));
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, ex.getStatus());
        assertTrue(ex.isRateLimit());
    }

    @Test
    @DisplayName("calculateRoute handles HTTP 404 / 400 no route found")
    void testCalculateRouteNoRoute() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.01, 105.01),
                new WaypointCoordinate(21.02, 105.02)
        );

        mockServer.expect(requestTo("https://api.openrouteservice.org/v2/directions/driving-car/geojson"))
                .andRespond(withStatus(HttpStatus.NOT_FOUND));

        RoutingProviderException ex = assertThrows(RoutingProviderException.class,
                () -> provider.calculateRoute("driving", waypoints));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }

    @Test
    @DisplayName("calculateRoute handles HTTP 500 server error")
    void testCalculateRouteServerError() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.01, 105.01),
                new WaypointCoordinate(21.02, 105.02)
        );

        mockServer.expect(requestTo("https://api.openrouteservice.org/v2/directions/driving-car/geojson"))
                .andRespond(withStatus(HttpStatus.INTERNAL_SERVER_ERROR));

        RoutingProviderException ex = assertThrows(RoutingProviderException.class,
                () -> provider.calculateRoute("driving", waypoints));
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, ex.getStatus());
    }

    @Test
    @DisplayName("calculateRoute handles timeout / connection error")
    void testCalculateRouteTimeout() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.01, 105.01),
                new WaypointCoordinate(21.02, 105.02)
        );

        mockServer.expect(requestTo("https://api.openrouteservice.org/v2/directions/driving-car/geojson"))
                .andRespond(withException(new SocketTimeoutException("Connection timed out")));

        RoutingProviderException ex = assertThrows(RoutingProviderException.class,
                () -> provider.calculateRoute("driving", waypoints));
        assertEquals(HttpStatus.GATEWAY_TIMEOUT, ex.getStatus());
        assertTrue(ex.isTimeout());
    }

    @Test
    @DisplayName("calculateRoute handles empty or malformed JSON")
    void testCalculateRouteMalformedJson() {
        List<WaypointCoordinate> waypoints = List.of(
                new WaypointCoordinate(21.01, 105.01),
                new WaypointCoordinate(21.02, 105.02)
        );

        mockServer.expect(requestTo("https://api.openrouteservice.org/v2/directions/driving-car/geojson"))
                .andRespond(withSuccess("{\"type\":\"FeatureCollection\",\"features\":[]}", MediaType.APPLICATION_JSON));

        RoutingProviderException ex = assertThrows(RoutingProviderException.class,
                () -> provider.calculateRoute("driving", waypoints));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }
}
