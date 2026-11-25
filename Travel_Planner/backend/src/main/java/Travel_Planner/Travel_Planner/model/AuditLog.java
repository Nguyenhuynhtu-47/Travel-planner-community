package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditPolicy;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Immutable;

import java.time.LocalDateTime;

/**
 * Immutable, append-only JPA entity representing an administrative audit trail entry.
 * Intentionally decoupled from business entities (e.g. User, Itinerary, Post) so audit
 * records remain preserved across account or content lifecycle changes.
 */
@Entity
@Immutable
@Table(name = "audit_logs", indexes = {
        @Index(name = "idx_audit_actor_created", columnList = "actor_id, created_at"),
        @Index(name = "idx_audit_action_created", columnList = "action_type, created_at"),
        @Index(name = "idx_audit_target_created", columnList = "target_type, target_id, created_at"),
        @Index(name = "idx_audit_created_at", columnList = "created_at"),
        @Index(name = "idx_audit_correlation_id", columnList = "correlation_id")
})
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "log_id", updatable = false)
    private Long logId;

    @Column(name = "actor_id", nullable = false, updatable = false)
    private Integer actorId;

    @Column(name = "actor_username", nullable = false, length = 50, updatable = false)
    private String actorUsername;

    @Enumerated(EnumType.STRING)
    @Column(name = "action_type", nullable = false, length = 50, updatable = false)
    private AuditActionType actionType;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_type", nullable = false, length = 50, updatable = false)
    private AuditTargetType targetType;

    @Column(name = "target_id", nullable = false, length = 100, updatable = false)
    private String targetId;

    @Column(name = "reason", length = 255, updatable = false)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(name = "result_status", nullable = false, length = 30, updatable = false)
    @Builder.Default
    private AuditResultStatus resultStatus = AuditResultStatus.SUCCESS;

    @Column(name = "before_data_json", columnDefinition = "TEXT", updatable = false)
    private String beforeDataJson;

    @Column(name = "after_data_json", columnDefinition = "TEXT", updatable = false)
    private String afterDataJson;

    @Column(name = "ip_address", length = 45, updatable = false)
    private String ipAddress;

    @Column(name = "user_agent", length = 255, updatable = false)
    private String userAgent;

    @Column(name = "correlation_id", length = 64, updatable = false)
    private String correlationId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (resultStatus == null) {
            resultStatus = AuditResultStatus.SUCCESS;
        }
        if (actionType == null || actionType.getPolicy() != AuditPolicy.STRICT) {
            throw new IllegalStateException("Only STRICT audit actions may be persisted to audit_logs.");
        }
    }

    @PreUpdate
    protected void preventUpdate() {
        throw new UnsupportedOperationException("AuditLog is strictly append-only; updates are prohibited.");
    }

    @PreRemove
    protected void preventRemove() {
        throw new UnsupportedOperationException("AuditLog is strictly append-only; deletions are prohibited.");
    }
}
