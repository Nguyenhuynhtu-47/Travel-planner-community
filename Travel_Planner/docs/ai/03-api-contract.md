
# API Contract Guidelines

## 1. General
- Backend: Spring Boot REST API.
- Data exchange: JSON over HTTP/HTTPS.
- Both Flutter Mobile and Flutter Web use the same API.
- Follow existing endpoint and response conventions.
- Inspect current controllers and DTOs before adding APIs.

## 2. HTTP Methods
- GET: retrieve resources.
- POST: create resources or perform defined actions.
- PUT: replace a resource when appropriate.
- PATCH: partially update a resource.
- DELETE: delete a resource when permitted.

Use methods consistently with existing API conventions.

## 3. Endpoint Design
- Use resource-oriented and predictable URLs.
- Use plural resource names where appropriate.
- Keep route naming consistent.
- Do not duplicate endpoints for mobile and web.
- Document query parameters and request bodies.

## 4. Request and Response
For each endpoint, document:
- HTTP method and path.
- Authentication requirement.
- Required role or permissions.
- Path and query parameters.
- Request body.
- Success status and response schema.
- Possible error responses.
- Validation rules.

Use actual DTOs and implementation as the source of truth.

## 5. Error Handling
### Target Standard Error Response
All error responses from the Spring Boot API must adhere to a centralized JSON schema to be handled by `@RestControllerAdvice` in `Travel_Planner.Travel_Planner.exception`.

> **Note on Implementation Status**: This is the agreed target standard for all endpoints. In the current codebase, `Travel_Planner.Travel_Planner.exception/` only contains `.gitkeep`; `@RestControllerAdvice` has not yet been implemented in code.

```json
{
  "timestamp": "2026-10-17T01:30:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Dữ liệu gửi lên không hợp lệ",
  "path": "/api/itineraries",
  "validationErrors": {
    "title": "Tiêu đề lịch trình không được để trống",
    "budget": "Ngân sách dự kiến phải lớn hơn hoặc bằng 0"
  }
}
```

### Field Definitions and Data Types
| Field | Data Type | Required | Description |
|---|---|---|---|
| `timestamp` | String (ISO-8601) | Yes | Server time when the error occurred (e.g., `2026-10-17T01:30:00Z`). |
| `status` | Integer | Yes | HTTP status code matching the response header (e.g., 400, 401, 403, 404, 409, 500). |
| `error` | String | Yes | Standard HTTP reason phrase (e.g., `"Bad Request"`, `"Unauthorized"`, `"Forbidden"`). |
| `message` | String | Yes | Human-readable description safe to display to the user. Never leak database stack traces or SQL syntax. |
| `path` | String | Yes | The request URI path that produced the error. |
| `validationErrors` | Object (`Map<String, String>`) | Optional | Field-by-field validation error messages. Present only for input validation failures (HTTP 400). |

### Frontend Error Handling Flow
- **HTTP 400 (Bad Request)**:
  - If `validationErrors` is present, the frontend client maps field keys (`title`, `budget`) directly to inline form field error messages.
  - If `validationErrors` is absent, display `message` in a top banner or snackbar.
- **HTTP 401 (Unauthorized)**:
  - Auth token is missing, expired, or invalid.
  - Clear stored tokens from client storage and redirect the user to the Login screen with an optional redirect path.
- **HTTP 403 (Forbidden)**:
  - User is authenticated but lacks required role or is attempting to modify a resource owned by another user.
  - Display an access-denied state without navigating away.
- **HTTP 404 (Not Found)**:
  - The requested resource ID does not exist or was deleted.
  - Display a clean not-found empty/error state.
- **HTTP 409 (Conflict)**:
  - Business constraint conflict (e.g., duplicate username, email already registered, duplicate itinerary rating).
  - Display the specific conflict `message` to prompt user resolution.
- **HTTP 500 (Internal Server Error)**:
  - Unexpected server crash. Technical details are logged on the server.
  - Frontend displays a friendly fallback: *"Hệ thống gặp sự cố tạm thời. Vui lòng thử lại sau."*

## 6. Authentication and Authorization
- **Current Codebase Status**:
  - `SecurityConfig.java` currently configures stateless session management and allows all requests (`permitAll()`).
  - Neither JWT filter, UserDetailsService, nor token issuance logic is implemented yet.
  - Do not treat JWT authentication as already functional in the codebase.
- **Confirmed Authentication Architecture**:
  - **JWT Bearer Token** transmitted via HTTP header `Authorization: Bearer <token>` is the confirmed authentication method for the shared REST API serving Flutter Mobile and Flutter Web.
