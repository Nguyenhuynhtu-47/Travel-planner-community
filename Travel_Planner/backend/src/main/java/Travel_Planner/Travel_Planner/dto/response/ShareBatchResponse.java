package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.ShareTargetType;
import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShareBatchResponse {
    private ShareTargetType targetType;
    private Long targetId;
    private int totalRequested;
    private int successCount;
    private int failedCount;
    private List<ShareBatchItemResponse> results;
}
