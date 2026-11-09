package Travel_Planner.Travel_Planner.dto.response;

import java.time.LocalDateTime;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class PublicProfileResponse {
    private Integer userId;
    private String username;
    private String fullName;
    private String avatar;
    private String bio;
    private LocalDateTime createdAt;
    private long followerCount;
    private long followingCount;
    @JsonProperty("isFollowing") private boolean isFollowing;
    @JsonProperty("isOwnProfile") private boolean isOwnProfile;
}
