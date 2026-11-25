package Travel_Planner.Travel_Planner.dto.audit;

import Travel_Planner.Travel_Planner.model.PostReport;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Allowlist-only snapshot DTO for PostReport audit records.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportAuditSnapshot implements AuditSnapshot {

    private Long reportId;
    private Long postId;
    private String status;
    private String reason;
    private Integer resolvedById;

    public static ReportAuditSnapshot from(PostReport report) {
        if (report == null) {
            return null;
        }
        return ReportAuditSnapshot.builder()
                .reportId(report.getReportId())
                .postId(report.getPost() != null ? report.getPost().getPostId() : null)
                .status(report.getStatus() != null ? report.getStatus().name() : null)
                .reason(report.getReason())
                .resolvedById(report.getResolvedBy() != null ? report.getResolvedBy().getUserId() : null)
                .build();
    }
}
