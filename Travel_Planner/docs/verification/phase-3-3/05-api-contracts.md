# Phase 3.3 — Artifact 05: Public & Administrative API Contracts

## 1. Overview & Architectural Principles

All endpoints in Phase 3.3 adhere to standard Spring Boot REST conventions:
- Public discovery endpoints are open (`permitAll()`).
- Invariant: Quarantined units (`UNVERIFIED_AND_QUARANTINED`) are strictly excluded.
- DTOs strictly decouple database entities from HTTP responses.
- All endpoints support pagination and stable sorting where applicable.

---

## 2. API Contract Specifications

### 2.1 `GET /api/administrative-areas/provinces`
- **Method:** `GET`
- **Description:** Returns all 34 official provincial units (provinces and centrally governed cities).
- **Authentication:** Public (No token required).
- **Response:** `200 OK` — `List<AdministrativeAreaResponse>`

### 2.2 `GET /api/administrative-areas/{code}/children`
- **Method:** `GET`
- **Path Parameter:** `code` (`String`): Parent province code (e.g. `"01"`, `"79"`, `"24"`).
- **Description:** Returns non-quarantined child units (communes/wards/special zones) of the province.
- **Response:** `200 OK` — `List<AdministrativeAreaResponse>`
- **Errors:** `400 Bad Request` (blank code), `404 Not Found` (parent code not found).

### 2.3 `GET /api/administrative-areas/search`
- **Method:** `GET`
- **Query Parameters:**
  - `q` (`String`, required): Search keyword (accented or unaccented, e.g. `"Long Xuyen"`, `"Hoàn Kiếm"`, or exact code `"00070"`).
  - `limit` (`int`, optional, default: 10, max: 50).
- **Response:** `200 OK` — `List<AdministrativeAreaSearchResultResponse>`
- **Quarantine Invariant:** Units `07294..09496` are never returned.

### 2.4 `GET /api/places`
- **Method:** `GET`
- **Query Parameters:**
  - `keyword` (`String`, optional): Search text matching name or address.
  - `category` (`PlaceCategory`, optional): `ATTRACTION`, `RESTAURANT`, `CAFE`, `HOTEL`, etc.
  - `administrativeAreaCode` (`String`, optional): Filter places belonging to this administrative code (or its child communes if province).
  - `administrativeAreaId` (`Long`, optional): Filter by area ID.
  - `latitude` (`Double`, optional): Center latitude for radius search.
  - `longitude` (`Double`, optional): Center longitude for radius search.
  - `radiusKm` (`Double`, optional): Search radius in kilometers.
  - `page` (`int`, optional, default: 0).
  - `size` (`int`, optional, default: 10).
  - `sort` (`String`, optional, default: `"name,asc"`).
- **Response:** `200 OK` — `Page<PlaceResponse>`

### 2.5 `GET /api/administrative-areas/{code}/places`
- **Method:** `GET`
- **Path Parameter:** `code` (`String`): Administrative area code.
- **Query Parameters:** `keyword`, `category`, `page`, `size`, `sort`.
- **Description:** Returns all Places within the given administrative area (including child units if `code` is a province).
- **Response:** `200 OK` — `Page<PlaceResponse>`

### 2.6 `GET /api/locations/search`
- **Method:** `GET`
- **Query Parameters:** `query` / `q`, `limit`, `mode` (`SUGGEST` or `SEARCH`), `sessionId`.
- **Search Priority:**
  1. Internal canonical Places (`provider = "SYSTEM"`).
  2. Non-quarantined administrative areas (`type = "administrative"`).
  3. External provider fallback (LocationIQ / HERE / TomTom).
- **Response:** `200 OK` — `List<LocationSearchResultResponse>`

