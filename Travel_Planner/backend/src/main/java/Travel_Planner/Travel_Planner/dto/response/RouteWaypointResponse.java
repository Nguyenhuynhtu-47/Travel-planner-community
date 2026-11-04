package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Representation of an active itinerary stop participating in route calculation.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RouteWaypointResponse {
    private Integer activityId;
    private String name;
    private String locationName;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private Integer displayOrder;
}

