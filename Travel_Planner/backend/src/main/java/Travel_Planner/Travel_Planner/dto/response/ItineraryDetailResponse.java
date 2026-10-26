package Travel_Planner.Travel_Planner.dto.response;

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
public class ItineraryDetailResponse {
    private Integer itineraryId;
    private String title;
    private String description;
    private String location;
    private String coverImage;
    private Integer totalDays;
    private BigDecimal budget;
    private String theme;
    private String visibility;
    private Integer viewCount;
    private Integer favoriteCount;
    private Integer ratingCount;
    private Integer commentCount;
    private Integer reuseCount;
    private Double averageRating;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private CreatorSummaryResponse creator;
    private List<ItineraryDayResponse> days;
}
