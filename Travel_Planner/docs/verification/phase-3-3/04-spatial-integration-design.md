# Phase 3.3 — Artifact 04: Spatial Integration Design

## 1. Objective & Requirements

Phase 3.3.4 addresses geographic discovery of Places using coordinates:
1. **Nearby Place Discovery:** Finding Places within radius `R` (km) of coordinates `(latitude, longitude)`.
2. **Distance-Based Ranking:** Sorting nearby places in ascending order of Haversine distance.
3. **Bounding-Box Optimization:** Prefiltering candidate places using indexed latitude/longitude ranges to eliminate full-table scans.
4. **Coordinate Validation:** Rejecting out-of-range, NaN, or infinite coordinates.
5. **Spatial Correctness & Cadastral Invariant:** Geographical proximity alone **must never be used to automatically link an unassigned Place to an administrative area**.

---

## 2. Technical Architecture & Database Index Utilization

### 2.1 Index Optimization
The `places` table already has a composite B-tree index:
`KEY idx_places_coords (latitude, longitude)`

Given a query at `(lat, lon)` with radius `radiusKm`:
- Delta Latitude: `dLat = radiusKm / 111.0`
- Delta Longitude: `dLon = radiusKm / (111.0 * cos(radians(lat)))`
- Bounding Box: `[lat - dLat, lat + dLat]` x `[lon - dLon, lon + dLon]`

The query:
```sql
SELECT p FROM Place p WHERE p.status = 'ACTIVE' 
  AND p.latitude BETWEEN :minLat AND :maxLat 
  AND p.longitude BETWEEN :minLon AND :maxLon
```
executes an indexed range scan on `idx_places_coords`, fetching only candidate rows within the bounding square.

### 2.2 Accurate Haversine Distance Calculation
For candidate rows, exact great-circle distance is calculated using the Haversine formula:
```
a = sin²(Δφ/2) + cos(φ1) * cos(φ2) * sin²(Δλ/2)
c = 2 * atan2(√a, √(1−a))
distance = R * c
```
Where `R = 6,371,000` meters. Candidates with `distance <= radiusKm` are retained, sorted by distance ascending, and paginated.

---

## 3. Combining Spatial Radius and Administrative Area Filter

When both `radiusKm` (with coordinates) and `administrativeAreaCode` are provided:
1. Prefilter bounding box using `(latitude, longitude, radiusKm)`.
2. Filter candidates matching `administrativeArea.code` (or parent code if province).
3. Filter by category or keyword if provided.
4. Sort by distance ascending and return paginated `PlaceResponse`.

