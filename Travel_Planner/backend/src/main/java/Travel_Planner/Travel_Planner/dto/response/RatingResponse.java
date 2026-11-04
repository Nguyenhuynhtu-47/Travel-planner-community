package Travel_Planner.Travel_Planner.dto.response;

import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RatingResponse {
    private Integer ratingId;
    private Integer itineraryId;
    private Integer score;
    private Double averageRating;
    private Integer ratingCount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @JsonIgnore
    private boolean newlyCreated;
}
