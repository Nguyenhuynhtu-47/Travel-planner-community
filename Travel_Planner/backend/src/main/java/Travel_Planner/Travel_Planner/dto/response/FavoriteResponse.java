package Travel_Planner.Travel_Planner.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FavoriteResponse {
    private Integer itineraryId;
    private boolean favorited;
    private Integer favoriteCount;

    @JsonIgnore
    private boolean newlyCreated;
}
