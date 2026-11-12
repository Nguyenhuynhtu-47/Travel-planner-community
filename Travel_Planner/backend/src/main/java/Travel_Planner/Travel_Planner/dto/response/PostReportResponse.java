package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.ReportStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PostReportResponse {
    private Long reportId;
    private Long postId;
    private PostAuthorResponse reporter;
    private String reason;
    private String details;
    private ReportStatus status;
    private LocalDateTime createdAt;
    private LocalDateTime resolvedAt;
    private PostAuthorResponse resolvedBy;
}

