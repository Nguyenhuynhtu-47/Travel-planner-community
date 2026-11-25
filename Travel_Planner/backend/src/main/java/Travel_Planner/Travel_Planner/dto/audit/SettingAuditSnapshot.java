package Travel_Planner.Travel_Planner.dto.audit;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Allowlist-only snapshot DTO for SystemSetting audit records.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SettingAuditSnapshot implements AuditSnapshot {

    private String settingKey;
    private String settingValue;
    private String settingGroup;
}
