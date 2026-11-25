package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.exception.AuditTrailPersistenceException;
import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.enums.AuditPolicy;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.util.AuditContextResolver;
import Travel_Planner.Travel_Planner.util.DataMaskingUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;

@Service
public class AuditLogServiceImpl implements AuditLogService {

    private static final Logger log = LoggerFactory.getLogger(AuditLogServiceImpl.class);
    private static final Logger telemetryLog = LoggerFactory.getLogger("AUDIT_TELEMETRY");

    private final AuditLogRepository auditLogRepository;
    private final DataMaskingUtil dataMaskingUtil;
    private final AuditContextResolver auditContextResolver;
    private TelemetryEmitter telemetryEmitter;

    @FunctionalInterface
    public interface TelemetryEmitter {
        void emit(String actorUsername, String action, String targetType, String targetId, String payloadJson, String correlationId);
    }

    @Autowired
    public AuditLogServiceImpl(
            AuditLogRepository auditLogRepository,
            DataMaskingUtil dataMaskingUtil,
            AuditContextResolver auditContextResolver) {
        this.auditLogRepository = auditLogRepository;
        this.dataMaskingUtil = dataMaskingUtil;
        this.auditContextResolver = auditContextResolver;
        this.telemetryEmitter = (actorUsername, action, targetType, targetId, payloadJson, correlationId) ->
                telemetryLog.info("[TELEMETRY] actor={} action={} targetType={} targetId={} correlationId={} payload={}",
                        actorUsername, action, targetType, targetId, correlationId, payloadJson);
    }

    public void setTelemetryEmitter(TelemetryEmitter telemetryEmitter) {
        if (telemetryEmitter != null) {
            this.telemetryEmitter = telemetryEmitter;
        }
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRED, readOnly = false)
    public AuditLog logStrictAction(AuditCommand command) {
        return persistStrictAudit(command);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW, readOnly = false)
    public AuditLog logIsolatedOutcome(AuditCommand command) {
        return persistStrictAudit(command);
    }

    @Override
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public void recordBestEffortTelemetry(AuditCommand command) {
        if (command == null || command.getActionType() == null || command.getTargetType() == null) {
            throw new IllegalArgumentException("Telemetry command, actionType, and targetType must not be null.");
        }
        if (command.getActionType().getPolicy() == AuditPolicy.STRICT) {
            throw new IllegalArgumentException(
                    "Strict audit action " + command.getActionType()
                            + " cannot be downgraded to best-effort telemetry.");
        }

        try {
            AuditContextResolver.AuditActor actor = auditContextResolver.resolveTelemetryActorOrSystem();
            AuditContextResolver.AuditRequestMetadata metadata = auditContextResolver.resolveRequestMetadata(
                    command.getIpAddress(), command.getUserAgent(), command.getCorrelationId());
            String maskedPayload = dataMaskingUtil.toMaskedJson(command.getAfterSnapshot());

            telemetryEmitter.emit(
                    actor.username(),
                    command.getActionType().name(),
                    command.getTargetType().name(),
                    AuditContextResolver.sanitizeAndTruncate(command.getTargetId(), 100),
                    maskedPayload,
                    metadata.correlationId());
        } catch (Exception ex) {
            // Best-effort telemetry policy: log warning cleanly without disclosing snapshots or rolling back callers
            log.warn("Best-effort telemetry failed for action={}, targetType={}, targetId={}: {}",
                    command.getActionType(), command.getTargetType(), command.getTargetId(), ex.getMessage());
        }
    }

    private AuditLog persistStrictAudit(AuditCommand command) {
        validateStrictCommand(command);

        if (TransactionSynchronizationManager.isSynchronizationActive()
                && TransactionSynchronizationManager.isCurrentTransactionReadOnly()) {
            throw new AuditTrailPersistenceException(
                    "Strict audit cannot be persisted inside a read-only transaction.");
        }

        AuditContextResolver.AuditActor actor =
                auditContextResolver.resolveAuthenticatedActor(command.getExpectedActorUsername());
        AuditContextResolver.AuditRequestMetadata metadata =
                auditContextResolver.resolveRequestMetadata(
                        command.getIpAddress(), command.getUserAgent(), command.getCorrelationId());

        String beforeJson = dataMaskingUtil.toMaskedJson(command.getBeforeSnapshot());
        String afterJson = dataMaskingUtil.toMaskedJson(command.getAfterSnapshot());

        AuditLog entry = AuditLog.builder()
                .actorId(actor.userId())
                .actorUsername(actor.username())
                .actionType(command.getActionType())
                .targetType(command.getTargetType())
                .targetId(AuditContextResolver.sanitizeAndTruncate(command.getTargetId(), 100))
                .reason(AuditContextResolver.sanitizeAndTruncate(command.getReason(), 255))
                .resultStatus(command.getResultStatus() != null ? command.getResultStatus() : AuditResultStatus.SUCCESS)
                .beforeDataJson(beforeJson)
                .afterDataJson(afterJson)
                .ipAddress(metadata.ipAddress())
                .userAgent(metadata.userAgent())
                .correlationId(metadata.correlationId())
                .createdAt(LocalDateTime.now())
                .build();

        try {
            return auditLogRepository.saveAndFlush(entry);
        } catch (RuntimeException ex) {
            log.error("[STRICT_AUDIT_FAILURE] Failed to persist audit log for action={}, targetType={}, targetId={}, correlationId={}",
                    command.getActionType(),
                    command.getTargetType(),
                    command.getTargetId(),
                    metadata.correlationId(),
                    ex);
            throw new AuditTrailPersistenceException(AuditTrailPersistenceException.DEFAULT_SAFE_MESSAGE, ex);
        }
    }

    private void validateStrictCommand(AuditCommand command) {
        if (command == null) {
            throw new IllegalArgumentException("Audit command must not be null.");
        }
        if (command.getActionType() == null) {
            throw new IllegalArgumentException("Audit actionType must not be null.");
        }
        if (command.getActionType().getPolicy() != AuditPolicy.STRICT) {
            throw new IllegalArgumentException(
                    "Action " + command.getActionType() + " does not have STRICT audit policy.");
        }
        if (command.getTargetType() == null) {
            throw new IllegalArgumentException("Audit targetType must not be null.");
        }
        if (command.getTargetId() == null || command.getTargetId().isBlank()) {
            throw new IllegalArgumentException("Audit targetId must not be blank.");
        }
    }
}
