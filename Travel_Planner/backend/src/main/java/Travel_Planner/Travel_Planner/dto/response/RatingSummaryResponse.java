package Travel_Planner.Travel_Planner.dto.response;

import lombok.*;

import java.util.Map;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RatingSummaryResponse {
    private Integer itineraryId;
    private Double averageRating;
    private Integer ratingCount;
    private Map<Integer, Long> starCounts;
}

