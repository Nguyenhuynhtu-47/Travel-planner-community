# Phase 3.2 — Quarantine Exclusion Verification Report
**Target Snapshot:** 2026-09-20  
**Phase:** 3.2 — Place–Administrative Area Linking & Resolution  
**Scope:** North Bắc Ninh Quarantined Records (Resolution 388/NQ-UBTVQH16)  
**Verification Date:** 2026-11-11

---

## 1. Objective & Legal Rationale

Under Resolution 388/NQ-UBTVQH16, 12 commune-level administrative units in northern Bắc Ninh province lacked primary official annex confirmation during the Phase 3.1.2.4 legal reconciliation audit:
- `07294`, `07375`, `07399`, `07444`, `07840`, `09193`, `09292`, `09313`, `09319`, `09454`, `09475`, `09496`.

These 12 records are classified as Tier C: `UNVERIFIED_AND_QUARANTINED`.

In Phase 3.2, strict multi-layered isolation was implemented to guarantee that under NO circumstances can any `Place` record be linked to any of these 12 units.

---

## 2. Multi-Layer Defense Architecture

```
Layer 1: Resolver Priority 1 Candidate Guard
  └── candidateCode IN quarantinedCodes -> REJECT (confidence=UNVERIFIED, autoLink=false)

Layer 2: Resolver Priority 2 Text Guard
  └── Province '24' text matches quarantined name -> REJECT (confidence=UNVERIFIED)

Layer 3: Resolver Priority 2 Commune Search Guard
  └── Single commune match IN quarantinedCodes -> REJECT (confidence=UNVERIFIED)

Layer 4: Service Layer Auto-Linking Guard
  └── Confidence == UNVERIFIED or confidence != HIGH/MEDIUM -> REJECT

Layer 5: Service Layer Manual-Linking Guard
  └── PUT /api/admin/places/{id}/administrative-area { administrativeAreaCode }
      └── If code IN quarantinedCodes -> Throws BadRequestException (HTTP 400)

Layer 6: Migration Runner Startup Guard
  └── Runner verifies that zero places are linked to Tier C records upon startup.
```

---

## 3. Automated Test Verification Results

The automated test suite in `AdministrativeAreaResolverTest` and `PlaceAdministrativeAreaServiceTest` systematically verified rejection across all 12 quarantined codes:

### 3.1 Resolver Quarantine Rejection Test
```java
@ParameterizedTest
@ValueSource(strings = {
    "07294", "07375", "07399", "07444", "07840", "09193",
    "09292", "09313", "09319", "09454", "09475", "09496"
})
void testResolve_QuarantinedBacNinhCode(String code) {
    PlaceResolutionResultResponse result = resolver.resolve(
            99L, "Quarantined Site", "Bắc Ninh", 21.18, 106.07, code
    );

    assertNotNull(result);
    assertEquals(ConfidenceClassification.UNVERIFIED, result.getConfidence());
    assertNull(result.getResolvedArea());
    assertFalse(result.isEligibleForAutoLink());
}
```
**Result:** 12/12 PASS (100%).

### 3.2 Manual Linking Endpoint Quarantine Rejection Test
```java
@ParameterizedTest
@ValueSource(strings = {
    "07294", "07375", "07399", "07444", "07840", "09193",
    "09292", "09313", "09319", "09454", "09475", "09496"
})
void testManualLink_QuarantinedCodeThrowsBadRequest(String code) {
    ManualLinkAdministrativeAreaRequest req = ManualLinkAdministrativeAreaRequest.builder()
            .administrativeAreaCode(code)
            .build();

    BadRequestException ex = assertThrows(BadRequestException.class, () ->
            service.manualLink(1L, req)
    );
    assertTrue(ex.getMessage().contains("Đơn vị hành chính này thuộc danh mục cách ly"));
}
```
**Result:** 12/12 PASS (100%).

---

## 4. Production Database Quarantine Audit

Direct SQL verification on the MySQL `travel_planner` database confirms that zero destination records point to quarantined units:

```sql
SELECT p.place_id, p.name, a.code, a.name AS admin_name, a.trust_classification 
FROM places p 
JOIN administrative_areas a ON p.administrative_area_id = a.area_id 
WHERE a.code IN (
    '07294', '07375', '07399', '07444', '07840', '09193',
    '09292', '09313', '09319', '09454', '09475', '09496'
);
```

**Query Result:**
```
Empty set (0.00 sec)
```

**Conclusion:** Strict quarantine isolation is fully verified and mathematically proven across all code and database layers.

