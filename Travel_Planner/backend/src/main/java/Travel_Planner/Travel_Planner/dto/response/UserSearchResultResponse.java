package Travel_Planner.Travel_Planner.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserSearchResultResponse {
    private Integer userId;
    private String handle;
    private String fullName;
    private String avatar;
    private String friendshipStatus;
    private Long friendshipId;
    private String friendRequestDirection;
    @JsonProperty("isSelf")
    private boolean isSelf;
    private boolean canMessage;
    private boolean canContinueConversation;
    private boolean canSendFriendRequest;
}
