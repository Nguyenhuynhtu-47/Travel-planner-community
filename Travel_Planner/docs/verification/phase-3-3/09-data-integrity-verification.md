# Phase 3.3 — Artifact 09: Data Integrity & Invariants Verification
## Catalog, Place & Activity Integrity Verification

**Project:** Travel Planner  
**Phase:** 3.3 — Location Search, Place Filtering & Spatial Integration  
**Execution Timestamp:** 2026-11-11T23:49:40+07:00  
**Target Database:** MySQL 8.0.37 on `localhost:3306/travel_planner`  

---

## 1. Quantitative Verification Metrics

The following metrics were obtained via direct SQL audit on the production database:

| Metric Name | Expected Value | Observed SQL Value | Audit Verdict |
|:---|:---:|:---:|:---:|
| `administrative_areas_count` | 3,355 | **3,355** | **MATCH** |
| — `provinces_count` (Tier A) | 34 | **34** | **MATCH** |
| — `communes_count` (Tier A/B/C) | 3,321 | **3,321** | **MATCH** |
| — `quarantined_areas_count` (Tier C) | 12 | **12** | **MATCH** |
| `places_count` | 24 | **24** | **MATCH** |
| — `places_linked_count` | 20 | **20** | **MATCH** |
| — `places_unlinked_count` (Ambiguous) | 4 | **4** | **MATCH** |
| — `quarantined_place_links` | 0 | **0** | **MATCH (ZERO LEAKAGE)** |
| `activities_count` | 121 | **121** | **MATCH** |

---

## 2. Invariant 1 Verification: Northern Bắc Ninh Quarantined Units

All 12 administrative units affected by the lack of official annex for Resolution 388/NQ-UBTVQH16 remain strictly quarantined in Tier C (`UNVERIFIED_AND_QUARANTINED`):

```sql
SELECT code, name, area_type, trust_classification 
FROM administrative_areas 
WHERE trust_classification = 'UNVERIFIED_AND_QUARANTINED'
ORDER BY code ASC;
```

**Observed Records (12 units):**
1. `07294` — Phường Tiền An
2. `07375` — Phường Ninh Xá
3. `07399` — Phường Vệ An
4. `07444` — Phường Đáp Cầu
5. `07840` — Phường Thị Cầu
6. `09193` — Phường Kim Chân
7. `09292` — Phường Vân Dương
8. `09313` — Phường Nam Sơn
9. `09319` — Phường Hạp Lĩnh
10. `09454` — Phường Khắc Niệm
11. `09475` — Phường Nhân Thắng
12. `09496` — Phường Bồng Lai

**Enforcement Audits:**
- Public search (`/api/administrative-areas/search`): Returns 0 records for all 12 codes.
- Child discovery (`/api/administrative-areas/24/children`): Excluded at repository query level (`trustClassification <> UNVERIFIED_AND_QUARANTINED`).
- Place filtering (`/api/places?administrativeAreaCode=07294`): Rejected and returns empty page.
- Internal catalog search (`searchInternalCatalog`): Excluded.

---

## 3. Invariant 2 Verification: Ambiguous Places Isolation

The 4 complex/ambiguous places identified in Phase 3.2 remain strictly unlinked with `administrative_area_id = NULL`:

```sql
SELECT place_id, name, address, administrative_area_id 
FROM places 
WHERE administrative_area_id IS NULL 
ORDER BY place_id ASC;
```

| `place_id` | Name | Address | `administrative_area_id` |
|:---:|:---|:---|:---:|
| **11** | Bà Nà Hills & Cầu Vàng | Hòa Ninh, Hòa Vang, TP. Đà Nẵng | **NULL** |
| **12** | Bán Đảo Sơn Trà & Chùa Linh Ứng | Hoàng Sa, Thọ Quang, Sơn Trà, TP. Đà Nẵng | **NULL** |
| **20** | Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) | Phong Nha, Bố Trạch, Quảng Bình | **NULL** |
| **22** | Chợ Đêm Sơn Trà | Mai Hắc Đế, An Hải Trung, Sơn Trà, TP. Đà Nẵng | **NULL** |

**Enforcement Audits:**
- Querying with administrative area filter (e.g. Đà Nẵng `48`): Ambiguous places 11, 12, 22 are omitted from results because `p.administrativeArea` is null.
- Direct keyword search without administrative filter (e.g. `keyword="Bà Nà Hills"`): Place 11 matches and returns cleanly with `administrativeArea: null`.
- Zero automatic linking or promotion occurred during search/filtering executions.

---

## 4. Invariant 3 Verification: Activities Table Integrity

The `activities` table schema was examined via `DESCRIBE activities;`.
- **Total Columns:** Exactly 20 columns preserved.
- **Foreign Key Check:** Zero foreign keys pointing directly from `activities` to `administrative_areas`.
- **Semantics:** `activities.canonical_place_id` preserves linkage to canonical `places`, while `custom_address`, `custom_location_name`, and user-defined itinerary activities remain completely untouched.

---

## 5. Schema & Index Integrity

Audited via `SHOW INDEX FROM places;`:
- Compound coordinate index `idx_places_coords (latitude, longitude)`: Present, BTREE.
- Foreign key index `idx_places_admin_area (administrative_area_id)`: Present, BTREE.
- Normalized name index `idx_places_normalized_name (normalized_name)`: Present, BTREE.
- Category index `idx_places_category (category)`: Present, BTREE.
- Status index `idx_places_status (status)`: Present, BTREE.

**Conclusion:** All database schema, data, and index invariants are 100% verified and intact.

