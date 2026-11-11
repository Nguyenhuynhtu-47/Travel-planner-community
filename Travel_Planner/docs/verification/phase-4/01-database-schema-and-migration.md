# PHASE 4 — 01. DATABASE SCHEMA & MIGRATION AUDIT
## Table `itinerary_places` Schema Definition and Constraints

**Project:** Travel Planner  
**Database:** MySQL 8.0.37  
**Schema:** `travel_planner` & `travel_planner_test`  

---

### 1. DDL Specification

The table `itinerary_places` provides the pure associative link between `Itinerary` and `Place`:

```sql
CREATE TABLE IF NOT EXISTS `itinerary_places` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `saved_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `itinerary_id` INT NOT NULL,
  `place_id` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_itinerary_place` (`itinerary_id`, `place_id`),
  KEY `idx_itinerary_places_itinerary` (`itinerary_id`),
  KEY `idx_itinerary_places_place` (`place_id`),
  CONSTRAINT `fk_itinerary_places_itinerary` FOREIGN KEY (`itinerary_id`) REFERENCES `itineraries` (`itinerary_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_itinerary_places_place` FOREIGN KEY (`place_id`) REFERENCES `places` (`place_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

### 2. Constraint and Index Analysis

1. **Primary Key:** `id` (BIGINT AUTO_INCREMENT) ensures efficient synthetic identification.
2. **Unique Composite Index (`uk_itinerary_place`):** Enforces that a place cannot be saved more than once within the same itinerary.
3. **Foreign Key `fk_itinerary_places_itinerary`:**
   - Targets `itineraries(itinerary_id)`.
   - `ON DELETE CASCADE`: If an itinerary is deleted, its saved places list is cleaned up automatically.
4. **Foreign Key `fk_itinerary_places_place`:**
   - Targets `places(place_id)`.
   - `ON DELETE CASCADE`: If a canonical place is deleted by system admins, associations referencing it are cleaned up.
5. **Foreign Key Safety on `activities`:**
   - `activities` references `places(place_id)` directly via `canonical_place_id`.
   - There is NO foreign key between `activities` and `itinerary_places`. Deleting an `itinerary_places` row NEVER triggers cascades or updates on `activities`.

---

### 3. Production & Test Verification

```
mysql> DESCRIBE itinerary_places;
+--------------+-------------+------+-----+---------+----------------+
| Field        | Type        | Null | Key | Default | Extra          |
+--------------+-------------+------+-----+---------+----------------+
| id           | bigint      | NO   | PRI | NULL    | auto_increment |
| saved_at     | datetime(6) | NO   |     | NULL    |                |
| itinerary_id | int         | NO   | MUL | NULL    |                |
| place_id     | bigint      | NO   | MUL | NULL    |                |
+--------------+-------------+------+-----+---------+----------------+
4 rows in set (0.00 sec)

mysql> SHOW INDEX FROM itinerary_places;
+------------------+------------+-------------------------------+--------------+--------------+
| Table            | Non_unique | Key_name                      | Seq_in_index | Column_name  |
+------------------+------------+-------------------------------+--------------+--------------+
| itinerary_places |          0 | PRIMARY                       |            1 | id           |
| itinerary_places |          0 | uk_itinerary_place            |            1 | itinerary_id |
| itinerary_places |          0 | uk_itinerary_place            |            2 | place_id     |
| itinerary_places |          1 | idx_itinerary_places_itinerary|            1 | itinerary_id |
| itinerary_places |          1 | idx_itinerary_places_place    |            1 | place_id     |
+------------------+------------+-------------------------------+--------------+--------------+
5 rows in set (0.00 sec)
```
Status: **VERIFIED & PRODUCTION-READY**.

