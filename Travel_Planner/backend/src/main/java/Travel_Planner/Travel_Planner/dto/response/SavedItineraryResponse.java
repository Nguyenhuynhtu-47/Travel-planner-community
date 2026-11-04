package Travel_Planner.Travel_Planner.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavedItineraryResponse {
    private Integer saveId;
    private Integer itineraryId;
    private boolean saved;
    private LocalDateTime savedAt;

    @JsonIgnore
    private boolean newlyCreated;
}

