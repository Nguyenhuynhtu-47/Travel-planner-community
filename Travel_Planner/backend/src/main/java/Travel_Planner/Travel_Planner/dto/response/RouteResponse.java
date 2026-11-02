package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Normalized per-day route calculation API response contract.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RouteResponse {
    private Integer itineraryId;
    private Integer dayId;
    private String status;               // "SUCCESS", "FALLBACK", "INSUFFICIENT_WAYPOINTS"
    private String routeType;            // "ACTUAL_ROAD", "ESTIMATED_INDICATIVE", "NONE"
    private String mode;                 // "driving", "walking"
    private Double totalDistanceMeters;  // Road distance (null for fallback or insufficient)
    private Double directDistanceMeters; // Straight-line Haversine distance
    private Double totalDurationSeconds; // Road duration in seconds (null for fallback or insufficient)
    private List<RouteWaypointResponse> waypoints;
    private List<List<Double>> geometryCoordinates; // GeoJSON format: [[lng, lat], ...]
}

