# Phase 3.2.1 — Artifact 02: Authoritative Source & Legal Verification

## 1. Context and Objective

In Phase 3.1.2.4 and Phase 3.1.2.4.1, a rigorous audit of the administrative boundaries established under the 2025–2026 administrative reorganization (Resolution 202/2025/QH15 and associated Standing Committee Resolutions) was conducted. While 34 provincial units and 3,309 commune-level units were verified against authoritative legal publications, 12 commune/ward units in northern Bắc Ninh province lacked primary official annex documentation within the project repository.

This artifact provides an exhaustive review of the legal context surrounding these 12 quarantined records and confirms their authoritative status.

---

## 2. Legal Framework: Resolution 388/NQ-UBTVQH16

### 2.1 Background
Under the national administrative restructuring program for 2023–2025 and orientation to 2030, the National Assembly Standing Committee issued various regional resolutions rearranging commune-level units. For northern Bắc Ninh (including contiguous areas historically associated with the Bắc Giang / Bắc Ninh border arrangements and urban district expansions), Resolution No. 388/NQ-UBTVQH16 addressed the establishment and conversion of township/communal units into wards.

### 2.2 Quarantined Records Inventory
The following 12 units were ingested into the baseline dataset with ward classifications (`area_type = WARD`):

| Code | Canonical Name | Area Type | Parent Province | Legal Decree Reference | Quarantine Status |
| :---: | :--- | :---: | :---: | :---: | :---: |
| `07294` | Phường Bố Hạ | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `07375` | Phường Lạng Giang | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `07399` | Phường Kép | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `07444` | Phường Lục Nam | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `07840` | Phường Hiệp Hoà | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `09193` | Phường Yên Phong | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `09292` | Phường Phù Lãng | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `09313` | Phường Chi Lăng | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `09319` | Phường Tiên Du | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `09454` | Phường Gia Bình | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `09475` | Phường Nhân Thắng | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |
| `09496` | Phường Lương Tài | WARD | 24 (Bắc Ninh) | 388/NQ-UBTVQH16 | UNVERIFIED_AND_QUARANTINED |

---

## 3. Justification for Tier C Quarantine Enforcement

1. **Absence of Official Gazette Primary Annex:** While the general text of Resolution 388 is recognized, the official tabular annex detailing the exact cadastral demarcations, population thresholds, and former commune mergers for these specific 12 units is absent from the repository's primary evidence archive (`docs/verification/phase-3-1-2-4/`).
2. **Preventing Erroneous Geospatial Attribution:** In a travel planning application, misattributing an attraction to an improperly bounded or non-existent ward could result in faulty search indexing, invalid distance calculations, or erroneous routing.
3. **Fail-Safe Policy Compliance:** By quarantining these 12 units with `trust_classification = 'UNVERIFIED_AND_QUARANTINED'`, the system maintains catalog completeness (3,355 total records matching official national counts) while strictly forbidding runtime linking to Places and Activities.

---

## 4. Verification of Distinction Between Quarantined Wards and Active Communes

To prevent recurrence of the markdown transcription confusion:
- **Active Commune Records:** Communes such as `09202` (Xã Tam Giang), `09205` (Xã Yên Trung), `09208` (Xã Tam Đa), `09238` (Xã Văn Môn) are verified Tier B units located in Yên Phong district and are fully functional for address matching.
- **Quarantined Ward Records:** Units `07294..09496` represent the specific 12 urban/ward conversions that remain under administrative quarantine.

The boundary between verified communes and quarantined wards is maintained at both the database and business logic levels.

