# 08 — UNVERIFIED RECORDS & RUNTIME EXCLUSION ARCHITECTURE
## Phase 3.1.2.4.1 Independent Catalog Audit & Database Trust Boundary

**Project:** Travel Planner  
**Scope:** Administrative Areas Catalog — North Bắc Ninh Records & Trust Boundary  
**Target Snapshot:** 2026-09-20  
**Audit Date:** 2026-11-11  
**Auditor:** Independent Backend Quality Assurance  

---

## 1. Executive Summary & Problem Statement

During the Phase 3.1.2.4.1 independent verification, the official annex of **Resolution 388/NQ-UBTVQH16** (adjusting commune-level administrative units in Bắc Ninh Province) was determined to be **unavailable** in the project's official source package and inaccessible across public legislative repositories (National Assembly Portal, Government Portal, National Gazette).

As mandated by strict data integrity rules:
1. Uncertified names and conjectured 5-digit codes must **not** be treated as authoritative data.
2. These records must **never** be imported into or queried by the trusted runtime administrative catalog.
3. Their audit status is formally classified as `UNVERIFIED_SOURCE_DOCUMENT_MISSING`.
4. They are strictly quarantined from participating in Place-to-Area resolution (Phase 3.2) or Location Search indexing (Phase 3.3).

---

## 2. Dossier of the 12 Unverified Records

The following 12 commune/ward records are associated with the unverified Bắc Ninh changes:

| Code | Candidate Name | Declared Area Type | Parent Code | Parent Name | Legal Instrument | Verification Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `07294` | Phường Bố Hạ | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `07375` | Phường Lạng Giang | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `07399` | Phường Kép | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `07444` | Phường Lục Nam | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `07840` | Phường Hiệp Hoà | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `09193` | Phường Yên Phong | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `09292` | Phường Phù Lãng | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `09313` | Phường Chi Lăng | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `09319` | Phường Tiên Du | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `09454` | Phường Gia Bình | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `09475` | Phường Nhân Thắng | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |
| `09496` | Phường Lương Tài | `WARD` | `24` | Tỉnh Bắc Ninh | NQ 388/NQ-UBTVQH16 | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` |

> [!WARNING]
> None of the codes or names above are certified by primary official gazette annexes. They must not be treated as authoritative data or exposed via public APIs without explicit warning banners.

---

## 3. Forensic Traceability: How the Records Entered the System

1. **Seed Ingestion in Phase 3.1.2:** During early administrative catalog drafting in Phase 3.1.2, provisional restructuring drafts for Bắc Ninh were merged into the canonical JSON baseline.
2. **Migration Runner Ingestion:** When `AdministrativeAreaMigrationRunner` executed against `travel_planner_test`, all 3,321 communes in `communes.json` were upserted into MySQL table `administrative_areas`.
3. **Production Isolation:** In the production environment (`travel_planner`), table `administrative_areas` has **not** been instantiated. The production database contains **zero** administrative records.

---

## 4. Empirical Impact & Dependency Audit

To satisfy Critical Task A.7 ("Do not delete records or alter parent relationships until their dependencies and impact have been inspected"):

### 4.1 Schema Dependency Audit
```sql
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'travel_planner' AND TABLE_NAME = 'places';
```
*Results:* Exactly 12 columns exist in `places`. The column `administrative_area_id` **does not exist** (deferred to Phase 3.2).

### 4.2 Row-level Association Audit
```sql
SELECT place_id, name, address 
FROM travel_planner.places 
WHERE address LIKE '%Bắc Ninh%' OR address LIKE '%Bac Ninh%';
```
*Results:* **0 places** in Bắc Ninh. All 24 places in `travel_planner` are located in Hanoi, Quang Ninh, Ninh Binh, Da Nang, Thua Thien Hue, Quang Nam, Khanh Hoa, Lam Dong, HCMC, Kien Giang, Lao Cai, and Can Tho.

### 4.3 Activity Audit
```sql
SELECT activity_id, location_name, location_address 
FROM travel_planner.activities 
WHERE location_address LIKE '%Bắc Ninh%' OR location_address LIKE '%Bac Ninh%';
```
*Results:* **0 activities** in Bắc Ninh.

**Conclusion:** The 12 unverified Bắc Ninh records have **zero references, zero foreign keys, and zero runtime dependencies** across the entire application ecosystem.

---

## 5. Trust Boundary & Runtime Exclusion Architecture

To establish a bulletproof trust boundary without performing destructive database mutations:

```
+-----------------------------------------------------------------------------------+
|                        ADMINISTRATIVE DATA ARCHITECTURE                           |
|                                                                                   |
|  +----------------------------------+     +-----------------------------------+   |
|  |       TRUSTED RUNTIME TIER       |     |        AUDIT EVIDENCE TIER        |   |
|  |                                  |     |                                   |   |
|  | - 34 Provinces / Central Cities  |     | - 12 Unverified Bắc Ninh Records  |   |
|  | - 33 Primary Verified Communes   |     |   (Status:                        |   |
|  | - 3,276 Secondary GSO Communes   |     |    UNVERIFIED_SOURCE_             |   |
|  |                                  |     |    DOCUMENT_MISSING)              |   |
|  | Total: 3,343 Records             |     | Total: 12 Records                 |   |
|  +-----------------+----------------+     +-----------------+-----------------+   |
|                    |                                        |                     |
|                    v                                        v                     |
|  +----------------------------------+     +-----------------------------------+   |
|  |   Phase 3.2 Place Backfill &     |     |       BLOCKED & QUARANTINED       |   |
|  |   Runtime Resolution Engine      |     |  - Resolvers return NULL / Skip   |   |
|  |   (ELIGIBLE)                     |     |  - Excluded from Search Index     |   |
|  +----------------------------------+     +-----------------------------------+   |
+-----------------------------------------------------------------------------------+
```

### 5.1 Resolver Exclusion Rule (Phase 3.2 Integration Contract)
When resolving administrative areas for places in Phase 3.2, the resolver algorithm must enforce:
```java
if (candidateArea.getVerificationStatus() == VerificationStatus.UNVERIFIED_SOURCE_DOCUMENT_MISSING) {
    logger.warn("Excluding unverified administrative area {} from Place linking", candidateArea.getCode());
    return null; // Leave places.administrative_area_id as NULL
}
```

### 5.2 Search Engine Exclusion Rule (Phase 3.3 Integration Contract)
Location search and autocomplete queries must explicitly filter:
```sql
WHERE status = 'ACTIVE' 
  AND verification_status != 'UNVERIFIED_SOURCE_DOCUMENT_MISSING'
```

---

## 6. Safe & Reversible Remediation Strategy

Tested on disposable test database `travel_planner_test`:

### Step 1: Add Non-Destructive Verification Metadata Column
```sql
ALTER TABLE administrative_areas 
ADD COLUMN verification_status VARCHAR(50) NOT NULL DEFAULT 'VERIFIED_SECONDARY';
```

### Step 2: Mark Unverified Bắc Ninh Records
```sql
UPDATE administrative_areas 
SET verification_status = 'UNVERIFIED_SOURCE_DOCUMENT_MISSING' 
WHERE code IN ('07294','07375','07399','07444','07840','09193','09292','09313','09319','09454','09475','09496');
```

### Step 3: Reversible Canonical Patch Mechanism
When the official gazette annex of Resolution 388/NQ-UBTVQH16 is published:
1. Verify the official name and 5-digit code assigned by the GSO.
2. Update `communes.json` with primary citations.
3. Update `metadata.json` checksums.
4. Run standard idempotent migration runner, which flips `verification_status` to `VERIFIED_PRIMARY`.

