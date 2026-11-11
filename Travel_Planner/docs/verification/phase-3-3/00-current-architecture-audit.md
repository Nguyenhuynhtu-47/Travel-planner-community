# Phase 3.3 — Artifact 00: Current Architecture Audit

## 1. Executive Summary & Audit Context

Phase 3.3 aims to implement an integrated location discovery, administrative-area filtering, and spatial search system across the Travel Planner application. In accordance with Section IV of the Phase 3.3 Master Prompt, this document details the current state of the backend services, database schema, Flutter mobile and web clients, identifies existing reusable components and functional gaps, and establishes a safe, non-destructive implementation plan.

---

## 2. Backend Architecture Audit

### 2.1 Administrative Areas Subsystem
- **Entity:** `AdministrativeArea` (table `administrative_areas`). Fields: `area_id`, `code`, `name`, `normalized_name`, `area_type`, `trust_classification`, `status`, `parent_id`.
- **Repository:** `AdministrativeAreaRepository` with queries:
  - `findByAreaTypeInAndStatusOrderByCodeAsc`
  - `findByParent_CodeAndStatusOrderByCodeAsc`
  - `searchByNormalizedNameWithParent`
- **Service:** `AdministrativeAreaServiceImpl` caching provinces, children, and code lookups with Caffeine.
- **Controller:** `AdministrativeAreaController` exposing:
  - `GET /api/administrative-areas/provinces`
  - `GET /api/administrative-areas/{code}/children`
  - `GET /api/administrative-areas/search?q={query}&limit={limit}`
  - `GET /api/administrative-areas/{code}`
- **Security:** Public read access configured in `SecurityConfig.java` (`.requestMatchers(HttpMethod.GET, "/api/administrative-areas/**").permitAll()`).
- **Defect/Gap Identified:**
  - `AdministrativeAreaRepository.searchByNormalizedNameWithParent` and `findByParent_CodeAndStatusOrderByCodeAsc` do not filter out `trust_classification = 'UNVERIFIED_AND_QUARANTINED'`. The 12 quarantined Northern Bắc Ninh wards (`07294..09496`) could inadvertently be surfaced if queried by name or under parent code `24`.

### 2.2 Place Subsystem
- **Entity:** `Place` (table `places`). Fields: `place_id`, `name`, `normalized_name`, `address`, `category`, `status`, `latitude`, `longitude`, `administrative_area_id`.
- **Repository:** `PlaceRepository` with methods:
  - `searchPlaces(@Param("keyword") String keyword, @Param("normKeyword") String normKeyword, @Param("category") PlaceCategory category, ...)`
  - `findInBoundingBox(@Param("minLat") BigDecimal minLat, @Param("maxLat") BigDecimal maxLat, ...)`
  - `findByAdministrativeArea_AreaId(Long areaId)`
  - `findByAdministrativeArea_Code(String code)`
  - `findByAdministrativeArea_Parent_Code(String parentCode)`
- **Service:** `PlaceServiceImpl` supporting keyword search and radius-based bounding box filtering (`searchByRadius`).
- **Controller:** `PlaceController` exposing `GET /api/places` and `GET /api/places/{id}`.
- **Defect/Gap Identified:**
  - `GET /api/places` accepts `keyword`, `category`, `latitude`, `longitude`, `radiusKm`, but **lacks parameters for administrative area filtering** (`administrativeAreaCode`, `administrativeAreaId`, or `provinceCode`).
  - No hierarchy expansion: selecting a province should return places linked to that province OR linked to any of its child communes/wards.

### 2.3 Location Search & External Geocoding
- **Service:** `LocationServiceImpl` orchestrating `QueryUnderstandingService`, `GeographicFilterService`, `LocationRankingService`, and providers (`LocationIqGeocodingProvider`, `HereGeocodingProvider`, `TomTomPlacesProvider`).
- **Controller:** `LocationController` exposing `GET /api/locations/search`, `GET /api/locations/nearby`, `GET /api/locations/reverse-geocode`.
- **Defect/Gap Identified:**
  - `LocationServiceImpl` currently **only queries external third-party providers**. It does not query internal canonical `PlaceRepository` or `AdministrativeAreaRepository`.
  - When a user searches for an existing landmark (e.g. "Bà Nà Hills", "Hồ Hoàn Kiếm", "Văn Miếu") in Location Picker, internal canonical places with verified coordinates are bypassed in favor of remote geocoding calls.

