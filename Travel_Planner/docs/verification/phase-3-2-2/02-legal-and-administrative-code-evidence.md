# Phase 3.2.2 — Artifact 02: Legal & Administrative Code Evidence Verification

## 1. Executive Summary & Objective

In compliance with Phase 3.2.2 requirements, this document rigorously decouples **legal establishment evidence** from **administrative-code assignment evidence**. 

A recurring vulnerability in administrative data management is treating a single legislative resolution (e.g., establishing an administrative unit or changing its boundary) as automatic, self-contained proof of administrative numeric codes, database mappings, and geospatial polygons. 

This audit analyzes the primary legal instruments cited, delineates the evidence boundaries for each data attribute, and provides an authoritative evidentiary assessment for all 12 quarantined records.

---

## 2. Examination of Cited Legal Instrument: Resolution 388/NQ-UBTVQH16

### 2.1 Metadata of the Legal Instrument
- **Instrument Number:** `388/NQ-UBTVQH16`
- **Issuing Body:** Ủy ban Thường vụ Quốc hội khóa XVI (Standing Committee of the National Assembly)
- **Signing / Issuance Date:** `2026-08-04`
- **Official Effective Date:** `2026-09-20`
- **Context & Scope:** Reorganization of commune-level units and establishment of 12 wards in Bắc Ninh, coinciding with the establishment of Thành phố Bắc Ninh as a centrally governed city under Resolution 39/2026/QH16.
- **Reference URL in Gazette:** `https://congbao.chinhphu.vn/van-ban-dang-cong-bao/uy-ban-thuong-vu-quoc-hoi-c28.htm` (Government Gazette notice).

### 2.2 Evidentiary Limitations of the Resolution
1. **Preamble and Enacting Clauses:** The resolution enacts the conversion of communal units into urban wards to accommodate administrative restructuring.
2. **Missing Primary Annex in Repository:** As documented in `00-canonical-correction-reference.md` (Section 4), the official tabular annex detailing the specific boundary demarcations, acreage, population counts, and former commune mergers was **not bundled into the project source package**.
3. **No Administrative Code Assignment:** In the Vietnamese legal hierarchy, National Assembly / Standing Committee resolutions define territorial boundaries and official legal names; they **do not** assign the 5-digit GSO administrative codes (`Mã số đơn vị hành chính`). Administrative codes are assigned and promulgated separately by the General Statistics Office (Cục Thống kê / Decision 19/2025/QĐ-TTg or ministerial code circulars).

---

## 3. Disaggregation Matrix: Legal Evidence vs. Code Evidence

To avoid conflation between legislative acts and statistical catalogs, all administrative attributes are audited against their respective required evidence sources:

| Administrative Attribute | Primary Evidentiary Authority | Standard of Proof | Project Verification Status |
| :--- | :--- | :--- | :---: |
| **Legal Unit Existence** | National Assembly / UBTVQH Resolution | Published full text in Công Báo (Gazette) | **LEGALLY_VERIFIED** (General decree exists) |
| **Official Legal Name** | UBTVQH Resolution Annex | Tabular schedule in official Gazette annex | **UNVERIFIED** (Annex absent from repo) |
| **Effective Date** | Final Clause of UBTVQH Resolution | Explicit date statement (`2026-09-20`) | **LEGALLY_VERIFIED** |
| **Administrative Code (5-digit)** | GSO / Decision 19/2025/QĐ-TTg Circulars | Official statistical code catalog | **CODE_VERIFIED** (Legacy GSO code preserved) |
| **Parent Unit Assignment** | Provincial Reorganization Resolution | Resolution 202/2025/QH15 & NQ 39/2026/QH16 | **LEGALLY_VERIFIED** (Parent: Thành phố Bắc Ninh `24`) |
| **Geographic Boundary Polygons** | Ministry of Natural Resources (MONRE) | Cadastral survey maps / GIS datasets | **UNRESOLVED** (No cadastral polygons in repo) |

---

## 4. Evidentiary Audit of the 12 Quarantined Records

The table below audits the 12 Northern Bắc Ninh records across both legal and administrative-code axes:

| Code | Canonical Name | Area Type | Parent | Legal Existence Evidence | Official Name Evidence | Administrative Code Evidence | Status Classification | Runtime Quarantine |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `07294` | Phường Bố Hạ | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `07375` | Phường Lạng Giang | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `07399` | Phường Kép | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `07444` | Phường Lục Nam | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `07840` | Phường Hiệp Hoà | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `09193` | Phường Yên Phong | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `09292` | Phường Phù Lãng | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `09313` | Phường Chi Lăng | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `09319` | Phường Tiên Du | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `09454` | Phường Gia Bình | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `09475` | Phường Nhân Thắng | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |
| `09496` | Phường Lương Tài | WARD | 24 | NQ 388/NQ-UBTVQH16 | Missing Annex Gap | GSO Legacy Mirror | `VERIFIED_WITH_LIMITATIONS` (Code only) | **QUARANTINED** |

---

## 5. Architectural Rule: No Automatic Trust Upgrade

**Strict Invariant Enforced:**
Even if secondary legal summaries or press releases confirm the name of a ward (e.g., confirming "Phường Nhân Thắng"), **this confirmation must NOT automatically upgrade the record's trust classification from Tier C (`UNVERIFIED_AND_QUARANTINED`) to Tier A or Tier B**.

A record may only be upgraded if:
1. The official Gazette PDF/DOCX of the Resolution Annex is deposited into `docs/verification/`.
2. The exact administrative code is matched against an official statistical publication (Decision 19/2025/QĐ-TTg or Cục Thống kê circular).
3. Field-by-field verification is performed and recorded in an independent verification artifact.

Until these conditions are met, all 12 records **must remain strictly quarantined**.

