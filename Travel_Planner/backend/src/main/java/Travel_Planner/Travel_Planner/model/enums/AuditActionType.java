package Travel_Planner.Travel_Planner.model.enums;

/**
 * Canonical administrative audit actions and their non-overridable durability policy.
 */
public enum AuditActionType {
    USER_BAN(AuditPolicy.STRICT),
    USER_UNBAN(AuditPolicy.STRICT),
    USER_ROLE_CHANGE(AuditPolicy.STRICT),
    USER_SESSIONS_REVOKE(AuditPolicy.STRICT),
    ITINERARY_MODERATE(AuditPolicy.STRICT),
    ITINERARY_PRIVATE_INSPECT(AuditPolicy.STRICT),
    POST_MODERATE(AuditPolicy.STRICT),
    POST_PURGE(AuditPolicy.STRICT),
    REPORT_RESOLVE(AuditPolicy.STRICT),
    PLACE_ADMIN_AREA_LINK(AuditPolicy.STRICT),
    PLACE_ADMIN_AREA_BATCH_RESOLVE(AuditPolicy.STRICT),
    SETTING_UPDATE(AuditPolicy.STRICT),
    MAINTENANCE_TOGGLE(AuditPolicy.STRICT),
    AUDIT_EXPORT(AuditPolicy.STRICT),
    AUDIT_EXPORT_DELIVERY_FAILED(AuditPolicy.STRICT),
    TELEMETRY_OPERATIONAL(AuditPolicy.BEST_EFFORT_TELEMETRY);

    private final AuditPolicy policy;

    AuditActionType(AuditPolicy policy) {
        this.policy = policy;
    }

    public AuditPolicy getPolicy() {
        return policy;
    }

    public boolean isStrict() {
        return policy == AuditPolicy.STRICT;
    }
}
