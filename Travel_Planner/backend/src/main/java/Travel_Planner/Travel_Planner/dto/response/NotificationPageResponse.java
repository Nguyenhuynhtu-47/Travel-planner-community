package Travel_Planner.Travel_Planner.dto.response;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class NotificationPageResponse {
    private List<NotificationResponse> content;
    private String nextCursor;
    private boolean hasMore;
}
