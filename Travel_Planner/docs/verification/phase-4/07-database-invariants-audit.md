# PHASE 4 — 07. DATABASE INVARIANTS AUDIT
## Verification of System-Wide Integrity and Baseline Preservation

**Project:** Travel Planner  
**Database:** `travel_planner` (MySQL 8.0.37)  
**Execution Timestamp:** 2026-11-12T01:02:40+07:00  

---

### 1. Invariant Summary Table

| Invariant | Requirement | Actual Value in DB | Status |
|---|---|---|---|
| **Invariant 1: Northern Bắc Ninh Quarantined** | Exactly 12 units quarantined with `UNVERIFIED_AND_QUARANTINED` | Exactly 12 units quarantined | **100% PASS** |
| **Invariant 2: Unresolved Places Null Admin Area** | Places 11, 12, 20, 22 retain `administrative_area_id = NULL` | All 4 places have `NULL` | **100% PASS** |
| **Invariant 3: Activities Baseline Preservation** | Exactly 121 rows, 20 columns, 0 direct FKs to `administrative_areas` | 121 rows, 20 cols, 0 admin FKs | **100% PASS** |
| **Invariant 4: Trust Classification Integrity** | Zero automatic promotions of trust classifications | 0 automatic promotions | **100% PASS** |

---

### 2. Evidence Logs

#### Invariant 1: 12 Quarantined Units
```sql
SELECT area_id, code, name, status, trust_classification, parent_id 
FROM administrative_areas 
WHERE trust_classification = 'UNVERIFIED_AND_QUARANTINED';
```
Output:
- `07294`: Phường Bố Hạ (area_id 797)
- `07375`: Phường Lạng Giang (area_id 803)
- `07399`: Phường Kép (area_id 805)
- `07444`: Phường Lục Nam (area_id 808)
- `07840`: Phường Hiệp Hoà (area_id 846)
- `09193`: Phường Yên Phong (area_id 958)
- `09292`: Phường Phù Lãng (area_id 967)
- `09313`: Phường Chi Lăng (area_id 970)
- `09319`: Phường Tiên Du (area_id 971)
- `09454`: Phường Gia Bình (area_id 987)
- `09475`: Phường Nhân Thắng (area_id 990)
- `09496`: Phường Lương Tài (area_id 992)
Total: **12 records**.

#### Invariant 2: Places 11, 12, 20, 22
```sql
SELECT place_id, name, administrative_area_id FROM places WHERE place_id IN (11, 12, 20, 22);
```
Output:
- 11: Bà Nà Hills & Cầu Vàng -> NULL
- 12: Bán Đảo Sơn Trà & Chùa Linh Ứng -> NULL
- 20: Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) -> NULL
- 22: Chợ Đêm Sơn Trà -> NULL
Total: **4 records with NULL**.

#### Invariant 3: Activities Table
- Total Rows: `121`
- Total Columns: `20`
- Foreign Keys:
  - `day_id` -> `itinerary_days(day_id)`
  - `canonical_place_id` -> `places(place_id)`
- Direct FKs to `administrative_areas`: `0`
- Direct FKs to `itinerary_places`: `0`

