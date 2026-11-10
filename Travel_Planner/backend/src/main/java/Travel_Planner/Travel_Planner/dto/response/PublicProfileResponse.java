package Travel_Planner.Travel_Planner.dto.response;

import java.time.LocalDateTime;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class PublicProfileResponse {
    private Integer userId;
    private String handle;
    private String username;
    private String fullName;
    private String avatar;
    private String bio;
    private LocalDateTime createdAt;
    private long followerCount;
    private long followingCount;
    @JsonProperty("isFollowing") private boolean isFollowing;
    @JsonProperty("isOwnProfile") private boolean isOwnProfile;
    private String friendshipStatus;
    private String friendRequestDirection;
    private Boolean canMessage;
    private Boolean canSendFriendRequest;
}
