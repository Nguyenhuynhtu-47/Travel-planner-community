# Phase 3.3.1 — Document 04: Spatial Index & Query Plan (EXPLAIN) Audit

## 1. Spatial Architecture Overview

To enable fast geographic proximity search and bounding box discovery without requiring expensive spatial extensions (such as PostGIS or spatial R-Tree overhead for small-to-medium POI collections), the system employs a two-tier spatial query strategy:
1. **Tier 1 (Database Level):** An indexed B-Tree bounding box query using composite index `idx_places_coords (latitude, longitude)` on table `places`.
2. **Tier 2 (Application Level):** High-precision Haversine spherical distance filtering to eliminate candidates in the bounding box's corners beyond the true spherical radius, followed by distance sorting and pagination.

---

## 2. MySQL 8.0 `EXPLAIN` & `EXPLAIN ANALYZE` Verification

### 2.1 Test Query Formulation
```sql
EXPLAIN ANALYZE
SELECT place_id, name, latitude, longitude, status, administrative_area_id
FROM places
WHERE latitude BETWEEN 10.7000000 AND 10.8500000
  AND longitude BETWEEN 106.6000000 AND 106.7500000
  AND status = 'ACTIVE';
```

### 2.2 Execution Plan Output
```text
-> Filter: ((places.`status` = 'ACTIVE') and (places.longitude between 106.6000000 and 106.7500000))  (cost=1.16 rows=1) (actual time=0.102..0.133 rows=1 loops=1)
    -> Index range scan on places using idx_places_coords over (10.7000000 <= latitude <= 10.8500000), with index condition: (places.latitude between 10.7000000 and 10.8500000)  (cost=1.16 rows=1) (actual time=0.089..0.118 rows=1 loops=1)
```

### 2.3 Tabular EXPLAIN Analysis
| Select Type | Table | Type | Possible Keys | Key Used | Key Length | Ref | Rows Examined | Filtered % | Extra Information |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `SIMPLE` | `places` | `range` | `idx_places_coords` | `idx_places_coords` | `12` | `NULL` | 1 | 100.00% | `Using index condition; Using where` |

### 2.4 Detailed Execution Plan & Index Behavior Analysis
- **Key Length 12 Bytes:** The composite index consists of two `DECIMAL(10,7)` columns (`latitude`, `longitude`).
- **Index Range Scan on Latitude:** The B-Tree index scan traverses the range on the first indexed column: `with index condition: (places.latitude between 10.7000000 and 10.8500000)`.
- **Secondary Evaluation in Filter Stage:** In multi-column B-Tree indexing, once a range predicate (`BETWEEN`) is evaluated on the leading column (`latitude`), the second column (`longitude`) cannot narrow the B-Tree range further. As explicitly confirmed by the execution tree, the predicate `places.longitude between 106.6000000 and 106.7500000` is evaluated in the Filter step along with `status = 'ACTIVE'`.
- **Current Performance & Dataset Scope:** For the current canonical catalog of 24 places, the query cost is **1.16** and actual execution time is **~0.102 ms**. This confirms fast, sub-millisecond lookup for the current catalog scale. Note: Claims of scalability to tens of thousands of places must not be extrapolated from a 24-record dataset without dedicated synthetic load testing; if the catalog expands to high volumes in future phases, true spatial indexing (e.g. MySQL `POINT` + Spatial R-Tree index) may be evaluated.

---

## 3. Mathematical Formula & Distance Calculation

### 3.1 Bounding Box Calculation
At latitude $\phi$ and Earth radius $R \approx 6,371\text{ km}$:
$$\Delta \phi = \frac{r}{111.0} \quad (\text{degrees latitude})$$
$$\Delta \lambda = \frac{r}{111.0 \times \cos(\phi)} \quad (\text{degrees longitude})$$
The query bounding box is bounded by:
$$[\phi - \Delta \phi, \phi + \Delta \phi] \times [\lambda - \Delta \lambda, \lambda + \Delta \lambda]$$

### 3.2 Haversine Spherical Distance Formula
Given user position $(\phi_1, \lambda_1)$ and place candidate $(\phi_2, \lambda_2)$:
$$a = \sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)$$
$$d = 2 R \cdot \operatorname{atan2}\left(\sqrt{a}, \sqrt{1 - a}\right)$$
Candidates where $d \le r$ are preserved, distance is formatted to 2 decimal places in `distanceKm`, and results are sorted ascending by distance.

---

## 4. Edge Cases & Defensive Hardening Remediation

During the Phase 3.3.1 audit, three mathematical and API edge cases were identified and hardened:

### 4.1 Polar Latitude Division-by-Zero Protection
- **Vulnerability:** When $\phi \to \pm 90^\circ$ (near the North or South Pole), $\cos(\phi) \to 0$. Division by $\cos(\phi)$ yielded `Infinity` or `NaN`.
- **Remediation in `PlaceServiceImpl.java`:**
  ```java
  double cosLat = Math.cos(Math.toRadians(lat));
  double dLon = Math.abs(cosLat) > 1e-6 ? (radiusKm / (111.0 * cosLat)) : 180.0;
  ```

### 4.2 Coordinate Clamping to Valid Geographic Bounds
- **Vulnerability:** Large radii near poles or the antimeridian could compute bounding boxes exceeding $[-90, 90]$ or $[-180, 180]$.
- **Remediation in `PlaceServiceImpl.java`:**
  ```java
  BigDecimal minLat = BigDecimal.valueOf(Math.max(-90.0, lat - dLat));
  BigDecimal maxLat = BigDecimal.valueOf(Math.min(90.0, lat + dLat));
  BigDecimal minLon = BigDecimal.valueOf(Math.max(-180.0, lon - dLon));
  BigDecimal maxLon = BigDecimal.valueOf(Math.min(180.0, lon + dLon));
  ```

### 4.3 Radius Input Validation & Coordinate Coupling
- **Vulnerability:** Negative radius, zero radius, or extreme radius (e.g. 10,000 km) could degrade performance or throw unhandled exceptions.
- **Remediation in `PlaceServiceImpl.java`:**
  ```java
  if (radiusKm != null) {
      if (radiusKm <= 0.0 || radiusKm > 500.0) {
          throw new BadRequestException("Bán kính tìm kiếm (radiusKm) phải lớn hơn 0 và không vượt quá 500 km");
      }
      if (lat == null || lon == null) {
          throw new BadRequestException("Tọa độ latitude và longitude phải được cung cấp cùng với radiusKm");
      }
  }
  ```

---

## 5. Verification Test Suite Status

The spatial improvements are validated by automated tests in `LocationSearchAndFilteringTest.java`:
1. `testSpatialDiscovery_RadiusFiltering`: Verifies nearby places sorted by distance.
2. `testSpatialDiscovery_RadiusValidation`: Verifies rejection of radius <= 0, radius > 500, or missing coordinates.
3. `testSpatialDiscovery_PolarCoordinateClamping`: Verifies near-pole queries (lat=89.9999) execute safely.
4. `testSpatialEndpoint_InvalidRadiusThrowsBadRequest`: Verifies HTTP 400 Bad Request on negative radius via `/api/places`.
- **Status:** **ALL 4 TESTS PASS**.

