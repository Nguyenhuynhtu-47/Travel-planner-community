package Travel_Planner.Travel_Planner.dto.audit;

import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.util.DataMaskingUtil;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Allowlist-only snapshot DTO for User audit records.
 * Excludes password hashes, token versions, phone numbers, addresses, and internal credentials.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserAuditSnapshot implements AuditSnapshot {

    private Integer userId;
    private String username;
    private String handle;
    private String email;
    private String role;
    private String status;

    public static UserAuditSnapshot from(User user) {
        if (user == null) {
            return null;
        }
        return UserAuditSnapshot.builder()
                .userId(user.getUserId())
                .username(user.getUsername())
                .handle(user.getHandle())
                .email(DataMaskingUtil.maskEmail(user.getEmail()))
                .role(user.getRole() != null ? user.getRole().name() : null)
                .status(user.getStatus() != null ? user.getStatus().name() : null)
                .build();
    }
}
