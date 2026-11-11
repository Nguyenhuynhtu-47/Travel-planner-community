# Phase 3.3.1 — Document 07: Targeted Gap Remediation Report

## 1. Remediation Overview

During Phase 3.3.1, targeted engineering remediations were designed, implemented, and verified to resolve all architectural and algorithmic gaps identified in the Phase 3.3 post-implementation audit.

```
[Phase 3.3.1 Remediations]
├── Remediation 1: Intent-Aware Internal Search Short-Circuiting (LocationServiceImpl)
├── Remediation 2: Boundary Penalization & Conditional System Boost (LocationRankingServiceImpl)
├── Remediation 3: Spatial Bounds Clamping, Polar Protection & Radius Validation (PlaceServiceImpl)
└── Remediation 4: Comprehensive Regression & Integration Test Suite Hardening
```

---

## 2. Remediation 1: Intent-Aware Internal Catalog Short-Circuiting

- **File Modified**: `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java`
- **Issue**: In `searchLocationsUnified` and `searchLocations`, if `internalCandidates.size() >= effectiveLimit`, the engine returned immediately. For POI queries (e.g. `cơm tấm Long Xuyên`, `cafe Đà Lạt`), administrative boundaries could consume the limit and block external fallback.
- **Implementation**:
  ```java
  ParsedLocationQuery parsed = queryUnderstandingService.parseQuery(trimmed);
  boolean isPoiIntent = parsed != null && (
          parsed.getSearchIntent() == SearchIntent.POI_IN_LOCATION || 
          parsed.getSearchIntent() == SearchIntent.GENERIC_POI
  );

  List<LocationSearchResultResponse> internalCandidates = searchInternalCatalog(trimmed, effectiveLimit);
  long internalPoiCount = internalCandidates.stream()
          .filter(r -> "place".equalsIgnoreCase(r.getType()))
          .count();

  if ((!isPoiIntent && internalCandidates.size() >= effectiveLimit) || 
      (isPoiIntent && internalPoiCount >= effectiveLimit)) {
      return locationRankingService.rankAndDeduplicate(
              trimmed, internalCandidates, normalizedLat, normalizedLon, effectiveLimit
      );
  }
  ```
- **Outcome**: When searching for POIs, administrative boundaries never satisfy the result quota. The pipeline always proceeds to Two-Stage search or standard search with external fallback.

---

## 3. Remediation 2: Administrative Ranking Penalization in POI Queries

- **File Modified**: `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationRankingServiceImpl.java`
- **Issue**: Administrative boundary polygons received the `+50.0 SYSTEM` boost unconditionally and lacked negative scoring during POI searches, allowing boundary nodes to outrank actual venues.
- **Implementation**:
  ```java
  // In calculateScore:
  if (isCityQuery) {
      // Existing city ranking logic...
  } else {
      // Service / POI search intent
      if (matchesServiceIntent(normQuery, type, category)) {
          score += 45.0;
      }
      if (isFoodIntent(normQuery) && isIncompatibleFoodType(type, category)) {
          score -= 100.0;
      }
      // Penalize administrative boundaries in POI queries
      if (isItemAdminPlace) {
          score -= 30.0;
      }
  }

  // Provider boost:
  if ("SYSTEM".equalsIgnoreCase(item.getProvider())) {
      if (!isItemAdminPlace || isCityQuery) {
          score += 50.0;
      }
  }
  ```
- **Outcome**: For POI queries, boundary polygons receive `-30.0` penalty and are denied the `+50.0` boost. Real POIs consistently outrank administrative areas.

---

## 4. Remediation 3: Spatial Defensive Hardening & Polar Clamping

- **File Modified**: `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/PlaceServiceImpl.java`
- **Issues**:
  1. Potential division by zero at polar latitudes ($\cos(\pm 90^\circ) \to 0$).
  2. Bounding boxes could theoretically overflow valid coordinate space.
  3. Radius parameter lacked boundary validation ($r \le 0$ or extreme values).
- **Implementation**:
  ```java
  // 1. Radius and coordinate validation in getPublicPlaces:
  if (radiusKm != null) {
      if (radiusKm <= 0.0 || radiusKm > 500.0) {
          throw new BadRequestException("Bán kính tìm kiếm (radiusKm) phải lớn hơn 0 và không vượt quá 500 km");
      }
      if (lat == null || lon == null) {
          throw new BadRequestException("Tọa độ latitude và longitude phải được cung cấp cùng với radiusKm");
      }
      validateCoordinates(BigDecimal.valueOf(lat), BigDecimal.valueOf(lon));
      return searchByRadiusWithAdminArea(trimmedKw, normKw, category, resolvedAreaId, isProvince, lat, lon, radiusKm, pageable);
  } else if (lat != null && lon != null) {
      validateCoordinates(BigDecimal.valueOf(lat), BigDecimal.valueOf(lon));
  }

  // 2. Polar protection & coordinate clamping in searchByRadiusWithAdminArea & resolveOrPersistPlace:
  double cosLat = Math.cos(Math.toRadians(lat));
  double dLat = radiusKm / 111.0;
  double dLon = Math.abs(cosLat) > 1e-6 ? (radiusKm / (111.0 * cosLat)) : 180.0;

  BigDecimal minLat = BigDecimal.valueOf(Math.max(-90.0, lat - dLat));
  BigDecimal maxLat = BigDecimal.valueOf(Math.min(90.0, lat + dLat));
  BigDecimal minLon = BigDecimal.valueOf(Math.max(-180.0, lon - dLon));
  BigDecimal maxLon = BigDecimal.valueOf(Math.min(180.0, lon + dLon));
  ```
- **Outcome**: Spatial searches are completely immune to division by zero, invalid coordinate overflows, and unvalidated radius values.

---

## 5. Remediation 4: Automated Integration Tests

- **File Modified**: `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/LocationSearchAndFilteringTest.java`
- **Tests Added**:
  1. `testPoiQueryRanking_AdministrativePenalizedAndNoSystemBoost`: Verifies restaurant POI outranks provincial boundary in `cơm tấm Long Xuyên`.
  2. `testSpatialDiscovery_RadiusValidation`: Verifies rejection of radius <= 0, radius > 500, or missing coordinates.
  3. `testSpatialDiscovery_PolarCoordinateClamping`: Verifies near-pole queries (lat=89.9999) execute without mathematical exceptions.
  4. `testSpatialEndpoint_InvalidRadiusThrowsBadRequest`: Verifies HTTP 400 Bad Request on negative radius via mockMvc.
- **Outcome**: Total tests in `LocationSearchAndFilteringTest` increased from 13 to **17 PASS** (0 failures, 0 errors).

