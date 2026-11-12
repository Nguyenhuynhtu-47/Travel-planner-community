package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PostItineraryAttachmentResponse {
    private Integer itineraryId;
    private String title;
    private String coverImage;
    private Integer totalDays;
    private BigDecimal budget;
    private String location;
    private Double averageRating;
    private PostAuthorResponse owner;
}

