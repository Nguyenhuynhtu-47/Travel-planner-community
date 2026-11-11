package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlaceProviderMappingResponse {
    private Long mappingId;
    private String provider;
    private String providerPlaceId;
    private String providerType;
    private LocalDateTime lastSyncedAt;
}

