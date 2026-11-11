package Travel_Planner.Travel_Planner.model.enums;

/**
 * Trust Classification for Administrative Areas established in Phase 3.1.2.4 / 3.1.2.4.1.
 * 
 * Defines the statutory verification status and runtime eligibility:
 * - VERIFIED_AND_TRUSTED: 67 units (34 provinces/central cities + 33 primary verified communes:
 *   10 Đồng Nai wards, 13 special zones, 10 core municipal wards). Fully trusted for Place linking.
 * - VERIFIED_WITH_LIMITATIONS: 3,276 communes verified via GSO 2025 baseline / QĐ 19/2025/QĐ-TTg.
 * - UNVERIFIED_AND_QUARANTINED: 12 Bắc Ninh communes lacking official gazette annex for NQ 388/NQ-UBTVQH16.
 *   STRICTLY FORBIDDEN from participating in runtime Place linking.
 * - MISMATCH: 0 units. Ineligible for runtime use.
 */
public enum AdministrativeAreaTrustClassification {
    VERIFIED_AND_TRUSTED,
    VERIFIED_WITH_LIMITATIONS,
    UNVERIFIED_AND_QUARANTINED,
    MISMATCH;

    public boolean isEligibleForLinking() {
        return this == VERIFIED_AND_TRUSTED || this == VERIFIED_WITH_LIMITATIONS;
    }

    public boolean isQuarantined() {
        return this == UNVERIFIED_AND_QUARANTINED;
    }
}

