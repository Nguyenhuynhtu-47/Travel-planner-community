# PHASE 4 — 02. ITINERARY PLACE REST API AUDIT
## Endpoint Definitions, Payloads, and Response Structures

**Project:** Travel Planner  
**Base Path:** `/api/itineraries/{itineraryId}/places`  

---

### 1. Endpoint Overview

| Method | Endpoint | Auth Required | Description | Status Codes |
|---|---|---|---|---|
| `POST` | `/api/itineraries/{itineraryId}/places` | Yes (Owner) | Save place to itinerary | 201 Created, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict |
| `GET` | `/api/itineraries/{itineraryId}/places` | No (Public) / Yes (Private Owner) | Paginated list of saved places | 200 OK, 403 Forbidden, 404 Not Found |
| `GET` | `/api/itineraries/{itineraryId}/places/all` | No (Public) / Yes (Private Owner) | Full list of saved places | 200 OK, 403 Forbidden, 404 Not Found |
| `DELETE`| `/api/itineraries/{itineraryId}/places/{placeId}` | Yes (Owner) | Remove place association | 200 OK, 401 Unauthorized, 403 Forbidden, 404 Not Found |

---

### 2. Payload and Response Contracts

#### 2.1 POST Save Place
- **Request Body:**
  ```json
  {
    "placeId": 101
  }
  ```
- **Response (201 Created):**
  ```json
  {
    "id": 1,
    "itineraryId": 42,
    "place": {
      "placeId": 101,
      "name": "Chợ Bến Thành",
      "address": "Đường Lê Lợi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh",
      "category": "SHOPPING",
      "latitude": 10.7725,
      "longitude": 106.6980,
      "status": "ACTIVE",
      "administrativeArea": {
        "areaId": 50,
        "code": "26740",
        "name": "Phường Bến Thành",
        "areaType": "WARD",
        "trustClassification": "VERIFIED_AND_TRUSTED"
      }
    },
    "savedAt": "2026-09-20T14:30:00"
  }
  ```

#### 2.2 GET Paginated Saved Places
- **Query Parameters:** `page` (default 0), `size` (default 20), `sort` (default `savedAt,desc`).
- **Response (200 OK):**
  ```json
  {
    "content": [
      {
        "id": 1,
        "itineraryId": 42,
        "place": { ... },
        "savedAt": "2026-09-20T14:30:00"
      }
    ],
    "pageNumber": 0,
    "pageSize": 20,
    "totalElements": 1,
    "totalPages": 1,
    "last": true
  }
  ```

#### 2.3 DELETE Remove Place Association
- **Path Parameter:** `placeId`
- **Response (200 OK):** Empty body.

