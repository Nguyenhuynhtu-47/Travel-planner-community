package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuditLogResponse {

    private Long logId;
    private Integer actorId;
    private String actorUsername;
    private AuditActionType actionType;
    private AuditTargetType targetType;
    private String targetId;
    private String reason;
    private AuditResultStatus resultStatus;
    private String ipAddress;
    private String correlationId;
    private LocalDateTime createdAt;

    public static AuditLogResponse fromEntity(AuditLog entity) {
        return AuditLogResponse.builder()
                .logId(entity.getLogId())
                .actorId(entity.getActorId())
                .actorUsername(entity.getActorUsername())
                .actionType(entity.getActionType())
                .targetType(entity.getTargetType())
                .targetId(entity.getTargetId())
                .reason(entity.getReason())
                .resultStatus(entity.getResultStatus())
                .ipAddress(entity.getIpAddress())
                .correlationId(entity.getCorrelationId())
                .createdAt(entity.getCreatedAt())
                .build();
    }
}
