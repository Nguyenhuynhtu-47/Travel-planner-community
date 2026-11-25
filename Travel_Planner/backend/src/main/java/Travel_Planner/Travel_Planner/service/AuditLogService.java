package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.model.AuditLog;

/**
 * Shared backend service for recording immutable administrative audit trails
 * and strictly isolated operational telemetry.
 */
public interface AuditLogService {

    /**
     * Records a mandatory Strict Audit entry inside the caller's active transaction
     * (Propagation.REQUIRED, readOnly = false) and flushes immediately.
     * Any persistence failure throws AuditTrailPersistenceException and rolls back
     * the enclosing business transaction.
     */
    AuditLog logStrictAction(AuditCommand command);

    /**
     * Records an isolated outcome entry (e.g. FAILED / DELIVERY_FAILED after an outer failure)
     * in a new physical transaction (Propagation.REQUIRES_NEW, readOnly = false).
     * Still enforces Strict Audit durability: persistence failure throws AuditTrailPersistenceException.
     */
    AuditLog logIsolatedOutcome(AuditCommand command);

    /**
     * Emits a non-mandatory operational telemetry event outside database transactions.
     * Strictly rejects any AuditActionType whose policy is STRICT.
     * Failures in the telemetry sink are logged cleanly as warnings and do not abort callers.
     */
    void recordBestEffortTelemetry(AuditCommand command);
}
