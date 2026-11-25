package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ItineraryAdminResponse {

    private Integer itineraryId;
    private String title;
    private String description;
    private String location;
    private String coverImage;
    private Integer totalDays;
    private BigDecimal budget;
    private String theme;
    private String visibility;
    private String status;
    private Integer viewCount;
    private Integer favoriteCount;
    private Integer ratingCount;
    private Integer commentCount;
    private Integer reuseCount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private CreatorSummaryResponse creator;

    public static ItineraryAdminResponse from(Itinerary itinerary) {
        if (itinerary == null) {
            return null;
        }
        CreatorSummaryResponse creatorDto = null;
        User owner = itinerary.getUser();
        if (owner != null) {
            creatorDto = CreatorSummaryResponse.builder()
                    .userId(owner.getUserId())
                    .username(owner.getUsername())
                    .handle(owner.getHandle())
                    .fullName(owner.getFullName())
                    .avatar(owner.getAvatar())
                    .build();
        }
        return ItineraryAdminResponse.builder()
                .itineraryId(itinerary.getItineraryId())
                .title(itinerary.getTitle())
                .description(itinerary.getDescription())
                .location(itinerary.getLocation())
                .coverImage(itinerary.getCoverImage())
                .totalDays(itinerary.getTotalDays())
                .budget(itinerary.getBudget())
                .theme(itinerary.getTheme())
                .visibility(itinerary.getVisibility() != null ? itinerary.getVisibility().name() : null)
                .status(itinerary.getStatus() != null ? itinerary.getStatus().name() : null)
                .viewCount(itinerary.getViewCount())
                .favoriteCount(itinerary.getFavoriteCount())
                .ratingCount(itinerary.getRatingCount())
                .commentCount(itinerary.getCommentCount())
                .reuseCount(itinerary.getReuseCount())
                .createdAt(itinerary.getCreatedAt())
                .updatedAt(itinerary.getUpdatedAt())
                .creator(creatorDto)
                .build();
    }
}