---

## 3. Database Architecture & Indexing Audit

### 3.1 Schema Inspection (MySQL 8.0.37 `travel_planner`)
- **Table `administrative_areas`:**
  - Primary Key: `area_id` (`bigint`)
  - Unique Key: `uk_admin_areas_code` (`code`)
  - Indexes: `idx_admin_areas_parent_id`, `idx_admin_areas_normalized_name`, `idx_admin_areas_type_status`, `idx_admin_areas_trust_class`.
  - Hierarchy: Self-referencing FK `parent_id` -> `administrative_areas(area_id)`.
- **Table `places`:**
  - Primary Key: `place_id` (`bigint`)
  - Coordinates: `latitude` (`decimal(10,7)`), `longitude` (`decimal(10,7)`).
  - Foreign Key: `fk_places_admin_area` (`administrative_area_id` -> `administrative_areas.area_id`).
  - Indexes: `idx_places_coords` (`latitude`, `longitude`), `idx_places_admin_area`, `idx_places_normalized_name`, `idx_places_category`, `idx_places_status`.
- **Spatial Index Assessment:**
  - B-tree composite index `idx_places_coords` on `(latitude, longitude)` is active and verified.
  - Queries utilizing bounding box constraints (`latitude BETWEEN :minLat AND :maxLat AND longitude BETWEEN :minLon AND :maxLon`) perform indexed range scans with sub-millisecond latency.
  - **Decision:** No MySQL Spatial extensions (SPATIAL INDEX / GIS POINT geometry) or schema migrations are needed. The existing B-tree coordinates and Haversine distance calculations meet all performance and accuracy requirements.

---

## 4. Frontend Mobile & Web Audit

### 4.1 Flutter Mobile
- **Explore:** `ExploreScreen` and `FilterBottomSheet` currently filter itineraries by keyword, location text, theme, budget, days, and rating.
- **Location Picker:** `LocationPickerSheet` invokes `LocationRepository.searchLocations` -> hits `GET /api/locations/search`.
- **Activity Create/Edit:** Utilizes `LocationPickerSheet` to obtain `CustomLocationResult` and stores authoritative snapshot coordinates in `Activity`.
- **Integration Plan:**
  - Enhance `LocationPickerSheet` and Explore with administrative area discovery and hierarchy navigation.
  - Ensure canonical Places returned by the backend appear at the top of the search results with a distinct badge.

### 4.2 Flutter Web
- `AdminPlacesScreen` provides admin place curation (listing, create, edit, toggle visibility) consuming `/api/admin/places`.
- Web admin is already functional and unaffected by public search enhancements.

---

## 5. Reusable Components & Required Modifications

| Component | Current State | Required Modification for Phase 3.3 |
| :--- | :--- | :--- |
| `AdministrativeAreaRepository` | Queries all active areas | Add query condition to strictly exclude `trust_classification = 'UNVERIFIED_AND_QUARANTINED'` from public search and child listings. |
| `AdministrativeAreaController` | Basic provinces, children, search | Add endpoint `GET /{code}/places` to retrieve places in an administrative area (including descendant communes/wards). |
| `PlaceRepository` | Search keyword and bounding box | Add composite query supporting `administrativeAreaId` / `provinceCode` hierarchy filtering combined with keyword and category. |
| `PlaceService` & `PlaceController` | Search with radius | Support `administrativeAreaCode` / `administrativeAreaId` query parameter in `GET /api/places`. |
| `LocationServiceImpl` | Only calls external providers | Implement internal search first: search canonical `places` and non-quarantined `administrative_areas`, prioritizing them before falling back to external providers. |
| Mobile `LocationPickerSheet` | Search input calls `/api/locations/search` | Automatically benefits from internal Place priority. Add administrative area browse / quick-filter chips. |
| Mobile `ExploreScreen` | Text filter for location | Support administrative area selection and place filtering. |

---

## 6. Non-Negotiable Invariant Safeguards

1. **Quarantine Isolation:** The 12 northern Bắc Ninh codes (`07294..09496`) must never be returned in public administrative search, child listings, or autocomplete.
2. **Ambiguous Places:** Places 11, 12, 20, and 22 remain `NULL` and must never be attributed to any administrative area during search or spatial filtering.
3. **Activity Immutability:** No schema changes or FK additions to `activities`.

