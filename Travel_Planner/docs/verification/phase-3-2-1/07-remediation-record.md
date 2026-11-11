# Phase 3.2.1 — Artifact 07: Remediation Record

## 1. Executive Summary

This remediation record catalogs all corrections, documentation updates, and data reconciliations executed during Phase 3.2.1 following the post-acceptance review of Phase 3.2.

---

## 2. Itemized Remediation Log

### Remediation Item 1: Correction of Bắc Ninh Quarantined Records in Phase 3.2 Documentation
- **File Impacted:** `Travel_Planner/docs/verification/phase-3-2/03-trust-classification-report.md` (Section 3).
- **Issue:** Section 3 inadvertently listed 12 commune names from Yên Phong district (`Xã Tam Giang`, `Xã Yên Phụ`, etc.) alongside the 12 quarantined codes (`07294..09496`).
- **Investigation:** Audit of `communes.json`, `03-commune-level-correction.csv`, `07-independent-record-verification.csv`, and MySQL `travel_planner.administrative_areas` proved that the database and seed files always contained the canonical names (`Phường Bố Hạ`, `Phường Lạng Giang`, `Phường Kép`, `Phường Lục Nam`, `Phường Hiệp Hoà`, `Phường Yên Phong`, `Phường Phù Lãng`, `Phường Chi Lăng`, `Phường Tiên Du`, `Phường Gia Bình`, `Phường Nhân Thắng`, `Phường Lương Tài`).
- **Action Taken:** Updated Section 3 of `03-trust-classification-report.md` to reflect the canonical names in full alignment with the database, seed files, and legal documents.
- **Verification:** Verified via `git diff` that the text now accurately displays the canonical ward names.

---

### Remediation Item 2: Test Count Aggregation Formula Reconciliation
- **Documentation Impacted:** `Travel_Planner/docs/verification/phase-3-2/07-test-execution-report.md`, `08-final-acceptance-report.md`.
- **Issue:** The reported total of 815 passing tests double-counted the 28 dedicated Phase 3.2 tests because they were already included within the 390 backend regression tests (`mvnw test`).
- **Action Taken:** Reconciled test counting logic in Phase 3.2.1 artifacts (`03-test-count-and-regression-audit.md` and dev logs):
  - Dedicated Phase 3.2 Tests: 28 (all pass).
  - Backend Full Regression: 390 (all pass; includes the 28 tests).
  - Frontend Web: 33 (all pass).
  - Frontend Mobile: 367 (364 pass, 3 pre-existing baseline fails).
  - Total Unique Tests Executed: **790** (787 PASS / 3 FAIL).
- **Verification:** Both Maven Surefire execution logs and Flutter test execution logs confirm the exact test counts.

---

### Remediation Item 3: Deep Audit & Preservation of 4 Ambiguous Places
- **Target Entities:** Places 11 (Bà Nà Hills), 12 (Bán Đảo Sơn Trà), 20 (Phong Nha Reserve), 22 (Chợ Đêm Sơn Trà).
- **Audit Findings:** Confirmed that all 4 places correctly have competing candidates or multi-ward boundaries:
  - Place 11 ties between landmark `Xã Bà Nà` and address `Xã Hoà Vang`.
  - Place 12 ties between coastal road `"Hoàng Sa"` and district `"Sơn Trà"`; ambiguity prevented an erroneous false-positive link to offshore `Đặc khu Hoàng Sa`.
  - Place 20 spans multiple communes in Bố Trạch.
  - Place 22 intersects restructured wards in Sơn Trà.
- **Action Taken:** Verified that all 4 places properly remain `NULL` in `places.administrative_area_id`. Documented operational guidelines for manual administrative linking via `POST /api/admin/places/{id}/administrative-area/link`.
- **Verification:** Database confirmed `administrative_area_id IS NULL` for all 4 places.

---

### Remediation Item 4: End-to-End Quarantine Barrier Verification
- **Code Inspected:**
  - `AdministrativeAreaResolverImpl.java`: hardcoded quarantine set and early abort.
  - `PlaceAdministrativeAreaServiceImpl.java`: double-check in auto-link and explicit 400 Bad Request rejection in manual link.
  - `AdminPlaceAdministrativeAreaControllerTest.java`: integration test `testLinkManually_QuarantinedBacNinh_Rejected` passes.
- **Action Taken:** Audited database and confirmed 0 places are linked to any quarantined area.
- **Verification:** SQL query returned 0 rows.

---

## 3. Current Remediation Status

All identified issues from the post-acceptance review have been comprehensively resolved, verified, and documented.

