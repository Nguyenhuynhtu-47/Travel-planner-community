package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.AuditLogDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.AuditLogResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;

import java.util.List;

public interface AdminAuditLogService {

    PageResponse<AuditLogResponse> getAuditLogs(
            String keyword,
            Integer actorId,
            String actorUsername,
            AuditActionType actionType,
            AuditTargetType targetType,
            String targetId,
            AuditResultStatus resultStatus,
            String fromDate,
            String toDate,
            int page,
            int size
    );

    AuditLogDetailResponse getAuditLogById(Long logId);

    List<String> getActionTypes();
}
