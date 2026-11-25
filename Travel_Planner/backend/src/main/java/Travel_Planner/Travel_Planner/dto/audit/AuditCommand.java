package Travel_Planner.Travel_Planner.dto.audit;

import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import lombok.Builder;
import lombok.Getter;

/**
 * Internal service-layer command for recording an audit event.
 * Actor identity is NOT accepted as an arbitrary input field; it is always
 * resolved from the trusted Spring SecurityContext at the backend.
 */
@Getter
@Builder
public class AuditCommand {

    private final AuditActionType actionType;
    private final AuditTargetType targetType;
    private final String targetId;
    private final String reason;

    @Builder.Default
    private final AuditResultStatus resultStatus = AuditResultStatus.SUCCESS;

    private final Object beforeSnapshot;
    private final Object afterSnapshot;

    /**
     * Optional defensive assertion: if supplied by a service method, it must match
     * the currently authenticated SecurityContext principal or the request is rejected.
     */
    private final String expectedActorUsername;

    /**
     * Optional fallback metadata only used when executed outside an HTTP servlet request
     * (e.g. background jobs). Inside HTTP requests, RequestContextHolder metadata takes precedence.
     */
    private final String ipAddress;
    private final String userAgent;
    private final String correlationId;
}
