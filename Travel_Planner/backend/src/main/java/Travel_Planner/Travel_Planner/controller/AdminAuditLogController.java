package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.AuditLogDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.AuditLogResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import Travel_Planner.Travel_Planner.service.AdminAuditLogService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Strictly read-only Admin Controller for querying immutable audit logs.
 * Intentionally exposes NO POST, PUT, PATCH, or DELETE endpoints.
 */
@RestController
@PreAuthorize("hasRole('ADMIN')")
@RequestMapping("/api/admin/audit-logs")
public class AdminAuditLogController {

    private final AdminAuditLogService adminAuditLogService;

    public AdminAuditLogController(AdminAuditLogService adminAuditLogService) {
        this.adminAuditLogService = adminAuditLogService;
    }

    @GetMapping
    public ResponseEntity<PageResponse<AuditLogResponse>> getAuditLogs(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer actorId,
            @RequestParam(required = false) String actorUsername,
            @RequestParam(required = false) AuditActionType actionType,
            @RequestParam(required = false) AuditTargetType targetType,
            @RequestParam(required = false) String targetId,
            @RequestParam(required = false) AuditResultStatus resultStatus,
            @RequestParam(required = false) String fromDate,
            @RequestParam(required = false) String toDate,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(adminAuditLogService.getAuditLogs(
                keyword,
                actorId,
                actorUsername,
                actionType,
                targetType,
                targetId,
                resultStatus,
                fromDate,
                toDate,
                page,
                size));
    }

    @GetMapping("/{id}")
    public ResponseEntity<AuditLogDetailResponse> getAuditLogById(@PathVariable("id") Long id) {
        return ResponseEntity.ok(adminAuditLogService.getAuditLogById(id));
    }

    @GetMapping("/action-types")
    public ResponseEntity<List<String>> getActionTypes() {
        return ResponseEntity.ok(adminAuditLogService.getActionTypes());
    }
}
