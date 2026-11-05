package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.service.impl.HereGeocodingProvider;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

public class HereGeocodingProviderTest {

    @Test
    @DisplayName("Unconfigured HERE API key returns empty list and isConfigured is false")
    void unconfigured_returnsEmpty() {
        MapProperties props = new MapProperties();
        props.getGeocoding().setHereApiKey("");

        HereGeocodingProvider provider = new HereGeocodingProvider(RestClient.builder(), props);

        assertFalse(provider.isConfigured());
        assertEquals("HERE", provider.getProviderName());
        assertTrue(provider.search("Vũng Tàu", 10, null, null).isEmpty());
        assertTrue(provider.searchNearby(10.0, 106.0, "ALL", 1000, 10).isEmpty());
        assertNull(provider.reverseGeocode(10.0, 106.0));
    }

    @Test
    @DisplayName("Configured HERE provider parses items correctly from /v1/geocode")
    void configured_parsesGeocodeResponse() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();

        MapProperties props = new MapProperties();
        props.getGeocoding().setHereApiKey("here_test_key_123");

        HereGeocodingProvider provider = new HereGeocodingProvider(builder.build(), props);
        assertTrue(provider.isConfigured());

        server.expect(requestTo(containsString("/v1/geocode")))
                .andRespond(withSuccess("""
                        {
                          "items": [
                            {
                              "title": "Thành phố Vũng Tàu, Bà Rịa - Vũng Tàu, Việt Nam",
                              "id": "here:cm:namedplace:20658428",
                              "resultType": "administrativeArea",
                              "localityType": "city",
                              "address": {
                                "label": "Thành phố Vũng Tàu, Bà Rịa - Vũng Tàu, Việt Nam",
                                "city": "Vũng Tàu",
                                "county": "Bà Rịa - Vũng Tàu",
                                "countryName": "Việt Nam"
                              },
                              "position": {
                                "lat": 10.3460,
                                "lng": 107.0843
                              },
                              "mapView": {
                                "west": 107.05,
                                "south": 10.30,
                                "east": 107.15,
                                "north": 10.45
                              },
                              "scoring": {
                                "queryScore": 0.98
                              }
                            }
                          ]
                        }
                        """, MediaType.APPLICATION_JSON));

        List<LocationSearchResultResponse> results = provider.search("Vũng Tàu", 5, null, null);
        server.verify();

        assertEquals(1, results.size());
        LocationSearchResultResponse res = results.get(0);
        assertEquals("Vũng Tàu", res.getName());
        assertEquals(10.3460, res.getLatitude());
        assertEquals(107.0843, res.getLongitude());
        assertEquals("city", res.getType());
        assertEquals("HERE", res.getProvider());
        assertNotNull(res.getBoundingBox());
    }

    @Test
    @DisplayName("Upstream error in HERE provider fails gracefully without breaking search")
    void upstreamError_failsGracefully() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();

        MapProperties props = new MapProperties();
        props.getGeocoding().setHereApiKey("here_test_key_123");

        HereGeocodingProvider provider = new HereGeocodingProvider(builder.build(), props);

        server.expect(requestTo(containsString("/v1/geocode")))
                .andRespond(withStatus(HttpStatus.BAD_GATEWAY));

        List<LocationSearchResultResponse> results = provider.search("ErrorQuery", 5, null, null);
        assertNotNull(results);
        assertTrue(results.isEmpty());
        server.verify();
    }
}

