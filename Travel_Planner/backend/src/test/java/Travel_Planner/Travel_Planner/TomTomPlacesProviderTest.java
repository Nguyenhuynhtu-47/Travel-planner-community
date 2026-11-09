package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.service.impl.TomTomPlacesProvider;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class TomTomPlacesProviderTest {
    @Test
    void suggestReturnsDetailsActionAndVietNamRestrictedQuery() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        MapProperties props = configured();
        TomTomPlacesProvider provider = new TomTomPlacesProvider(builder.build(), props);

        server.expect(requestTo(containsString("/maps/orbis/places/suggest")))
                .andExpect(header("TomTom-Api-Version", "3"))
                .andExpect(header("Session-Id", "123e4567-e89b-42d3-a456-426614174000"))
                .andRespond(withSuccess("""
                        {"results":[{"id":"poi-1","type":"poi","title":"Hồ Gươm",
                          "more":{"operation":"details","pathParameters":[
                            {"parameter":"type","argument":"pois"},
                            {"parameter":"id","argument":"poi-1"}]}}]}
                        """, MediaType.APPLICATION_JSON));

        List<LocationSearchResultResponse> results = provider.suggest("Hồ Gươm", 5, 21.0, 105.8,
                "123e4567-e89b-42d3-a456-426614174000");
        server.verify();
        assertEquals(1, results.size());
        assertEquals("pois:poi-1", results.get(0).getPlaceId());
        assertEquals("pois", results.get(0).getProviderType());
        assertTrue(results.get(0).getRequiresDetails());
        assertNull(results.get(0).getLatitude());
    }

    @Test
    void detailsResolvesCoordinatesForSelectedSuggestion() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        TomTomPlacesProvider provider = new TomTomPlacesProvider(builder.build(), configured());
        server.expect(requestTo(containsString("/places/details/pois/poi-1")))
                .andRespond(withSuccess("""
                        {"result":{"id":"poi-1","type":"poi","title":"Hồ Gươm",
                          "position":{"coordinates":[105.8522,21.0285]},
                          "address":{"freeformAddress":"Hoàn Kiếm, Hà Nội, Việt Nam"}}}
                        """, MediaType.APPLICATION_JSON));

        LocationSearchResultResponse result = provider.details("pois", "poi-1", null);
        server.verify();
        assertEquals(21.0285, result.getLatitude());
        assertEquals(105.8522, result.getLongitude());
        assertEquals("pois:poi-1", result.getPlaceId());
        assertEquals("TOMTOM", result.getProvider());
        assertFalse(result.getRequiresDetails());
    }

    private MapProperties configured() {
        MapProperties properties = new MapProperties();
        properties.getTomtom().setEnabled(true);
        properties.getTomtom().setApiKey("test-key");
        return properties;
    }
}
