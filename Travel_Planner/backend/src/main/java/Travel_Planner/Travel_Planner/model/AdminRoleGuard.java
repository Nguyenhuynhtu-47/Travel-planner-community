package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Standalone synchronization mutex entity for serializing all admin role/status
 * mutations across concurrent requests and preventing loss of the last ACTIVE ADMIN.
 */
@Entity
@Table(name = "admin_role_guard")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AdminRoleGuard {

    public static final String ADMIN_ROLE_MUTEX = "ADMIN_ROLE_MUTEX";

    @Id
    @Column(name = "guard_id")
    private Integer guardId;

    @Column(name = "guard_name", nullable = false, unique = true, length = 50)
    private String guardName;

    @Column(name = "locked_at")
    private LocalDateTime lockedAt;

    @Column(name = "locked_by", length = 50)
    private String lockedBy;
}
