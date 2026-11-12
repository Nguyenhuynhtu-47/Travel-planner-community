package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.PostVisibility;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PostResponse {
    private Long postId;
    private String content;
    private PostAuthorResponse author;
    private List<String> mediaUrls;
    private List<Long> mediaAssetIds;
    private PostItineraryAttachmentResponse itinerary;
    private boolean itineraryUnavailable;
    private String itineraryUnavailableReason;
    private PostVisibility visibility;
    private PostStatus status;
    private int likeCount;
    private int commentCount;

    @JsonProperty("isLikedByMe")
    private boolean isLikedByMe;

    @JsonProperty("isOwner")
    private boolean isOwner;

    public boolean isLikedByMe() {
        return isLikedByMe;
    }

    public boolean isOwner() {
        return isOwner;
    }

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // Backward-compatibility getters for clients checking likedByMe / owner
    @JsonProperty("likedByMe")
    public boolean getLikedByMe() {
        return isLikedByMe;
    }

    @JsonProperty("owner")
    public boolean getOwner() {
        return isOwner;
    }
}

