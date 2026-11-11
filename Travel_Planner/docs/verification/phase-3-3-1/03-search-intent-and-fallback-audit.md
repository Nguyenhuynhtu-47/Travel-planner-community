# Phase 3.3.1 — Document 03: Search Intent & Fallback Correctness Audit

## 1. Problem Statement & Audit Discovery

During the Phase 3.3 audit, a search pipeline vulnerability was identified:
> "Khi người dùng tìm kiếm theo cú pháp POI + Địa danh (ví dụ `cơm tấm Long Xuyên`, `cafe Đà Lạt`, `khách sạn Nha Trang`), pipeline tìm kiếm có nguy cơ bị chiếm dụng quota kết quả bởi các thực thể administrative boundary từ danh mục nội bộ, dẫn đến việc chặn đứng (suppress) cơ chế fallback sang provider ngoài (LocationIQ/TomTom) để tìm địa điểm POI thực tế."

An end-to-end trace of `LocationServiceImpl.java` and `LocationRankingServiceImpl.java` confirmed this issue and established the required remediation.

---

## 2. Root Cause Analysis

### 2.1 Premature Short-Circuiting in `LocationServiceImpl`
Prior to Phase 3.3.1, `LocationServiceImpl.java` evaluated internal catalog results as follows:
```java
List<LocationSearchResultResponse> internalCandidates = searchInternalCatalog(trimmed, effectiveLimit);
if (internalCandidates.size() >= effectiveLimit) {
    List<LocationSearchResultResponse> rankedInternal = locationRankingService.rankAndDeduplicate(
            trimmed, internalCandidates, normalizedLat, normalizedLon, effectiveLimit
    );
    return rankedInternal; // Short-circuits immediately!
}
```
**The Flaw:** `searchInternalCatalog` returns both canonical Places (`type: "place"`) and eligible Administrative Areas (`type: "administrative"`). If `internalCandidates` contained administrative boundary polygons that matched any part of the query, `internalCandidates.size() >= effectiveLimit` could evaluate to `true`. This caused the search pipeline to return administrative polygons without ever triggering external POI fallback searches!

### 2.2 Unconditional `SYSTEM` Provider Ranking Boost
In `LocationRankingServiceImpl.java`, the relevance scoring function calculated:
```java
if ("SYSTEM".equalsIgnoreCase(item.getProvider())) {
    score += 50.0;
}
```
**The Flaw:** Both canonical `Place` entities and `AdministrativeArea` entities have `provider = "SYSTEM"`. For a POI search (e.g. `cơm tấm Long Xuyên`), an administrative boundary like `"Long Xuyên (Khu vực)"` received the full `+50.0` boost, enabling boundary polygons to outrank actual restaurants returned by external providers.

---

## 3. Targeted Remediation Implementation

### 3.1 Intent-Aware Short-Circuit in `LocationServiceImpl`
We modified both `searchLocations` and `searchLocationsUnified` in `LocationServiceImpl.java`:
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

// Only short-circuit if query is NOT a POI query OR internal POIs alone satisfy effectiveLimit
if ((!isPoiIntent && internalCandidates.size() >= effectiveLimit) || 
    (isPoiIntent && internalPoiCount >= effectiveLimit)) {
    return locationRankingService.rankAndDeduplicate(
            trimmed, internalCandidates, normalizedLat, normalizedLon, effectiveLimit
    );
}
```
**Result:** For any POI query, administrative boundaries are **never** permitted to satisfy the limit. The engine is guaranteed to proceed to Two-Stage search or standard search with external fallback.

### 3.2 Ranking Penalty and Conditional Boost in `LocationRankingServiceImpl`
We updated `LocationRankingServiceImpl.java` under `calculateScore`:
1. **Administrative Boundary Penalty for POI Queries:**
   ```java
   } else {
       // Service / POI search intent (!isCityQuery)
       if (matchesServiceIntent(normQuery, type, category)) {
           score += 45.0;
       }
       if (isFoodIntent(normQuery) && isIncompatibleFoodType(type, category)) {
           score -= 100.0;
       }
       // Administrative boundaries are not POIs: penalize so they never displace real venues
       if (isItemAdminPlace) {
           score -= 30.0;
       }
   }
   ```
2. **Conditional `SYSTEM` Boost:**
   ```java
   if ("SYSTEM".equalsIgnoreCase(item.getProvider())) {
       // Boost canonical places; only boost administrative boundaries if the user intended a city/locality query
       if (!isItemAdminPlace || isCityQuery) {
           score += 50.0;
       }
   }
   ```

---

## 4. Query Comparison & Verification Matrix

| Query Example | Query Classification | `isCityQuery` | Administrative Boundary Score | Real POI Candidate Score | Expected Winner |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `cơm tấm Long Xuyên` | POI + Location (`FOOD`) | `false` | Baseline - 30.0 (No +50 boost) ≈ **10.0** | Name Match (70) + Service (45) + Imp (15) ≈ **130.0** | **Quán Cơm Tấm** |
| `cafe Đà Lạt` | POI + Location (`CAFE`) | `false` | Baseline - 30.0 (No +50 boost) ≈ **10.0** | Name Match (70) + Service (45) + Imp (15) ≈ **130.0** | **Quán Cà Phê** |
| `Long Xuyên` | Locality / City | `true` | Name Match (70) + Admin Boost (65) + SYSTEM (50) ≈ **185.0** | Baseline (20) - Penalty (45) ≈ **-25.0** | **Administrative Area** |
| `Tỉnh Lâm Đồng` | Administrative Unit | `true` | Name Match (70) + Admin Boost (65) + SYSTEM (50) ≈ **185.0** | Baseline (20) - Penalty (45) ≈ **-25.0** | **Administrative Area** |

---

## 5. Automated Verification Proof

Test `testPoiQueryRanking_AdministrativePenalizedAndNoSystemBoost` in `LocationSearchAndFilteringTest.java`:
- **Scenario**: Query `cơm tấm Long Xuyên` evaluated against candidates:
  - Candidate 1: `Tỉnh An Giang` (`type: "administrative"`, `provider: "SYSTEM"`)
  - Candidate 2: `Quán Cơm Tấm Cây Điệp Long Xuyên` (`type: "restaurant"`, `provider: "LOCATION_IQ"`)
- **Outcome**: `Quán Cơm Tấm Cây Điệp Long Xuyên` ranked #1 with top score; `Tỉnh An Giang` ranked #2 with penalization.
- **Status**: **PASS (0 Failures, 0 Errors)**.

