# Phase 3.2 — Database Migration & Schema Hardening Report
**Target Snapshot:** 2026-09-20  
**Phase:** 3.2 — Place–Administrative Area Linking & Resolution  
**Advisory Lock:** `place_administrative_area_migration_lock` (timeout 10s, max 3 attempts)  
**Execution Date:** 2026-11-11

---

## 1. Executive Summary

Phase 3.2 establishes the foreign key relationship and trust hierarchy connecting the destination catalog (`places`) with the official national administrative catalog (`administrative_areas`).

The database migration was executed using an idempotent migration runner (`PlaceAdministrativeAreaMigrationRunner`) ordered strictly after catalog import (`@Order(6)`), acquiring a dedicated single-connection MySQL advisory lock to guarantee cluster-wide concurrency safety without deadlocks or race conditions.

---

## 2. DDL & Schema Changes

### 2.1 Table `administrative_areas` (Enhancement)
Added column `trust_classification` to represent the 4-tier data verification classification:

```sql
ALTER TABLE administrative_areas 
  ADD COLUMN trust_classification VARCHAR(40) NOT NULL DEFAULT 'VERIFIED_WITH_LIMITATIONS';

CREATE INDEX idx_admin_areas_trust_class 
  ON administrative_areas(trust_classification);
```

#### Final Schema:
```sql
CREATE TABLE `administrative_areas` (
  `area_id` bigint NOT NULL AUTO_INCREMENT,
  `area_type` enum('CENTRAL_CITY','COMMUNE','PROVINCE','SPECIAL_ZONE','WARD') COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `effective_from` date DEFAULT NULL,
  `effective_to` date DEFAULT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `normalized_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('ACTIVE','HISTORICAL','INACTIVE') COLLATE utf8mb4_unicode_ci NOT NULL,
  `trust_classification` enum('MISMATCH','UNVERIFIED_AND_QUARANTINED','VERIFIED_AND_TRUSTED','VERIFIED_WITH_LIMITATIONS') COLLATE utf8mb4_unicode_ci NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `parent_id` bigint DEFAULT NULL,
  PRIMARY KEY (`area_id`),
  UNIQUE KEY `uk_admin_areas_code` (`code`),
  KEY `idx_admin_areas_parent_id` (`parent_id`),
  KEY `idx_admin_areas_normalized_name` (`normalized_name`),
  KEY `idx_admin_areas_type_status` (`area_type`,`status`),
  KEY `idx_admin_areas_trust_class` (`trust_classification`),
  CONSTRAINT `fk_admin_areas_parent` FOREIGN KEY (`parent_id`) REFERENCES `administrative_areas` (`area_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3356 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.2 Table `places` (Linking)
Added foreign key referencing `administrative_areas(area_id)`:

```sql
ALTER TABLE places 
  ADD COLUMN administrative_area_id BIGINT NULL;

ALTER TABLE places 
  ADD CONSTRAINT fk_places_admin_area 
  FOREIGN KEY (administrative_area_id) REFERENCES administrative_areas(area_id) 
  ON DELETE SET NULL;

CREATE INDEX idx_places_admin_area 
  ON places(administrative_area_id);
```

#### Final Schema:
```sql
CREATE TABLE `places` (
  `place_id` bigint NOT NULL AUTO_INCREMENT,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `category` enum('ATTRACTION','CAFE','ENTERTAINMENT','HOTEL','OTHER','RESTAURANT','SHOPPING') COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `image_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `normalized_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('ACTIVE','HIDDEN') COLLATE utf8mb4_unicode_ci NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `administrative_area_id` bigint DEFAULT NULL,
  PRIMARY KEY (`place_id`),
  KEY `idx_places_normalized_name` (`normalized_name`),
  KEY `idx_places_category` (`category`),
  KEY `idx_places_status` (`status`),
  KEY `idx_places_coords` (`latitude`,`longitude`),
  KEY `idx_places_admin_area` (`administrative_area_id`),
  CONSTRAINT `fk_places_admin_area` FOREIGN KEY (`administrative_area_id`) REFERENCES `administrative_areas` (`area_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 3. Concurrency & Advisory Lock Hardening

To prevent migration collisions in clustered deployments, `PlaceAdministrativeAreaMigrationRunner` uses a dedicated single-connection pattern:
- **Lock Identifier:** `place_administrative_area_migration_lock`
- **Acquisition Strategy:** `SELECT GET_LOCK('place_administrative_area_migration_lock', 10)` executed over an un-pooled single `Connection` instance that remains open for the entire lifecycle of schema validation and initial batch linking.
- **Safe Release:** In a mandatory `finally` block, `SELECT RELEASE_LOCK('place_administrative_area_migration_lock')` is executed before closing the dedicated connection.
- **Node Collision Behavior:** If another cluster node holds the lock after 3 retries (10s timeout, 1s backoff), the runner logs a warning and gracefully skips execution.

---

## 4. Rollback & Forward Strategy

| Migration Phase | Failure Mode | Recovery Action |
| :--- | :--- | :--- |
| Schema Alteration | DDL failure on `trust_classification` | Script rolls back transparently; column creation uses `IF NOT EXISTS` check via JDBC `DatabaseMetaData`. |
| Place FK Addition | Column `administrative_area_id` exists | Runner queries `meta.getColumns` before executing `ALTER TABLE`; idempotency ensured. |
| Re-import / Linking | Transient network or DB failure | Advisory lock released in `finally` block; subsequent startup run resumes linking for unlinked records. |
| Production Rollback | Emergency feature deactivation | `ALTER TABLE places DROP FOREIGN KEY fk_places_admin_area; ALTER TABLE places DROP COLUMN administrative_area_id;`. Places and Activities remain completely functional. |

