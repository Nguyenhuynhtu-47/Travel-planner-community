package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class RelationshipContextResponse {
    private String friendshipStatus;
    private String friendRequestDirection;
    private boolean canMessage;
    private boolean canSendFriendRequest;
}
