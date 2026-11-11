# Phase 3.2.2 — Artifact 06: Remediation & Clarification Record

## 1. Executive Summary

This record documents all clarifications, forensic verifications, and documentation alignments executed during Phase 3.2.2 (Final Consistency Verification & Closure).

In accordance with Phase 3.2.2 safety guidelines, this phase operated in **audit and documentation-alignment mode**:
- Zero business data modifications.
- Zero schema migrations.
- Zero destructive database operations.
- Zero Git commits or pushes.

---

## 2. Itemized Verification & Remediation Log

### Item 1: Conclusive Reconciliation of Code 09475
- **Subject:** Code `09475` documented as `Phường Nhân Thắng` vs `Xã Hòa Tiến`.
- **Finding:** Canonical seed (`communes.json`), correction CSV (`03-commune-level-correction.csv`), independent verification CSV (`07-independent-record-verification.csv`), and MySQL database (`administrative_areas`) have **always** held code `09475` as `Phường Nhân Thắng`. The presence of `Xã Hòa Tiến` was strictly a prose transcription error in the original Phase 3.2 report, caused by inadvertently pasting the 12 rural communes of Yên Phong district into the report.
- **Action Taken:** Validated that Section 3 of `03-trust-classification-report.md` correctly reflects `Phường Nhân Thắng`. Created comprehensive forensic proof in `01-code-09475-final-reconciliation.md`.
- **Classification:** `DOCUMENTATION_TRANSCRIPTION_ERROR`.

---

### Item 2: Disaggregation of Legal Source and Statistical Code Evidence
- **Subject:** Evidentiary authority of Resolution 388/NQ-UBTVQH16.
- **Finding:** A legislative resolution establishes the territorial creation and legal naming of units, but does not assign statistical administrative codes (which are assigned by the General Statistics Office / Decision 19/2025/QĐ-TTg). Because the official gazette annex of Resolution 388 is not bundled into the repository, the 12 records cannot be verified against primary cadastral documentation.
- **Action Taken:** Enforced the invariant that confirming a unit's legal existence or name cannot automatically promote a record's code-trust classification. All 12 records remain strictly quarantined under `UNVERIFIED_AND_QUARANTINED`. Documented in `02-legal-and-administrative-code-evidence.md`.

---

### Item 3: API Contract Clarification (`PUT` vs `POST .../link`)
- **Subject:** Route discrepancy between `PUT /api/admin/places/{id}/administrative-area` and `POST /api/admin/places/{id}/administrative-area/link`.
- **Finding:** The `PUT` path was an early conceptual notation from initial phase specifications. The actual production Spring Boot controller (`AdminPlaceAdministrativeAreaController.java`) implements command-oriented RPC endpoints: `POST /{id}/administrative-area/link`, `DELETE /{id}/administrative-area`, `POST /{id}/administrative-area/resolve`, `POST /{id}/administrative-area/preview`, and `POST /administrative-area/batch-resolve`.
- **Action Taken:** Documented the exact production API contract, request/response DTOs, and validation annotations in `03-admin-manual-linking-contract-audit.md`. No new code was introduced, preserving 100% binary compatibility.

---

### Item 4: End-to-End Quarantine Defense-in-Depth Verification
- **Subject:** Verification of quarantine enforcement at every entry point.
- **Finding:** Quarantine enforcement is implemented at multiple layers:
  1. Spring Security (`ROLE_ADMIN` check).
  2. Controller request validation (`@Valid`).
  3. Resolver static quarantine set (`QUARANTINED_BAC_NINH_CODES`).
  4. Service-level trust classification entity check (`UNVERIFIED_AND_QUARANTINED`).
  5. Database state (0 quarantined place links).
- **Action Taken:** Documented 11 operational scenarios in `04-quarantine-enforcement-verification.md`. Verified that direct Java service invocations and batch operations cannot bypass quarantine. Documented the lack of a dedicated database audit table as an explicit limitation.

---

### Item 5: Stack-Wide Test Count Confirmation
- **Subject:** De-duplication of test counts (reconciliation of 815 vs 790).
- **Finding:** The 28 dedicated Phase 3.2 tests are an integral subset of the 390 backend tests executed by `mvnw test`. Summing `390 + 28` produced an accidental double-count.
- **Action Taken:** Confirmed the true unique count of 790 tests across the stack (787 PASS / 3 pre-existing baseline FAIL). Documented in `05-test-and-database-baseline-confirmation.md`.

---

## 3. Status of Resolved Items

All five consistency items investigated in Phase 3.2.2 have been conclusively verified, reconciled, and documented.

