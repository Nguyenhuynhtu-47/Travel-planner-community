package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.FriendshipStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class FriendRequestResponse {
    private Long friendshipId;
    private FriendshipStatus status;
    private String direction;
    private PublicUserSummaryResponse otherUser;
    private LocalDateTime createdAt;
}
