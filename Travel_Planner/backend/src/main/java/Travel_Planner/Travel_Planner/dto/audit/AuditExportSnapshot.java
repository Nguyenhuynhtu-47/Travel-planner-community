package Travel_Planner.Travel_Planner.dto.audit;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.Map;

/**
 * Allowlist-only snapshot DTO for Audit Export metadata.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuditExportSnapshot implements AuditSnapshot {

    private String exportId;
    private String format;
    private Integer recordCount;
    private Map<String, Object> filters;
}
