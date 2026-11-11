package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlaceDetailResponse {
    private Long placeId;
    private String name;
    private String address;
    private String description;
    private String imageUrl;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private PlaceCategory category;
    private PlaceStatus status;
    private List<PlaceProviderMappingResponse> providerMappings;
    private AdministrativeAreaSummaryResponse administrativeArea;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

