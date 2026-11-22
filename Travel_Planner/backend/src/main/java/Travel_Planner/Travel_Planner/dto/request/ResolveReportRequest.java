package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.ReportStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResolveReportRequest {
    private ReportStatus resolution;
    private ReportStatus status;
}
