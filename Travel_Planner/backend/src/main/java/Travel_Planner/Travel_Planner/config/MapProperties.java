package Travel_Planner.Travel_Planner.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "app.map")
@Getter
@Setter
public class MapProperties {
    private Geocoding geocoding = new Geocoding();
    private Routing routing = new Routing();

    @Getter
    @Setter
    public static class Geocoding {
        private String provider = "LOCATION_IQ";
        private String apiKey = "";
        private int timeoutMs = 3000;
        private String baseUrl = "https://us1.locationiq.com/v1";
        private boolean nearbyEnabled = false;
        private String language = "vi";
        private String hereApiKey = "";
        private String hereBaseUrl = "https://geocode.search.hereapi.com/v1";
        private String hereDiscoverBaseUrl = "https://discover.search.hereapi.com/v1";
    }

    @Getter
    @Setter
    public static class Routing {
        private String provider = "OPEN_ROUTE_SERVICE";
        private String apiKey = "";
        private int timeoutMs = 4000;
        private String baseUrl = "https://api.openrouteservice.org";
        private int maxWaypoints = 50;
    }
}

