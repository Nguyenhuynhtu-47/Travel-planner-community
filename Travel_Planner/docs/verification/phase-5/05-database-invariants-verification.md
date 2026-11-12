# PHASE 5 — DATABASE INVARIANTS VERIFICATION

**Project:** Travel Planner  
**Phase:** 5 — Clone Itinerary  
**Target Snapshot Date:** 2026-09-20  
**Database:** MySQL 8.0.37 (`travel_planner`)  
**Git Branch:** `develop`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  

---

## 1. THE 4 CRITICAL DATABASE INVARIANTS

During Phase 5 implementation and verification, all four critical project invariants were strictly monitored and audited.

```sql
-- Verification Query
USE travel_planner;
SELECT trust_classification, COUNT(*) FROM administrative_areas GROUP BY trust_classification;
SELECT place_id, name, administrative_area_id FROM places WHERE place_id IN (11, 12, 20, 22);
SELECT COUNT(*) AS total_activities FROM activities;
SELECT COUNT(*) AS total_places FROM places;
SELECT COUNT(*) AS total_itineraries FROM itineraries;
```

---

## 2. AUDIT EVIDENCE & RESULTS

### 2.1 Invariant 1 — Northern Bắc Ninh Quarantined Units
- **Requirement:** Exactly 12 administrative units in Bắc Ninh must remain `UNVERIFIED_AND_QUARANTINED` due to Resolution 388/NQ-UBTVQH16 official boundary restrictions. Zero promotion to trusted.
- **Audit Result:**
  ```
  trust_classification        COUNT(*)
  UNVERIFIED_AND_QUARANTINED  12
  VERIFIED_AND_TRUSTED        67
  VERIFIED_WITH_LIMITATIONS   3276
  ```
- **Status:** **PASS (100% INTACT)**.

### 2.2 Invariant 2 — Ambiguous Places Retain NULL Administrative Area
- **Requirement:** Places 11, 12, 20, and 22 must retain `administrative_area_id = NULL` due to unresolved commune boundaries. Zero false associations.
- **Audit Result:**
  ```
  place_id  name                                             administrative_area_id
  11        Bà Nà Hills & Cầu Vàng                           NULL
  12        Bán Đảo Sơn Trà & Chùa Linh Ứng                  NULL
  20        Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)  NULL
  22        Chợ Đêm Sơn Trà                                  NULL
  ```
- **Status:** **PASS (100% INTACT)**.

### 2.3 Invariant 3 — Activities Baseline Count
- **Requirement:** Total activities in `travel_planner` baseline must remain unchanged at 121 activities.
- **Audit Result:**
  ```
  total_activities: 121
  ```
- **Status:** **PASS (100% INTACT)**.

### 2.4 Invariant 4 — Places Catalog Zero Duplication
- **Requirement:** Total places in `travel_planner` catalog must remain exactly 24. Zero duplicate place records created during tests or cloning.
- **Audit Result:**
  ```
  total_places: 24
  ```
- **Status:** **PASS (100% INTACT)**.

### 2.5 Total Itineraries Baseline
- **Audit Result:**
  ```
  total_itineraries: 28
  ```
- **Status:** **PASS (100% INTACT)**. Dev database untouched; all tests execute in isolated `travel_planner_test` database.

