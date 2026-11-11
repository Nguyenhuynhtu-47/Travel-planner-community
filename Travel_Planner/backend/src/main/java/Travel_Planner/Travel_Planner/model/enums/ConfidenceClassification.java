package Travel_Planner.Travel_Planner.model.enums;

/**
 * Confidence classification for Place-to-Administrative-Area resolution.
 *
 * Rules:
 * - HIGH_CONFIDENCE: Exact verified code or unambiguous primary-verified administrative match. Eligible for auto-link.
 * - MEDIUM_CONFIDENCE: Secondary verified match or high-probability address-hierarchy match. Eligible for auto-link.
 * - LOW_CONFIDENCE: Incomplete evidence, partial match, or borderline coordinates. Ineligible for auto-link.
 * - AMBIGUOUS: Multiple candidates in different units without disambiguating context. Ineligible for auto-link.
 * - UNVERIFIED: Candidate belongs to quarantined/unverified units (e.g. 12 Bắc Ninh units). FORBIDDEN from linking.
 * - NO_MATCH: No administrative area found or coordinates outside Vietnam territory.
 */
public enum ConfidenceClassification {
    HIGH_CONFIDENCE,
    MEDIUM_CONFIDENCE,
    LOW_CONFIDENCE,
    AMBIGUOUS,
    UNVERIFIED,
    NO_MATCH;

    public boolean isEligibleForAutoLink() {
        return this == HIGH_CONFIDENCE || this == MEDIUM_CONFIDENCE;
    }
}

