package Travel_Planner.Travel_Planner.dto.response;

import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeleteRatingResponse {
    private String message;
    private Integer itineraryId;
    private Double averageRating;
    private Integer ratingCount;
}

