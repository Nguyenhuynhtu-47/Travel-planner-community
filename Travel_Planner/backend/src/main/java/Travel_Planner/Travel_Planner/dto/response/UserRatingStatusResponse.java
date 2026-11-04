package Travel_Planner.Travel_Planner.dto.response;

import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserRatingStatusResponse {
    private Integer itineraryId;
    private boolean rated;
    private Integer score;
    private Integer ratingId;
    private LocalDateTime updatedAt;
}

