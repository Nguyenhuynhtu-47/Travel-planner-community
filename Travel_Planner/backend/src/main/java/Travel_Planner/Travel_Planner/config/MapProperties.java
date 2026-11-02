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

    @Getter
    @Setter
    public static class Geocoding {
        private String provider = "LOCATION_IQ";
        private String apiKey = "";
        private int timeoutMs = 3000;
        private String baseUrl = "https://us1.locationiq.com/v1";
    }
}

