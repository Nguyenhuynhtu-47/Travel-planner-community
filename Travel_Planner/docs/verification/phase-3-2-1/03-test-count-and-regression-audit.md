# Phase 3.2.1 — Artifact 03: Test Count & Regression Audit

## 1. Executive Summary: Test Aggregation Audit

In the Phase 3.2 final acceptance report, the total test suite was reported as **815 PASS / 3 FAILED**. An independent audit was conducted during Phase 3.2.1 to verify whether the 28 dedicated Phase 3.2 tests were double-counted in this total.

### Key Audit Finding
The 28 dedicated Phase 3.2 tests (`AdministrativeAreaResolverTest`, `PlaceAdministrativeAreaServiceTest`, `PlaceAdministrativeAreaMigrationRunnerTest`, and `AdminPlaceAdministrativeAreaControllerTest`) are located under `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/`. When `mvnw test` executes, Maven Surefire automatically discovers and executes all `*Test.java` files.

Consequently:
- The 390 passed tests reported by `mvnw test` **already included** the 28 Phase 3.2 tests (362 baseline tests + 28 Phase 3.2 tests = 390 backend tests).
- Summing 390 (backend) + 28 (Phase 3.2 dedicated) + 33 (frontend web) + 364 (frontend mobile) yielded **815**, which double-counted the 28 dedicated tests.

---

## 2. Accurate Stack-Wide Test Inventory

| Layer | Test Runner / Command | Dedicated Phase 3.2 Tests | Pre-existing Tests | Total Unique Tests | Passed | Failed | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Backend (Spring Boot)** | `mvnw test` | 28 | 362 | 390 | 390 | 0 | **100% PASS** |
| **Frontend Web (Flutter Web)** | `flutter test` | 0 | 33 | 33 | 33 | 0 | **100% PASS** |
| **Frontend Mobile (Flutter Mobile)** | `flutter test` | 0 | 367 | 367 | 364 | 3* | **BASELINE PRESERVED** |
| **TOTAL STACK-WIDE** | Multi-runner | **28** | **762** | **790** | **787** | **3\*** | **STABLE (0 Regressions)** |

*\*Note: The 3 mobile failures are pre-existing baseline UI/mock failures documented in historical logs, completely independent of Phase 3.2 backend changes.*

---

## 3. Dedicated Phase 3.2 Test Breakdown (28 Tests)

All 28 dedicated tests executed cleanly with 0 failures, 0 errors, and 0 skipped tests:

### 3.1 `AdministrativeAreaResolverTest` (8 Tests)
1. `testResolve_ExactVerifiedCode`: Priority 1 exact code lookup for Tier A areas returning `HIGH_CONFIDENCE`.
2. `testResolve_SecondaryVerifiedCode`: Priority 1 exact code lookup for Tier B areas returning `MEDIUM_CONFIDENCE`.
3. `testResolve_QuarantinedBacNinhCode`: Rejection of all 12 quarantined codes (`UNVERIFIED`, `resolvedArea=null`).
4. `testResolve_StructuredAddressMatch`: Verification of address token extraction (Ward `00070`).
5. `testResolve_AmbiguousCandidates`: Rejection of auto-linking when multiple candidates tie (`AMBIGUOUS`).
6. `testResolve_NoMatch`: Handling of unrecognizable or foreign address strings (`NO_MATCH`).
7. `testResolve_NullOrBlankAddress`: Graceful handling of empty or null address strings.
8. `testResolve_BoundingBoxCoordinateFilter`: Bounding-box verification ensuring coordinates match province territory.

### 3.2 `PlaceAdministrativeAreaServiceTest` (8 Tests)
1. `testResolveAndLink_EligibleAutoLink`: Auto-linking of high-confidence resolved area.
2. `testResolveAndLink_AlreadyLinked_NoOverwrite`: Idempotent preservation of existing links when `overwriteExisting=false`.
3. `testResolveAndLink_OverwriteExisting`: Successful replacement of existing link when `overwriteExisting=true`.
4. `testResolveAndLink_QuarantinedAreaBlocked`: Safeguard ensuring quarantined units cannot be auto-linked.
5. `testLinkManually_Success`: Admin manual linking to valid, active area.
6. `testLinkManually_QuarantinedArea_ThrowsException`: Throws `BadRequestException` when attempting to manually link to quarantined code.
7. `testUnlink_Success`: Clean removal of administrative area foreign key.
8. `testBatchResolveAndLink_DryRun`: Verification of batch resolution without persisting database changes.