- **Decisions Pending Project Owner Confirmation**:
  - Access token lifespan and whether a refresh token flow (rotation, storage) will be used.
  - Token revocation and logout strategy (blacklisting tokens, database token tracking, or relying purely on short token lifespans).
  - Client token storage mechanisms on Web and Mobile.
  - CORS configuration in Spring Security allowing development origins `http://localhost:8081` and `http://127.0.0.1:8081` (production configured separately).

## 7. Pagination, Filtering and Sorting
Pagination is applied to collection endpoints that return open-ended lists (e.g., public itinerary search, reviews, comments, admin user lists). Pagination is **not** mandatory for bounded collections (e.g., activities within a single day).

### Query Parameters
| Parameter | Type | Default | Constraint / Behavior |
|---|---|---|---|
| `page` | Integer | `0` | 0-indexed page number. If `< 0`, server normalizes to `0` or responds with HTTP 400. |
| `size` | Integer | `10` | Items per page. Maximum allowed: `50`. If `> 50`, server caps to `50`; if `<= 0`, server defaults to `10`. |
| `sort` | String | `createdAt,desc` | Format: `fieldName,asc` or `fieldName,desc`. If invalid field name is passed, server falls back to default sorting or returns HTTP 400. |

### Standard Paginated JSON Response Wrapper
```json
{
  "content": [],
  "pageNumber": 0,
  "pageSize": 10,
  "totalElements": 42,
  "totalPages": 5,
  "last": false
}
```

## 8. API Change Process
1. Inspect the existing controller and DTO.
2. Define the required contract with request/response schemas.
3. Implement backend validation, transactions, and business rules.
4. Update the Flutter API client and data models.
5. Handle success, loading, empty, and failure states in UI.
6. Test the endpoint and affected screens with automated tests.
7. Update API documentation.

## 9. Endpoint Inventory
Current inventory of API endpoints:

| Module | Method | Endpoint | Auth Level | Purpose | Status |
|---|---|---|---|---|---|
| System | GET | `/api/health` | Public | Service health check | **Implemented** |
| Auth | POST | `/api/auth/register` | Public | Register new account | Implemented |
| Auth | POST | `/api/auth/login` | Public | Log in and receive JWT token | Implemented |
| Profile | GET | `/api/user/profile` | Authenticated | Fetch current user profile | Implemented |
| Profile | PUT | `/api/user/profile` | Authenticated | Update current user's full name, avatar URL, phone, address and bio | Implemented |
| Itinerary | GET | `/api/itineraries` | Public | Search & list public itineraries | Planned |
| Itinerary | POST | `/api/itineraries` | Authenticated | Create a new travel itinerary | Planned |
| Itinerary | GET | `/api/itineraries/{id}` | Public/Auth | Get itinerary details | Planned |
| Itinerary | PUT | `/api/itineraries/{id}` | Owner | Update owned itinerary | Planned |
| Itinerary | DELETE| `/api/itineraries/{id}` | Owner/Admin | Soft delete or delete itinerary | Planned |
| Reuse | POST | `/api/itineraries/{id}/reuse` | Authenticated | Clone itinerary as personal copy | Planned |
| Reviews | GET | `/api/itineraries/{id}/ratings` | Public | List ratings and feedback | Planned |
| Reviews | POST | `/api/itineraries/{id}/ratings` | Authenticated | Submit itinerary rating | Planned |
| Comments | GET | `/api/itineraries/{id}/comments` | Public | List comments on itinerary | Planned |
| Comments | POST | `/api/itineraries/{id}/comments` | Authenticated | Post comment on itinerary | Planned |
| Admin | GET | `/api/admin/dashboard` | Admin | Administrative metrics dashboard | Planned |
| Admin | GET | `/api/admin/users` | Admin | List and manage users | Planned |
| Admin | PUT | `/api/admin/moderation` | Admin | Moderate reported content/trips | Planned |

Profile request body for `PUT /api/user/profile` (authenticated):

```json
{
  "fullName": "Nguyen Van A",
  "avatar": "https://example.com/avatar.jpg",
  "phone": "0900000000",
  "address": "Da Nang",
  "bio": "Travel enthusiast"
}
```

`fullName` is required (maximum 100 characters). The other fields are optional; omitted or blank values are cleared. `avatar`, `phone` and `address` have maximum lengths of 500, 20 and 255 characters. The response uses the existing `UserResponse` fields and never includes the password. Both profile operations identify the account from the authenticated JWT; callers cannot select another user.

The health, authentication and profile endpoints are implemented. The remaining endpoints are planned specifications.
