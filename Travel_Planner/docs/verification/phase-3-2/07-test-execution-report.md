# Phase 3.2 — Test Execution & Regression Audit Report
**Target Snapshot:** 2026-09-20  
**Phase:** 3.2 — Place–Administrative Area Linking & Resolution  
**Execution Date:** 2026-11-11

---

## 1. Summary of Test Execution Suites

| Test Suite / Target | Total Tests Run | Passed | Failed | Skipped | Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Phase 3.2 Test Suite** | 28 | 28 | 0 | 0 | **PASS (100%)** |
| **Backend Full Regression (`mvnw test`)** | 390 | 390 | 0 | 0 | **PASS (100%)** |
| **Frontend Web (`flutter test`)** | 33 | 33 | 0 | 0 | **PASS (100%)** |
| **Frontend Mobile (`flutter test`)** | 367 | 364 | 3* | 0 | **PASS (Baseline Preserved)** |

*\*Note: The 3 mobile test failures are pre-existing baseline failures documented in development log sessions (explore_test, rating_ui_layout_test).*

---

## 2. Phase 3.2 Specific Test Suite Details

### 2.1 `AdministrativeAreaResolverTest` (8 Tests — 100% PASS)
- `testResolve_ExactVerifiedCode`: Verifies Priority 1 exact code match for Tier A units with `HIGH_CONFIDENCE`.
- `testResolve_SecondaryVerifiedCode`: Verifies Priority 1 exact code match for Tier B units with `MEDIUM_CONFIDENCE`.
- `testResolve_QuarantinedBacNinhCode`: Parameterized test across all 12 quarantined codes verifying immediate rejection (`confidence=UNVERIFIED`, `resolvedArea=null`, `eligibleForAutoLink=false`).
- `testResolve_StructuredAddressMatch`: Verifies decomposition of address "Hoàn Kiếm, Hà Nội" into ward `00070`.
- `testResolve_ProvinceLevelFallback`: Verifies fallback to province `68` for "Đà Lạt, Lâm Đồng".
- `testResolve_CoordinatesOutOfBounds`: Verifies warning generation for coordinates outside Vietnam `[8.0-24.0, 102.0-110.0]`.
- `testResolve_AmbiguousCandidates`: Verifies that ambiguous communes of equal specificity return `confidence=AMBIGUOUS` with candidate lists attached.
- `testResolve_NoMatch`: Verifies `NO_MATCH` for empty/unresolvable text.

### 2.2 `PlaceAdministrativeAreaServiceTest` (8 Tests — 100% PASS)
- `testPreviewResolution`: Verifies non-mutating preview resolution.
- `testResolveAndLink_AutoLinkEligible`: Verifies auto-linking for high/medium confidence results.
- `testResolveAndLink_QuarantinedRejection`: Verifies service rejection of quarantined codes.
- `testResolveAndLink_ExistingLinkProtected`: Verifies that `overwriteExisting=false` preserves valid links.
- `testManualLink_Success`: Verifies manual override by administrator for non-quarantined codes.
- `testManualLink_QuarantinedThrowsBadRequest`: Parameterized test across all 12 quarantined codes asserting `BadRequestException` (HTTP 400).
- `testUnlink`: Verifies explicit unlinking setting `administrative_area_id = NULL`.
- `testBatchResolveAndLink_DryRun`: Verifies batch execution report without persisting mutations.

### 2.3 `PlaceAdministrativeAreaMigrationRunnerTest` (4 Tests — 100% PASS)
- `testTableSchemaAndForeignKeyExists`: Verifies column `administrative_area_id` and foreign key `fk_places_admin_area`.
- `testTrustClassificationPopulated`: Verifies database trust distribution (67 Tier A, 3,276 Tier B, 12 Tier C, 0 Tier D).
- `testRun_Idempotency`: Verifies multi-pass idempotency without errors or data duplication.
- `testSingleConnectionAdvisoryLock`: Verifies acquire and release lifecycle of `place_administrative_area_migration_lock`.

### 2.4 `AdminPlaceAdministrativeAreaControllerTest` (8 Tests — 100% PASS)
- MockMvc integration tests verifying endpoint security (ADMIN role requirement, 403 for unauthorized users), JSON request parsing, and response payload formatting for all Phase 3.2 endpoints under `/api/admin/places`.

---

## 3. Frontend Web Verification

- `flutter analyze`: **No issues found!**
- `flutter test`: **All 33 tests passed!**

---

## 4. Frontend Mobile Verification

- `flutter analyze`: Passed with style/formatting infos.
- `flutter test`: **364 passed, 3 baseline failed**.
  - Confirmed 0 regressions introduced by Phase 3.2.

