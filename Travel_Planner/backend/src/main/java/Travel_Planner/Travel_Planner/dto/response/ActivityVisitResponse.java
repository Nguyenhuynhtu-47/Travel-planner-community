package Travel_Planner.Travel_Planner.dto.response;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class ActivityVisitResponse {
    private Integer activityId;
    private Boolean visited;
    private LocalDateTime updatedAt;
}
