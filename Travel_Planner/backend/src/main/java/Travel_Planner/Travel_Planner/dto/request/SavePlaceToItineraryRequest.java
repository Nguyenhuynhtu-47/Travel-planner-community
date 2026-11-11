package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavePlaceToItineraryRequest {

    @NotNull(message = "placeId không được để trống")
    private Long placeId;
}

