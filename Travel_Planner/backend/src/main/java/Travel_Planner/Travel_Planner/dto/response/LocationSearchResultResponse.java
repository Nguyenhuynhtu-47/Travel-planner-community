package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LocationSearchResultResponse {
    private String placeId;
    private String name;
    private String formattedAddress;
    private Double latitude;
    private Double longitude;
    private String category;
    private String type;
    private Double importance;
    private List<Double> boundingBox;
    private String provider;
    private Boolean isLocalityFallback;
}

