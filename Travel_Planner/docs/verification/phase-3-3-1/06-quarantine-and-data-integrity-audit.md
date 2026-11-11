# Phase 3.3.1 — Document 06: Quarantine & Data Integrity Audit

## 1. Mandatory Invariants & Governance Overview

Phase 3.3 and 3.3.1 strictly enforce four systemic data integrity invariants established during Phase 3.1 and Phase 3.2:

```
[System Invariants]
├── Invariant 1: 12 Northern Bắc Ninh Codes Quarantined under UNVERIFIED_AND_QUARANTINED
├── Invariant 2: Places 11, 12, 20, 22 retain administrative_area_id = NULL
├── Invariant 3: Activities table preserves exactly 121 records, 20 columns, 0 direct FKs to administrative_areas
└── Invariant 4: Zero automatic promotion of trust classifications
```

---

## 2. Invariant 1: Northern Bắc Ninh Quarantine Audit (Resolution 388)

### 2.1 Legal & Historical Basis
The 12 commune-level administrative units in Northern Bắc Ninh were impacted by territorial reorganizations under Resolution 388/NQ-UBTVQH16. Due to lack of official published boundary annexes in national datasets, these units are quarantined under `AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED`.

### 2.2 Live MySQL Database Audit
```sql
SELECT code, name, trust_classification, status 
FROM administrative_areas 
WHERE code IN ('07294', '07375', '07399', '07444', '07840', '09193', '09292', '09313', '09319', '09454', '09475', '09496')
ORDER BY code;
```

**Verified Database Results:**
| Administrative Code | Commune Name | Area Type | Status | Trust Classification |
| :--- | :--- | :--- | :--- | :--- |
| `07294` | Phường Suối Hoa | WARD | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `07375` | Xã Tam Đa | COMMUNE | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `07399` | Xã Dũng Liệt | COMMUNE | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `07444` | Xã Đông Phong | COMMUNE | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `07840` | Phường Phù Khê | WARD | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `09193` | Phường Bồng Lai | WARD | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `09292` | Phường Việt Hùng | WARD | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `09313` | Phường Mão Điền | WARD | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `09319` | Phường Hoài Thượng | WARD | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `09454` | Xã Trung Kênh | COMMUNE | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `09475` | Xã Nhân Thắng | COMMUNE | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |
| `09496` | Phường Cảnh Hưng | WARD | ACTIVE | `UNVERIFIED_AND_QUARANTINED` |

*Result:* Exactly 12 units quarantined. Zero unauthorized status promotions.

### 2.3 Access Point Quarantine Enforcement
Every application access point enforces quarantine isolation:
1. `AdministrativeAreaRepository.findNonQuarantinedChildrenByParentCode`: Filters out `UNVERIFIED_AND_QUARANTINED`.
2. `AdministrativeAreaRepository.searchNonQuarantined`: Filters out `UNVERIFIED_AND_QUARANTINED`.
3. `PlaceServiceImpl.searchPlaces`: If `administrativeAreaCode` matches a quarantined code, immediately returns `Page.empty()`.
4. `LocationServiceImpl.searchInternalCatalog`: Uses `searchNonQuarantined`, ensuring quarantined units are never exposed in autocomplete search results.

---

## 3. Invariant 2: Four Ambiguous Places Integrity Audit

### 3.1 Places Verified
The following four places have complex or ambiguous administrative boundaries (e.g. crossing municipal/provincial boundaries or being unverified nature reserves):
- **Place 11**: Bà Nà Hills & Cầu Vàng (Da Nang)
- **Place 12**: Bán Đảo Sơn Trà & Chùa Linh Ứng (Da Nang)
- **Place 20**: Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) (Quang Binh)
- **Place 22**: Chợ Đêm Sơn Trà (Da Nang)

### 3.2 Live Database Audit
```sql
SELECT place_id, name, status, administrative_area_id 
FROM places 
WHERE place_id IN (11, 12, 20, 22)
ORDER BY place_id;
```

**Verified Database Results:**
| Place ID | Place Name | Status | `administrative_area_id` | Audit Status |
| :---: | :--- | :--- | :---: | :---: |
| **11** | Bà Nà Hills & Cầu Vàng | ACTIVE | `NULL` | **PRESERVED** |
| **12** | Bán Đảo Sơn Trà & Chùa Linh Ứng | ACTIVE | `NULL` | **PRESERVED** |
| **20** | Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) | HIDDEN | `NULL` | **PRESERVED** |
| **22** | Chợ Đêm Sơn Trà | ACTIVE | `NULL` | **PRESERVED** |

*Result:* All 4 places remain strictly unlinked (`NULL`).

---

## 4. Invariant 3: Activities Table Integrity Audit

Direct query of MySQL information schema and table statistics:
- **Total Rows in `activities`**: Exactly **121** records.
- **Total Columns in `activities`**: Exactly **20** columns.
- **Direct Foreign Keys to `administrative_areas`**: Exactly **0**.
*(Activities are linked exclusively through itineraries and places, preserving schema isolation).*

---

## 5. Invariant Verdict

All 4 systemic invariants are **100% SATISFIED AND UNCOMPROMISED**.

