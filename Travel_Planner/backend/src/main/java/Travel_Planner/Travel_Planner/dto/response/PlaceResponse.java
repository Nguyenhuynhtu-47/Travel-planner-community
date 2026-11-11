package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlaceResponse {
    private Long placeId;
    private String name;
    private String address;
    private String description;
    private String imageUrl;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private PlaceCategory category;
    private PlaceStatus status;
    private Integer sourceDestinationId;
    private Double distanceKm;
}

