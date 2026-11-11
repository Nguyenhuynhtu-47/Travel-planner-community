# Phase 3.3 — Artifact 03: Internal Place Search & Provider Fallback Design

## 1. Objective & Search Priority Hierarchy

Phase 3.3.3 establishes an authoritative search priority pipeline in `LocationServiceImpl`:
1. **Priority 1: Canonical Internal Places (`places` table)**
   - Search active canonical Places by exact name, normalized unaccented name, or address keyword.
   - Return matched internal Places with `provider = "SYSTEM"`, `importance = 1.0`, and full coordinate metadata.
2. **Priority 2: Eligible Administrative Areas (`administrative_areas` table)**
   - Search non-quarantined administrative areas (Provinces, Wards, Communes, Special Zones).
   - If matched, surface as locality/boundary suggestions (`category = "boundary"`, `type = "administrative"`, `isLocalityFallback = true`).
3. **Priority 3: External Geocoding Providers (LocationIQ / HERE / TomTom)**
   - Invoked as fallback when internal results are fewer than the client's requested limit (`effectiveLimit`).
   - Reuses existing `QueryUnderstandingService`, `GeographicFilterService`, and provider fallbacks.
4. **Priority 4: Semantic Ranking & Deduplication**
   - Deduplicate provider results against internal canonical places based on name similarity and geographic proximity (< 100 meters).
   - Internal canonical Places always outrank external provider candidates.

---

## 2. Pipeline Architecture in `LocationServiceImpl`

```
User Query (e.g. "Hồ Hoàn Kiếm", "Cơm tấm ở Long Xuyên", "Bà Nà Hills")
                      │
                      ▼
         [Query Understanding Parser]
                      │
                      ▼
 ┌─────────────────────────────────────────────────────────┐
 │ Stage 1: Internal Search                                │
 │   ├── A. Search `places` (ACTIVE status only)           │
 │   └── B. Search `administrative_areas` (non-quarantined)│
 └────────────────────────────┬────────────────────────────┘
                              │
                    Internal Results Count >= Limit?
                   ├── YES ──► Rank & Return Internal Candidates
                   │
                   └── NO  ──► Stage 2: External Provider Fallback
                               ├── LocationIQ / TomTom
                               ├── HERE Geocoding fallback
                               ├── Strict Geographic Filtering
                               └── Rank & Deduplicate with Internal Results
```

---

## 3. Deduplication & Transformation Rules

1. **Internal Place Conversion to `LocationSearchResultResponse`:**
   ```java
   LocationSearchResultResponse.builder()
       .placeId("place_" + p.getPlaceId())
       .name(p.getName())
       .formattedAddress(p.getAddress())
       .latitude(p.getLatitude().doubleValue())
       .longitude(p.getLongitude().doubleValue())
       .category(p.getCategory().name())
       .type("place")
       .importance(1.0)
       .provider("SYSTEM")
       .isLocalityFallback(false)
       .build();
   ```
2. **Administrative Area Conversion:**
   ```java
   LocationSearchResultResponse.builder()
       .placeId("admin_" + a.getCode())
       .name(a.getName() + (a.getParent() != null ? ", " + a.getParent().getName() : ""))
       .formattedAddress(a.getName() + (a.getParent() != null ? ", " + a.getParent().getName() : ""))
       .category("boundary")
       .type("administrative")
       .importance(0.8)
       .provider("SYSTEM")
       .isLocalityFallback(true)
       .build();
   ```
3. **Quarantine Invariant:** The administrative search query within the pipeline strictly excludes all 12 quarantined Northern Bắc Ninh codes.

