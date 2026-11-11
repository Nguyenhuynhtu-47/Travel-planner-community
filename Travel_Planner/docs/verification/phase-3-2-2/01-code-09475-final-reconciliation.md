# Phase 3.2.2 — Artifact 01: Code 09475 Final Reconciliation & Multi-Layer Audit

## 1. Executive Summary & Objective

During the post-acceptance review of Phase 3.2 and Phase 3.2.1, a specific question was raised concerning the documentation of administrative code `09475`:
- In the **Phase 3.1.2.4.1 verification report** and canonical datasets, code `09475` is identified as **Phường Nhân Thắng** (Thành phố Bắc Ninh).
- In the **Phase 3.2.1 discrepancy audit table**, it was noted that the original Phase 3.2 report text in `03-trust-classification-report.md` listed code `09475` as **Xã Hòa Tiến**.

This artifact provides an exhaustive, forensic investigation to determine:
1. The exact historical text in the Phase 3.2 report prior to remediation.
2. The exact data across all four project layers (Seed JSON, Correction CSV, Verification CSV, MySQL Production DB).
3. The origin of the name "Hòa Tiến" and how it entered the report.
4. The definitive classification of this issue under Phase 3.2.2 standards.

---

## 2. Multi-Layer Cross-Verification of Code 09475

| Data Layer | Source File / Resource | Code | Entity Name | Entity Type | Parent Code / Name | Trust Classification |
| :--- | :--- | :---: | :--- | :---: | :---: | :---: |
| **Layer 1: Canonical Seed** | `communes.json` (Line 6688) | `09475` | `Phường Nhân Thắng` | `WARD` | `24` (Bắc Ninh) | — |
| **Layer 2: Correction CSV** | `03-commune-level-correction.csv` (Line 957) | `09475` | `Phường Nhân Thắng` | `WARD` | `24` (Bắc Ninh) | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| **Layer 3: Verification CSV** | `07-independent-record-verification.csv` (Line 957) | `09475` | `Phường Nhân Thắng` | `WARD` | `24` (Bắc Ninh) | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| **Layer 4: MySQL Database** | `travel_planner.administrative_areas` (`area_id = 990`) | `09475` | `Phường Nhân Thắng` | `WARD` | `11` (Bắc Ninh) | `UNVERIFIED_AND_QUARANTINED` |
| **Layer 5: Java Resolver Code** | `AdministrativeAreaResolverImpl.java` (Line 38) | `09475` | *(Quarantined Set)* | — | — | Excluded from resolution |
| **Phase 3.2 Original Report** | `03-trust-classification-report.md` (Line 92 prior to edit) | `09475` | `Xã Hòa Tiến` | — | — | *(Prose transcription error)* |
| **Phase 3.2.1 Audit Table** | `01-bac-ninh-code-name-discrepancy-audit.md` (Line 31) | `09475` | `Phường Nhân Thắng` | `WARD` | `24` (Bắc Ninh) | `UNVERIFIED_AND_QUARANTINED` |

---

## 3. Forensic Trace: Where Did "Hòa Tiến" Originate?

A deep genealogical trace of the names listed in Section 3 of the original Phase 3.2 report reveals the following sequence:

1. **The 12 Rural Communes of Yên Phong District:**
   In historical General Statistics Office (GSO) catalogs, the rural commune-level units of Yên Phong district, Bắc Ninh province consisted of:
   - 1. Tam Giang (GSO code `09202`)
   - 2. Yên Phụ (GSO code `09241`)
   - 3. Đông Thọ (GSO code `09229`)
   - 4. Văn Môn (GSO code `09238`)
   - 5. Dũng Liệt (GSO code `09211`)
   - 6. Trung Nghĩa (GSO code `09226`)
   - 7. Đông Phong (GSO code `09220`)
   - 8. Long Châu (GSO code `09223`)
   - 9. Thụy Hòa (GSO code `09214`)
   - 10. Tam Đa (GSO code `09208`)
   - **11. Hòa Tiến** (GSO code `09217`)
   - 12. Yên Trung (GSO code `09205`)

2. **The Transcription Slip:**
   When drafting Section 3 ("Tier C: Unverified and Quarantined (12 Records)") in `03-trust-classification-report.md`, the author intended to enumerate the 12 quarantined codes (`07294`, `07375`, `07399`, `07444`, `07840`, `09193`, `09292`, `09313`, `09319`, `09454`, `09475`, `09496`).
   However, instead of retrieving the ward names from the database or seed JSON, the author inadvertently pasted the 12 rural commune names of Yên Phong district into the 12 numbered bullet points.
   Because "Hòa Tiến" was the 11th commune in the Yên Phong list, it was erroneously paired with code `09475` (the 11th code in the numeric sequence).

3. **Status of "Hòa Tiến" in the System:**
   - In the active MySQL database `travel_planner`, `Xã Hoà Tiến` exists as code **`20332`** (`area_id = 1900`) under Thành phố Đà Nẵng (`parent_id = 21`, `VERIFIED_WITH_LIMITATIONS`).
   - In the canonical seed and database, code **`09475`** has **never** been named "Hòa Tiến". It has always been `Phường Nhân Thắng`.

---

## 4. Definitive Classification & Conclusion

Under Phase 3.2.2 audit criteria, this finding is officially classified as:

### **`DOCUMENTATION_TRANSCRIPTION_ERROR`**

### Summary of Facts:
1. **No Data Corruption:** The canonical JSON seed, the reconciliation CSVs, and the MySQL production database were 100% consistent and intact. At no point was code `09475` named "Hòa Tiến" in any data table or software component.
2. **Phase 3.2.1 Audit Accuracy:** The discrepancy table in `01-bac-ninh-code-name-discrepancy-audit.md` was 100% accurate in recording that the original Phase 3.2 Markdown report contained `Xã Hòa Tiến` as a transcription artifact.
3. **Remediation Integrity:** Section 3 of `03-trust-classification-report.md` has been corrected to restore the canonical name `Phường Nhân Thắng`. Historical documentation and audit records preserve the forensic trail without silent alteration.
4. **Quarantine Unchanged:** Code `09475` remains strictly classified as `UNVERIFIED_AND_QUARANTINED` in Tier C, barred from runtime resolution and linking.

