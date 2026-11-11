# Phase 3.3.1 — Document 00: Baseline & Git State Audit

## 1. Executive Summary & Git Baseline

This document establishes the verified baseline for Phase 3.3.1 (Post-Implementation Audit & Gap Remediation for Phase 3.3). Phase 3.3 delivered location discovery, administrative area catalog search, place administrative filtering, and spatial radius search. Phase 3.3.1 conducts an independent forensic review and targeted gap remediation.

| Audit Parameter | Verified Status | Evidence / Notes |
| :--- | :--- | :--- |
| **Target Branch** | `develop` | Verified via `git branch --show-current` |
| **Baseline Git HEAD** | `9902ccd` | `9902ccd docs: update project specifications, development logs, and architecture audit documentation` |
| **Git Working Tree Policy** | STRICTLY NO COMMIT, NO PUSH | Confirmed by zero commits, local workspace modifications only |
| **Target Snapshot Date** | 2026-09-20 | Post-2025 Resolution 388/NQ-UBTVQH16 canonical administrative baseline |

---

## 2. Tracked File Changes Accounting

Phase 3.3 and Phase 3.3.1 modify existing files within the backend service and controller layers without altering database schema migrations or existing place coordinates.

```text
Tracked Modified Files:
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/PlaceController.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/PlaceDetailResponse.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/PlaceResponse.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/Place.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/PlaceRepository.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/PlaceService.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationRankingServiceImpl.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java
  Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/PlaceServiceImpl.java
  Travel_Planner/docs/ai/09-development-log.md
  Travel_Planner/docs/ai/12-project-status-and-next-steps.md
```

### Detailed File Analysis:
1. `PlaceController.java`: Added query parameters for `administrativeAreaCode`, `administrativeAreaId`, `latitude`, `longitude`, `radiusKm`.
2. `PlaceResponse.java` & `PlaceDetailResponse.java`: Added `administrativeArea` (`AdministrativeAreaSummaryResponse`) and `distanceKm`.
3. `Place.java`: Foreign key association `administrative_area_id` mapped to `AdministrativeArea`.
4. `PlaceRepository.java`: Added `findInBoundingBox`, `searchPlacesWithAdminArea`, `countByAdministrativeArea_AreaId`.
5. `SecurityConfig.java`: Publicly permitted `/api/administrative-areas/**` and `/api/places/**`.
6. `PlaceService.java` & `PlaceServiceImpl.java`: Extended search capabilities for spatial radius filtering and administrative filtering. Hardened with coordinate bounds clamping and radius validation in Phase 3.3.1.
7. `LocationServiceImpl.java`: Added Authoritative Priority Pipeline (`searchInternalCatalog`). Remediated in Phase 3.3.1 to bypass internal administrative short-circuiting on POI intents (`POI_IN_LOCATION`, `GENERIC_POI`).
8. `LocationRankingServiceImpl.java`: Composite relevance ranking and deduplication. Remediated in Phase 3.3.1 to penalize administrative boundaries (-30.0) and withhold +50.0 SYSTEM boost during POI searches.

---

## 3. Untracked Artifacts Accounting

New components introduced during Phase 3.1, 3.2, and 3.3 reside in untracked files:
- Administrative Area entities, DTOs, controllers, and services (`model/AdministrativeArea.java`, `controller/AdministrativeAreaController.java`, etc.).
- Resolver infrastructure (`resolver/AdministrativeAreaResolverImpl.java`).
- Migration and validation runners (`config/AdministrativeAreaMigrationRunner.java`, `config/PlaceAdministrativeAreaMigrationRunner.java`).
- Canonical dataset resources (`src/main/resources/data/vietnam_administrative_units_canonical_2026.json`).
- Automated integration test suites (`src/test/java/.../LocationSearchAndFilteringTest.java`, `PlaceAdministrativeAreaServiceTest.java`, etc.).

---

## 4. Verification Checksum & Invariant Baseline

1. **Canonical Dataset Checksum**: `af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`
2. **Administrative Units Count**: Exactly 34 province-level units, 3,321 commune-level units (Total: 3,355).
3. **Quarantine Invariant**: Exactly 12 units under Resolution 388/NQ-UBTVQH16 in Northern Bắc Ninh assigned `UNVERIFIED_AND_QUARANTINED`.
4. **Place Entity Count**: 24 canonical records in database. Places 11, 12, 20, 22 retain `administrative_area_id = NULL`.
5. **Activity Entity Count**: 121 canonical records in database across 20 columns with zero direct foreign keys to `administrative_areas`.

