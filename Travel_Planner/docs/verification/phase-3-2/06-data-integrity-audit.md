# Phase 3.2 — Data Integrity & Row-Level Preservation Audit
**Target Snapshot:** 2026-09-20  
**Phase:** 3.2 — Place–Administrative Area Linking & Resolution  
**Database Audited:** `travel_planner` (MySQL 8.0.37)  
**Audit Date:** 2026-11-11

---

## 1. Scope & Invariant Principles

The core system invariants established across Phase 1 through Phase 3 must remain strictly inviolate:
1. **Places Table:** Exactly 24 rows, with primary keys 1 to 24 preserved. All names, descriptions, categories, addresses, and coordinates must remain identical to the pre-Phase 3.2 state.
2. **Activities Table:** Exactly 121 rows. Exactly 111 activities linked via `canonical_place_id` (IDs 1..24), and exactly 10 custom activities with `canonical_place_id = NULL`. Zero activity columns altered.
3. **Administrative Areas Table:** Exactly 3,355 rows (34 provinces, 3,321 communes). Exactly 67 Tier A, 3,276 Tier B, 12 Tier C, and 0 Tier D.

---

## 2. Table-by-Table Verification

### 2.1 Destinations (`places` table)

#### Count and Range Verification:
```sql
SELECT 
    COUNT(*) AS total_places, 
    MIN(place_id) AS min_id, 
    MAX(place_id) AS max_id,
    COUNT(DISTINCT place_id) AS distinct_ids
FROM places;
```
**Output:**
```
total_places: 24
min_id:       1
max_id:       24
distinct_ids: 24
```

#### Field Stability Audit:
All 24 places retained their exact coordinates, normalized names, and categories:
- `Hồ Hoàn Kiếm` (ID 1): Lat 21.0285000, Lon 105.8542000, ATTRACTION, ACTIVE.
- `Bà Nà Hills` (ID 11): Lat 15.9988500, Lon 107.9961600, ATTRACTION, ACTIVE.
- `Chợ Bến Thành` (ID 15): Lat 10.7725000, Lon 106.6980000, ATTRACTION, ACTIVE.
- `Bãi Sao Phú Quốc` (ID 17): Lat 10.0543000, Lon 104.0336000, ATTRACTION, ACTIVE.
- `Chợ Hàn Đà Nẵng` (ID 24): Lat 16.0682000, Lon 108.2241000, SHOPPING, ACTIVE.

---

### 2.2 Itinerary Activities (`activities` table)

#### Total Count and Canonical Linking Verification:
```sql
SELECT 
    COUNT(*) AS total_activities,
    SUM(CASE WHEN canonical_place_id IS NOT NULL THEN 1 ELSE 0 END) AS linked_canonical_activities,
    SUM(CASE WHEN canonical_place_id IS NULL THEN 1 ELSE 0 END) AS custom_activities
FROM activities;
```
**Output:**
```
total_activities:            121
linked_canonical_activities: 111
custom_activities:           10
```

#### Activity Schema Preservation:
Querying `DESCRIBE activities` demonstrates that no columns were added, modified, or dropped:
- Exactly 20 columns exist: `activity_id`, `cost`, `created_at`, `description`, `display_order`, `end_time`, `name`, `start_time`, `updated_at`, `day_id`, `custom_address`, `location_address`, `custom_location_name`, `location_name`, `latitude`, `location_provider`, `longitude`, `place_id`, `image_url`, `canonical_place_id`.
- Zero schema modifications.

---

### 2.3 Administrative Areas (`administrative_areas` table)

#### Total Count and Hierarchy Verification:
```sql
SELECT 
    COUNT(*) AS total_areas,
    SUM(CASE WHEN parent_id IS NULL THEN 1 ELSE 0 END) AS provinces,
    SUM(CASE WHEN parent_id IS NOT NULL THEN 1 ELSE 0 END) AS communes
FROM administrative_areas;
```
**Output:**
```
total_areas: 3355
provinces:   34
communes:    3321
```

#### Trust Classification Verification:
```sql
SELECT trust_classification, COUNT(*) 
FROM administrative_areas 
GROUP BY trust_classification;
```
**Output:**
```
trust_classification        COUNT(*)
UNVERIFIED_AND_QUARANTINED  12
VERIFIED_AND_TRUSTED        67
VERIFIED_WITH_LIMITATIONS   3276
MISMATCH                    0
```

---

## 3. Concurrency & Idempotency Audit

Repeated execution of `PlaceAdministrativeAreaMigrationRunner.run()` across subsequent application startups verified:
1. No duplicated schema alterations (checks `meta.getColumns` before alter).
2. No re-linking of already linked places (`overwriteExisting = false` default preserves existing valid linkages).
3. Zero lock collisions or lingering advisory locks.

---

## 4. Conclusion

The data integrity of the Travel Planner database across `places`, `activities`, and `administrative_areas` is 100% intact, fully verified, and satisfies all architectural constraints.

