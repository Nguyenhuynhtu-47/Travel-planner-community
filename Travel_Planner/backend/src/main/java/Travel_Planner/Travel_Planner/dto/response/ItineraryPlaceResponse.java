package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ItineraryPlaceResponse {

    private Long id;
    private Integer itineraryId;
    private PlaceResponse place;
    private LocalDateTime savedAt;
}

