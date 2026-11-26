package Travel_Planner.Travel_Planner.dto.response;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class NotificationActorResponse {
    private Integer userId;
    private String username;
    private String handle;
    private String displayName;
    private String avatar;
}
