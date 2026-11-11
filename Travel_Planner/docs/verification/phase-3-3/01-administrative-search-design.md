# Phase 3.3 — Artifact 01: Administrative Hierarchy Search Design

## 1. Objective & Requirements

Phase 3.3.1 requires an internal administrative discovery service enabling users to:
1. Search administrative units by keyword (with Vietnamese diacritics, case-insensitive, unaccented partial match, or exact code match).
2. Navigate the administrative hierarchy (Province/City → Commune/Ward/Special Zone).
3. Retrieve child units of any province/city.
4. Strictly exclude the 12 quarantined Northern Bắc Ninh units (`07294..09496`) from public search and child listings.

---

## 2. Technical Design & Repository Queries

### 2.1 Strict Quarantine Exclusion Invariant
The query for administrative search and child listing must enforce the quarantine invariant directly in JPQL/SQL:
```sql
WHERE a.status = :status 
  AND a.trustClassification <> Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED
```
This ensures that even if an unverified unit is marked `ACTIVE`, it is mathematically excluded from being returned to clients.

### 2.2 Search Query Strategy
In `AdministrativeAreaRepository`:
```java
@Query("SELECT a FROM AdministrativeArea a LEFT JOIN FETCH a.parent " +
       "WHERE (a.normalizedName LIKE %:keyword% OR a.code = :exactCode) " +
       "  AND a.status = :status " +
       "  AND a.trustClassification <> Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED " +
       "ORDER BY CASE " +
       "  WHEN a.code = :exactCode THEN 0 " +
       "  WHEN a.normalizedName = :exactNorm THEN 1 " +
       "  WHEN a.normalizedName LIKE :prefixNorm THEN 2 " +
       "  ELSE 3 END, a.code ASC")
List<AdministrativeArea> searchNonQuarantined(
        @Param("keyword") String keyword,
        @Param("exactCode") String exactCode,
        @Param("exactNorm") String exactNorm,
        @Param("prefixNorm") String prefixNorm,
        @Param("status") AdministrativeAreaStatus status,
        Pageable pageable
);
```

### 2.3 Child Listing Strategy
In `AdministrativeAreaRepository`:
```java
@Query("SELECT a FROM AdministrativeArea a " +
       "WHERE a.parent.code = :parentCode " +
       "  AND a.status = :status " +
       "  AND a.trustClassification <> Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED " +
       "ORDER BY a.name ASC, a.code ASC")
List<AdministrativeArea> findNonQuarantinedChildrenByParentCode(
        @Param("parentCode") String parentCode,
        @Param("status") AdministrativeAreaStatus status
);
```

---

## 3. Endpoints & Response Contracts

1. **`GET /api/administrative-areas/provinces`**
   - Returns all 34 provinces/central cities.
   - Cached in Caffeine for high performance.
2. **`GET /api/administrative-areas/{code}/children`**
   - Returns eligible non-quarantined child units (wards, communes, special zones) belonging to province `code`.
   - Returns 404 if province code does not exist.
   - For Bắc Ninh (`24`), returns only the 87 verified active communes/wards; the 12 quarantined units are omitted.
3. **`GET /api/administrative-areas/search?q={query}&limit={limit}`**
   - Dispatches search query to `searchNonQuarantined`.
   - Supports exact code, prefix, and substring matching.
   - Returns `AdministrativeAreaSearchResultResponse` with parent province context.