### 3.3 `PlaceAdministrativeAreaMigrationRunnerTest` (4 Tests)
1. `testMigration_DryRun_NoPersist`: Verification that dry-run mode does not modify `places` table.
2. `testMigration_Execution_Idempotent`: Running migration runner repeatedly maintains exactly 20 linked and 4 unlinked.
3. `testMigration_QuarantineSafety`: Verifies that no places are linked to any of the 12 quarantined codes during batch run.
4. `testMigration_AmbiguousSafety`: Verifies that Places 11, 12, 20, 22 remain unlinked (`NULL`).

### 3.4 `AdminPlaceAdministrativeAreaControllerTest` (8 Tests)
1. `testPreviewResolution_Admin`: Verification of preview endpoint (`POST /api/admin/places/{id}/administrative-area/preview`).
2. `testResolveAndLink_Admin`: Verification of resolve & link endpoint (`POST /api/admin/places/{id}/administrative-area/resolve`).
3. `testLinkManually_Success`: Verification of manual link endpoint (`POST /api/admin/places/{id}/administrative-area/link`).
4. `testLinkManually_QuarantinedBacNinh_Rejected`: Validates 400 Bad Request when attempting to link to code `07294`.
5. `testUnlink_Success`: Verification of unlink endpoint (`DELETE /api/admin/places/{id}/administrative-area`).
6. `testBatchResolve_Admin`: Verification of batch resolve endpoint (`POST /api/admin/places/administrative-area/batch-resolve`).
7. `testSecurity_Unauthenticated`: Validates HTTP 401 Unauthorized for unauthenticated requests.
8. `testSecurity_NonAdmin`: Validates HTTP 403 Forbidden for authenticated users without `ROLE_ADMIN`.

---

## 4. Mobile Test Baseline Failure Audit

During execution of `flutter test test/explore_test.dart test/features/social/rating_ui_layout_test.dart` in `Travel_Planner/frontend/mobile`, the 3 baseline failures were examined:

### Failure 1: `explore_test.dart`
- **Test:** `Explore Data Models Tests CreatorSummary falls back to username when fullName is null or empty`
- **File:** `Travel_Planner/frontend/mobile/test/explore_test.dart:96`
- **Failure:** `Expected: 'traveller_bob', Actual: 'Người dùng'`
- **Root Cause:** In Session 21/22, `CreatorSummary.displayName` was refactored to localize missing user names to `'Người dùng'` instead of exposing raw login usernames for privacy. The corresponding test expectation was not updated at that time.
- **Regression Analysis:** 0 connection to backend APIs or administrative area models.

### Failure 2: `rating_ui_layout_test.dart` (Dialog Test)
- **Test:** `1. Rating Dialog - Layout & RenderFlex Overflow Prevention Dialog renders cleanly without RenderFlex overflow on standard 360x640 screen`
- **File:** `Travel_Planner/frontend/mobile/test/features/social/rating_ui_layout_test.dart:88`
- **Failure:** Unhandled HTTP 400 request exception during test widget rendering.
- **Root Cause:** A remote image widget attempted network access without a mocked `HttpClient` in the widget test environment.
- **Regression Analysis:** Pre-existing test harness issue; 0 connection to Phase 3.2.

### Failure 3: `rating_ui_layout_test.dart` (Section Order Test)
- **Test:** `2. Section Order - Comments Section precedes Rating Section CommentsSection is rendered BEFORE RatingSection in the scroll tree`
- **File:** `Travel_Planner/frontend/mobile/test/features/social/rating_ui_layout_test.dart:274`
- **Failure:** `Expected: exactly one matching candidate, Actual: Found 0 widgets with text "Đánh giá (5)"`
- **Root Cause:** The rating section header text was refactored in a previous UI session, causing the text finder to fail.
- **Regression Analysis:** Purely a widget label mismatch from past frontend changes; 0 connection to Phase 3.2.

---

## 5. Conclusion

1. The test count discrepancy was an accounting double-count: the true number of unique passing tests is **787 PASS** (out of 790 total), not 815.
2. 100% of the backend tests (390/390) and 100% of the web tests (33/33) pass without error.
3. The 3 mobile failures are verified historical UI test baselines.
4. **Zero regressions** were introduced by Phase 3.2 or Phase 3.2.1.

