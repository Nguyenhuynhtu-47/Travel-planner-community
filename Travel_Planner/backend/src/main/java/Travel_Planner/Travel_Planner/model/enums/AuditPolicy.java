package Travel_Planner.Travel_Planner.model.enums;

/**
 * Defines durability and transaction failure policy for audit events.
 */
public enum AuditPolicy {
    /**
     * Mandatory strict audit persisted to audit_logs in the active transaction.
     * Persistence failure must abort and roll back the enclosing business operation.
     */
    STRICT,

    /**
     * Non-mandatory operational telemetry only. Never permitted for administrative
     * mutations persisted in audit_logs.
     */
    BEST_EFFORT_TELEMETRY
}
