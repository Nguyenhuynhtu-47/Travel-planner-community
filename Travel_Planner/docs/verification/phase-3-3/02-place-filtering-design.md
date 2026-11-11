# Phase 3.3 — Artifact 02: Place Filtering by Administrative Area Design

## 1. Objective & Filtering Scenarios

Phase 3.3.2 requires flexible, accurate filtering of canonical Places based on administrative area boundaries:
1. **Province/City Level Filtering:** Selecting a province (e.g. Đà Nẵng `48`, Hà Nội `01`, TP. Hồ Chí Minh `79`) returns:
   - Places directly linked to the province (provincial fallback), PLUS
   - Places linked to any child commune, ward, or special zone belonging to that province.
2. **Commune/Ward Level Filtering:** Selecting a commune or ward (e.g. `00070` Phường Hàng Gai) returns only Places directly linked to that specific administrative unit.
3. **Compound Filtering:** Combining administrative area with `category` (e.g. `ATTRACTION`, `FOOD`, `CAFE`, `HOTEL`) and/or `keyword` (e.g. "Cơm tấm", "Bảo tàng").
4. **Ambiguous Places Invariant:** Places with `administrative_area_id = NULL` (Places 11, 12, 20, 22) must never match when an administrative area filter is applied, preventing misattribution.

---

## 2. Technical Query Strategy in PlaceRepository

### 2.1 Multi-Tier Administrative Filtering Query
```java
@Query("SELECT p FROM Place p WHERE p.status = 'ACTIVE' " +
       "AND (:category IS NULL OR p.category = :category) " +
       "AND (:keyword IS NULL OR :keyword = '' OR " +
       "     LOWER(p.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
       "     LOWER(p.normalizedName) LIKE LOWER(CONCAT('%', :normKeyword, '%')) OR " +
       "     LOWER(p.address) LIKE LOWER(CONCAT('%', :keyword, '%'))) " +
       "AND (" +
       "     (:areaId IS NULL) OR " +
       "     (:isProvince = true AND (p.administrativeArea.areaId = :areaId OR p.administrativeArea.parent.areaId = :areaId)) OR " +
       "     (:isProvince = false AND p.administrativeArea.areaId = :areaId)" +
       ")")
Page<Place> searchPlacesWithAdminArea(
        @Param("keyword") String keyword,
        @Param("normKeyword") String normKeyword,
        @Param("category") PlaceCategory category,
        @Param("areaId") Long areaId,
        @Param("isProvince") Boolean isProvince,
        Pageable pageable
);
```

### 2.2 Execution Logic in PlaceServiceImpl
1. If `administrativeAreaCode` is passed in:
   - Look up `AdministrativeArea` via `administrativeAreaRepository.findByCode(code)`.
   - If not found or if `trustClassification == UNVERIFIED_AND_QUARANTINED`, return an empty page (quarantined units contain 0 valid places).
   - Determine `isProvince = (area.getAreaType() == PROVINCE || area.getAreaType() == CENTRAL_CITY)`.
   - Pass `area.getAreaId()` and `isProvince` into `searchPlacesWithAdminArea`.
2. If `latitude`, `longitude`, and `radiusKm` are also provided:
   - Combine bounding-box prefilter with administrative area filter in-memory or via composite query.

---

## 3. Endpoints & Compatibility

1. **`GET /api/places`**
   - New parameters:
     - `administrativeAreaCode` (`String`, optional): 2 to 5 digit administrative code.
     - `administrativeAreaId` (`Long`, optional): Internal ID of the administrative area.
   - Backward compatible: If omitted, existing keyword, category, and spatial search behavior is 100% preserved.
2. **`GET /api/administrative-areas/{code}/places`**
   - Resource-oriented convenience endpoint forwarding to `placeService.searchPlacesByAreaCode(...)`.
   - Parameters: `category`, `keyword`, `page`, `size`, `sort`.

