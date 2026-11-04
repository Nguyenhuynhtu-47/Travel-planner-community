# Backend Social Interaction Implementation Plan: Rating, Favorite, and Saved Itineraries

**Document Reference:** `plan/02-backend-social-interaction-plan.md`  
**Location:** `Travel_Planner/docs/plan/02-backend-social-interaction-plan.md`  
**Creation Date:** 2026-11-04  
**Last Updated:** 2026-11-04 (User Business Decisions Confirmed & Incorporated)  
**Author / Technical Lead:** Senior Software Architect, Technical Lead & Project Auditor  
**Scope:** Backend Only (Spring Boot 4.1.1, Spring Security, Spring Data JPA, MySQL 8)  
**Status:** Approved for Implementation (Awaiting Final Go-Ahead)  
**Parent Roadmap Tasks:** P2-R1, P2-F1, P2-SA1 (defined in [`12-project-status-and-next-steps.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/12-project-status-and-next-steps.md))  

---

## 1. Project Context & Current Status

### 1.1 Project Overview
**Travel Planner** is a community-driven travel planning and sharing platform built on a 3-tier architecture:
- **Backend:** Spring Boot 4.1.1 (Java 22), Spring Security, Spring Data JPA, MySQL 8.
- **Mobile Client:** Flutter (Dart 3.13.5, Flutter 3.47.7, Material 3).
- **Web Admin Portal:** Flutter Web.
- **Communication:** RESTful JSON API with stateless JWT Bearer token authentication.

### 1.2 Current Implementation State (Audited 2026-11-04)
A comprehensive audit conducted on 2026-11-04 confirmed that **501 / 501 automated tests are passing (100% green)** across the repository:
- **Backend:** 157 / 157 passing (`mvnw.cmd test` in 44.8s).
- **Mobile:** 305 / 305 passing (`flutter test` in 43.0s).
- **Web:** 39 / 39 passing (`flutter test` in 14.0s).

The core engine is complete and verified:
- JWT Authentication & RBAC (`/api/auth/*`).
- User Profile Management (`/api/user/profile`).
- Multi-criteria Explore, Search & Recommendations (`/api/itineraries`, `/api/itineraries/recommendations`).
- Full Itinerary & Day & Activity CRUD with two-pass display reordering (`/api/itineraries/*`).
- Destination Catalog & Admin CRUD (`/api/destinations`, `/api/admin/destinations`).
- Decoupled Free-First Map & Routing Stack (CARTO Basemaps, LocationIQ geocoding, OpenRouteService routing with Haversine fallback, co-location radial jittering).
- SHA-1 Signed Image Upload via Cloudinary (`/api/media/images`).
- Paginated Comments (`/api/itineraries/{id}/comments`).

### 1.3 The Specific Problem
Although the database tables and JPA entities for social interactions were created early in the project lifecycle:
1. **`Rating.java` & `RatingRepository.java`** exist in code, but there is **no `RatingController` or `RatingService`**. Users cannot rate or view their own rating.
2. **`Favorite.java` & `FavoriteRepository.java`** exist in code, but there is **no `FavoriteController` or `FavoriteService`**. Users cannot like/favorite itineraries.
3. **`SavedItinerary.java` & `SavedItineraryRepository.java`** exist in code, but there is **no `SavedItineraryController` or `SavedItineraryService`**. The Mobile app's "Đã Lưu" tab (`SavedItinerariesScreen`) is currently a dead-end placeholder (`AppEmptyState`).
4. **Counter Drift Risk:** In `Itinerary.java`, `ratingCount` and `favoriteCount` are populated only during initial seed data execution (`DataSeeder.java`). There is no operational API to increment, decrement, or synchronize these counters upon live user interactions.
5. **Contextual State Missing:** `GET /api/itineraries/{id}` returns `ItineraryDetailResponse` with aggregate counts, but **does not return whether the authenticated user has favorited, saved, or rated the itinerary**, requiring clients to either guess or make multiple speculative requests.

---

## 2. Objectives & Scope

### 2.1 Objectives
1. **Rating API:** Provide secure, authenticated endpoints for rating itineraries (1 to 5 stars), retrieving the current user's rating, retrieving public aggregate rating summaries, updating existing ratings (idempotent upsert), and deleting ratings.
2. **Favorite API:** Provide idempotent endpoints to favorite (like) and unfavorite public itineraries, maintaining `favoriteCount` with concurrency-safe atomic database increments/decrements. Allow users to query their favorited itineraries.
3. **Saved Itinerary API:** Provide unified, non-redundant endpoints to bookmark (save) and remove bookmarks from public itineraries, and retrieve a paginated collection of saved itineraries for the authenticated user (`GET /api/user/saved-itineraries`).
4. **Contextual Enrichment:** Enrich `ItineraryDetailResponse` with `isFavorited`, `isSaved`, and `userRating` (nullable) when accessed by an authenticated user.
5. **Data Integrity & Concurrency:** Guarantee that each user has **at most one** rating, **at most one** favorite, and **at most one** saved record per itinerary, even under concurrent duplicate requests.
6. **Access Control & Silent Filtering:** Enforce strict visibility checks: users cannot rate or favorite `PRIVATE`, `DELETED`, or non-`ACTIVE` itineraries. The saved itineraries list silently filters out itineraries that are not active and public, while preserving the underlying saved bookmark.

### 2.2 Scope
- **IN SCOPE:**
  - Backend Spring Boot controllers, services, repositories, DTOs, security matchers, and validation annotations.
  - Concurrency control via database unique constraints and atomic counter synchronization for `favoriteCount` and `ratingCount`.
  - Dynamic average rating calculation via database aggregation (`AVG(r.score)`).
  - Integration and unit tests targeting 100% pass rate with zero regression on existing 157 tests.
- **EXPLICITLY OUT OF SCOPE:**
  - Mobile Flutter UI implementation (covered in follow-up tasks P2-R2, P2-F2, P2-SA2).
  - Web Admin UI moderation screens (covered in Phase 4).
  - Itinerary Clone / Personalize API (covered in Phase 3 task P3-C1).
  - User-to-user Follow / Social Graph API (`Follow.java`).
  - Push / In-App Notifications.

---

## 3. Existing Architecture Analysis

### 3.1 Layer Responsibilities & Patterns
The codebase follows a strictly decoupled, layered architecture:

```
[ HTTP Requests / JSON ]
         │
         ▼
[ Security & Filter Layer ] ──► JwtAuthenticationFilter (Extracts username from Bearer token)
         │
         ▼
[ Controller Layer ] ─────────► REST Controllers (Validates DTOs, extracts UserDetails, handles HTTP codes)
         │
         ▼
[ Service Layer ] ────────────► Service Interfaces + Implementations (@Transactional, Business Rules)
         │
         ▼
[ Repository Layer ] ─────────► Spring Data JPA Interfaces (Derived queries, @Query JPQL, @Modifying)
         │
         ▼
[ Database Layer ] ───────────► MySQL 8 InnoDB (Unique constraints, Foreign keys, Auto-increment IDs)
```

### 3.2 Existing Relevant Artifacts

| Component | File Path | Existing State | Plan Action |
|:---|:---|:---|:---|
| **Rating Entity** | `backend/.../model/Rating.java` | Complete (PK `ratingId`, FK `user`, FK `itinerary`, `score`, timestamps, unique constraint `uk_rating_user_itinerary`) | **Reuse as-is** |
| **Favorite Entity** | `backend/.../model/Favorite.java` | Complete (PK `favoriteId`, FK `user`, FK `itinerary`, `createdAt`, unique constraint `uk_favorite_user_itinerary`) | **Reuse as-is** |
| **SavedItinerary Entity** | `backend/.../model/SavedItinerary.java` | Complete (PK `saveId`, FK `user`, FK `itinerary`, `createdAt`, unique constraint `uk_saved_user_itinerary`) | **Reuse as-is** |
| **Itinerary Entity** | `backend/.../model/Itinerary.java` | Complete (`ratingCount`, `favoriteCount`, `commentCount`, `viewCount`, `reuseCount`) | **Reuse as-is** |
| **Rating Repository** | `backend/.../repository/RatingRepository.java` | Has `findAverageRatingsByItineraryIds`, `existsByUser_UserIdAndItinerary_ItineraryId` | **Extend** with user lookup and single itinerary average query |
| **Favorite Repository** | `backend/.../repository/FavoriteRepository.java` | Has `findByUser_UserIdAndItinerary_ItineraryId`, `existsBy...`, `findByUser_UserIdOrderByCreatedAtDesc`, `countBy...` | **Extend** with paginated query `Page<Favorite> findByUser_UserId(...)` |
| **SavedItinerary Repository** | `backend/.../repository/SavedItineraryRepository.java` | Has `findByUser_UserIdAndItinerary_ItineraryId`, `existsBy...`, `findByUser_UserIdOrderByCreatedAtDesc`, `countBy...` | **Extend** with filtered paginated saved query |
| **Itinerary Repository** | `backend/.../repository/ItineraryRepository.java` | Has `@Modifying incrementCommentCount` | **Extend** with atomic `incrementFavoriteCount`, `decrementFavoriteCount`, `incrementRatingCount`, `decrementRatingCount` |
| **Global Exception Handler**| `backend/.../exception/GlobalExceptionHandler.java` | Handles `AppException`, `MethodArgumentNotValidException`, `AccessDeniedException` | **Reuse as-is** |
| **Security Config** | `backend/.../security/SecurityConfig.java` | Whitelists public GET endpoints; `.anyRequest().authenticated()` | **Update** to whitelist public GET rating aggregates |

---

## 4. Database Design & Required Changes

### 4.1 Schema Inspection (MySQL 8 InnoDB)

#### Table `ratings`:
```sql
CREATE TABLE ratings (
    rating_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    itinerary_id INT NOT NULL,
    score INT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT uk_rating_user_itinerary UNIQUE (user_id, itinerary_id),
    CONSTRAINT fk_rating_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_rating_itinerary FOREIGN KEY (itinerary_id) REFERENCES itineraries(itinerary_id) ON DELETE CASCADE
);
```

#### Table `favorites`:
```sql
CREATE TABLE favorites (
    favorite_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    itinerary_id INT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT uk_favorite_user_itinerary UNIQUE (user_id, itinerary_id),
    CONSTRAINT fk_favorite_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_favorite_itinerary FOREIGN KEY (itinerary_id) REFERENCES itineraries(itinerary_id) ON DELETE CASCADE
);
```

#### Table `saved_itineraries`:
```sql
CREATE TABLE saved_itineraries (
    save_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    itinerary_id INT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT uk_saved_user_itinerary UNIQUE (user_id, itinerary_id),
    CONSTRAINT fk_saved_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_saved_itinerary FOREIGN KEY (itinerary_id) REFERENCES itineraries(itinerary_id) ON DELETE CASCADE
);
```

### 4.2 Database Verification & Consistency
- **Schema Modification:** **NONE.** The existing database tables already possess all necessary columns, data types, and foreign key constraints.
- **Unique Constraint Verification:** The composite unique constraints:
  - `uk_rating_user_itinerary` on `ratings(user_id, itinerary_id)`
  - `uk_favorite_user_itinerary` on `favorites(user_id, itinerary_id)`
  - `uk_saved_user_itinerary` on `saved_itineraries(user_id, itinerary_id)`  
  are verified to exist in both Java entity mappings (`@UniqueConstraint`) and MySQL DDL. These guarantee that no user can have duplicate social interaction records for the same itinerary under any circumstances.
- **Dynamic Calculation of Average Rating:** In strict accordance with the audited architecture, `averageRating` is **NOT stored as a column on `itineraries`**. It is calculated dynamically via SQL `AVG(score)`. This prevents rounding errors, floating-point drift, and cache desynchronization across concurrent rating changes.

---

## 5. API Specification

All endpoints return JSON responses adhering to the established schema and HTTP status conventions.

### 5.1 Rating API (`/api/itineraries/{itineraryId}/ratings`)

#### 1. Submit or Update Rating (Upsert)
- **Method & Endpoint:** `POST /api/itineraries/{itineraryId}/ratings`
- **Permission:** Authenticated User (`ROLE_USER` or `ROLE_ADMIN`).
- **Path Parameters:**
  - `itineraryId` (Integer, required): ID of the itinerary.
- **Request Body:**
  ```json
  {
    "score": 5
  }
  ```
- **Validation Rules:**
  - `score`: `@NotNull(message = "Điểm đánh giá không được để trống")`, `@Min(value = 1, message = "Điểm đánh giá tối thiểu là 1 sao")`, `@Max(value = 5, message = "Điểm đánh giá tối đa là 5 sao")`.
- **Business Behavior:**
  - **Self-Rating Check:** If `itinerary.user.userId == currentUser.userId`, reject with `400 Bad Request` (`"Bạn không thể tự đánh giá lịch trình của chính mình"`).
  - If user has NOT rated before: Insert new `Rating`, atomically increment `itinerary.ratingCount` (+1). Returns `201 Created`.
  - If user HAS rated before: Update existing `Rating.score`, update `Rating.updatedAt`, DO NOT alter `itinerary.ratingCount`. Returns `200 OK`.
- **Response Body (`RatingResponse`):**
  ```json
  {
    "ratingId": 42,
    "itineraryId": 1,
    "score": 5,
    "averageRating": 4.8,
    "ratingCount": 15,
    "createdAt": "2026-11-04T10:15:30",
    "updatedAt": "2026-11-04T10:15:30"
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Self-rating attempted or score out of bounds (1–5).
  - `401 Unauthorized`: Token missing or expired.
  - `403 Forbidden`: User account is BANNED or INACTIVE.
  - `404 Not Found`: Itinerary not found, or is PRIVATE / DELETED / author banned.

#### 2. Get Current User's Rating for Itinerary
- **Method & Endpoint:** `GET /api/itineraries/{itineraryId}/ratings/me`
- **Permission:** Authenticated User.
- **Path Parameters:** `itineraryId` (Integer, required).
- **Response Body (`UserRatingStatusResponse`):**
  - If user rated:
    ```json
    {
      "itineraryId": 1,
      "rated": true,
      "score": 5,
      "ratingId": 42,
      "updatedAt": "2026-11-04T10:15:30"
    }
    ```
  - If user has not rated:
    ```json
    {
      "itineraryId": 1,
      "rated": false,
      "score": null,
      "ratingId": null,
      "updatedAt": null
    }
    ```

#### 3. Get Public Rating Summary Breakdown
- **Method & Endpoint:** `GET /api/itineraries/{itineraryId}/ratings`
- **Permission:** Public (`permitAll`).
- **Response Body (`RatingSummaryResponse`):**
  ```json
  {
    "itineraryId": 1,
    "averageRating": 4.67,
    "ratingCount": 15,
    "starCounts": {
      "5": 10,
      "4": 3,
      "3": 1,
      "2": 1,
      "1": 0
    }
  }
  ```

#### 4. Delete Own Rating
- **Method & Endpoint:** `DELETE /api/itineraries/{itineraryId}/ratings`
- **Permission:** Authenticated User.
- **Business Behavior:** Deletes user's `Rating` record, atomically decrements `itinerary.ratingCount` (-1, guarded at 0).
- **Response Body:** `200 OK`
  ```json
  {
    "message": "Đã xóa đánh giá thành công",
    "itineraryId": 1,
    "averageRating": 4.64,
    "ratingCount": 14
  }
  ```
- **Error Responses:**
  - `404 Not Found`: User has not rated this itinerary, or itinerary not found.

---

### 5.2 Favorite API (`/api/itineraries/{itineraryId}/favorites` & `/api/user/favorites`)

#### 1. Add Favorite (Like)
- **Method & Endpoint:** `POST /api/itineraries/{itineraryId}/favorites`
- **Permission:** Authenticated User.
- **Business Behavior:**
  - **Self-Favorite Check:** If `itinerary.user.userId == currentUser.userId`, reject with `400 Bad Request` (`"Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"`).
  - Idempotent. If already favorited, returns current state with `200 OK`. If newly favorited, creates `Favorite`, atomically increments `itinerary.favoriteCount` (+1), returns `201 Created`.
- **Response Body (`FavoriteResponse`):**
  ```json
  {
    "itineraryId": 1,
    "favorited": true,
    "favoriteCount": 24
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Self-favorite attempted.
  - `404 Not Found`: Itinerary not found, private, or deleted.

#### 2. Remove Favorite (Unlike)
- **Method & Endpoint:** `DELETE /api/itineraries/{itineraryId}/favorites`
- **Permission:** Authenticated User.
- **Business Behavior:** Idempotent. If record exists, deletes `Favorite` and atomically decrements `itinerary.favoriteCount` (-1, guarded at 0). Returns `200 OK`.
- **Response Body (`FavoriteResponse`):**
  ```json
  {
    "itineraryId": 1,
    "favorited": false,
    "favoriteCount": 23
  }
  ```

#### 3. Check Favorite Status
- **Method & Endpoint:** `GET /api/itineraries/{itineraryId}/favorites/status`
- **Permission:** Authenticated User.
- **Response Body (`FavoriteResponse`):**
  ```json
  {
    "itineraryId": 1,
    "favorited": true,
    "favoriteCount": 24
  }
  ```

#### 4. List User's Favorited Itineraries
- **Method & Endpoint:** `GET /api/user/favorites`
- **Permission:** Authenticated User.
- **Query Parameters:**
  - `page` (int, optional, default `0`).
  - `size` (int, optional, default `10`, max `50`).
- **Response Body:** `PageResponse<ItinerarySummaryResponse>` (silently filters out itineraries that are deleted, hidden, or private).

---

### 5.3 Saved Itinerary API (3 Dedicated Endpoints)

In accordance with user confirmation, the Saved Itinerary functionality is exposed via exactly **three dedicated, non-redundant endpoints**:

#### 1. Save Itinerary (Bookmark)
- **Method & Endpoint:** `POST /api/itineraries/{itineraryId}/save`
- **Permission:** Authenticated User.
- **Business Behavior:**
  - **Self-Save Policy:** Authors **ARE PERMITTED** to save their own itineraries. This allows users to bookmark their own flagship itineraries for quick access alongside community guides.
  - Idempotent. If already saved, returns `200 OK` with existing `saveId`. If newly saved, inserts into `saved_itineraries` and returns `201 Created`.
- **Response Body (`SavedItineraryResponse`):**
  ```json
  {
    "saveId": 18,
    "itineraryId": 1,
    "saved": true,
    "savedAt": "2026-11-04T10:20:00"
  }
  ```
- **Error Responses:**
  - `401 Unauthorized`: Token missing or expired.
  - `404 Not Found`: Itinerary not found, or is not public/active (unless author owns it).

#### 2. Remove Saved Itinerary (Unbookmark)
- **Method & Endpoint:** `DELETE /api/itineraries/{itineraryId}/save`
- **Permission:** Authenticated User.
- **Business Behavior:** Idempotent. Deletes `SavedItinerary` record if present. Returns `200 OK`.
- **Response Body (`SavedItineraryResponse`):**
  ```json
  {
    "saveId": null,
    "itineraryId": 1,
    "saved": false,
    "savedAt": null
  }
  ```

#### 3. Get User's Saved Itineraries (Mobile "Đã Lưu" tab)
- **Method & Endpoint:** `GET /api/user/saved-itineraries`
- **Permission:** Authenticated User.
- **Query Parameters:**
  - `page` (int, optional, default `0`).
  - `size` (int, optional, default `10`, max `50`).
- **Business Behavior (Silent Filter & Preservation):**
  - Only returns itineraries that are currently `status == ItineraryStatus.ACTIVE` AND `visibility == Visibility.PUBLIC`.
  - Itineraries that have been soft-deleted (`DELETED`), moderated/hidden (`HIDDEN`), or switched to `PRIVATE` are **silently omitted** from the returned list.
  - **Preservation Rule:** The underlying `SavedItinerary` record in database is **NEVER deleted** when a source itinerary becomes hidden or deleted. If the itinerary is later unhidden or restored to `ACTIVE + PUBLIC`, it immediately reappears in the user's saved list without requiring re-saving.
- **Response Body:** `PageResponse<ItinerarySummaryResponse>`  
  *(Maps saved itineraries ordered by bookmark creation timestamp `saved_itineraries.created_at DESC`)*.

---

### 5.4 Contextual Itinerary Detail Integration

#### Enriched `GET /api/itineraries/{id}` Response
When `GET /api/itineraries/{id}` is executed:
- If caller is **Anonymous/Guest**: `isFavorited = false`, `isSaved = false`, `userRating = null`.
- If caller is **Authenticated**:
  - `isFavorited = favoriteRepository.existsByUser_UserIdAndItinerary_ItineraryId(userId, id)`
  - `isSaved = savedItineraryRepository.existsByUser_UserIdAndItinerary_ItineraryId(userId, id)`
  - `userRating = ratingRepository.findByUser_UserIdAndItinerary_ItineraryId(userId, id).map(Rating::getScore).orElse(null)`

Enriched fields on `ItineraryDetailResponse`:
```json
{
  "itineraryId": 1,
  "title": "Hành trình di sản Hà Nội 3 ngày 2 đêm",
  ...
  "favoriteCount": 24,
  "ratingCount": 15,
  "commentCount": 8,
  "reuseCount": 3,
  "averageRating": 4.8,
  "isFavorited": true,
  "isSaved": false,
  "userRating": 5,
  "creator": { ... },
  "days": [ ... ]
}
```

---

## 6. Business Rules, Concurrency & Data Consistency

### 6.1 Validation Rules Matrix

| Field | Rule | Error Message (Vietnamese) |
|:---|:---|:---|
| `RatingRequest.score` | `@NotNull` | `"Điểm đánh giá không được để trống"` |
| `RatingRequest.score` | `@Min(1)` | `"Điểm đánh giá tối thiểu là 1 sao"` |
| `RatingRequest.score` | `@Max(5)` | `"Điểm đánh giá tối đa là 5 sao"` |
| `itineraryId` (Path) | `@NotNull`, positive integer | `"Mã lịch trình không hợp lệ"` |

### 6.2 Self-Interaction Policy (Confirmed)
1. **Self-Rating Prohibition:** Author CANNOT rate their own itinerary (`itinerary.getUser().getUserId().equals(currentUser.getUserId())`). Rejected with `HTTP 400 Bad Request`: `"Bạn không thể tự đánh giá lịch trình của chính mình"`.
2. **Self-Favorite Prohibition:** Author CANNOT favorite their own itinerary. Favorite count is a public metric of community appreciation; self-favoriting inflates recommendations. Rejected with `HTTP 400 Bad Request`: `"Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"`.
3. **Self-Saving Permitted:** Author **CAN** save their own itinerary. Users often want to pin their own itineraries in their saved collection for convenience. Allowed with `HTTP 201 Created` / `HTTP 200 OK`.

### 6.3 Itinerary Availability & Privacy Verification
Before rating or favoriting, the target itinerary must pass the unified validator:
```java
private Itinerary getPublicActiveItinerary(Integer itineraryId) {
    Itinerary itinerary = itineraryRepository.findById(itineraryId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình"));
    if (itinerary.getStatus() != ItineraryStatus.ACTIVE
            || itinerary.getVisibility() != Visibility.PUBLIC
            || itinerary.getUser().getStatus() != UserStatus.ACTIVE) {
        throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc không khả dụng");
    }
    return itinerary;
}
```
*Security Justification:* Returning `404 Not Found` (rather than `403 Forbidden`) when an itinerary is private or authored by a banned account prevents malicious users from probing for the existence of private itineraries via brute-force ID guessing.

### 6.4 Concurrency Control & Atomic Counter Synchronization
To prevent lost updates, race conditions, and counter drift under concurrent requests:

#### 1. Atomic JPQL Counter Queries
Counters `favoriteCount` and `ratingCount` on table `itineraries` MUST NOT be updated via Java in-memory increments (`setFavoriteCount(getFavoriteCount() + 1)`). They must use atomic database statements:
```java
@Modifying
@Query("update Itinerary i set i.favoriteCount = i.favoriteCount + 1 where i.itineraryId = :itineraryId")
int incrementFavoriteCount(@Param("itineraryId") Integer itineraryId);

@Modifying
@Query("update Itinerary i set i.favoriteCount = i.favoriteCount - 1 where i.itineraryId = :itineraryId and i.favoriteCount > 0")
int decrementFavoriteCount(@Param("itineraryId") Integer itineraryId);

@Modifying
@Query("update Itinerary i set i.ratingCount = i.ratingCount + 1 where i.itineraryId = :itineraryId")
int incrementRatingCount(@Param("itineraryId") Integer itineraryId);

@Modifying
@Query("update Itinerary i set i.ratingCount = i.ratingCount - 1 where i.itineraryId = :itineraryId and i.ratingCount > 0")
int decrementRatingCount(@Param("itineraryId") Integer itineraryId);
```

#### 2. Handling Concurrent Duplicate Requests
If a client sends two concurrent requests for the same user and itinerary:
- **Favorite Concurrency:**
  - Request 1 inserts row `(user_id, itinerary_id)`, executes `incrementFavoriteCount`, commits.
  - Request 2 attempts insertion, triggering MySQL `uk_favorite_user_itinerary` and throwing Spring's `DataIntegrityViolationException`.
  - Service catches `DataIntegrityViolationException`, queries the existing record, and returns `FavoriteResponse(favorited=true, favoriteCount)` without double-incrementing.
- **Rating Concurrency:**
  - Request 1 inserts row `(user_id, itinerary_id)`, executes `incrementRatingCount`, commits.
  - Request 2 catches `DataIntegrityViolationException` and falls back to update logic (updates `score`, does NOT increment counter).
- **Saved Itinerary Concurrency:**
  - Request 2 catches `DataIntegrityViolationException` and returns existing `SavedItineraryResponse(saved=true)`.

This guarantees **100% thread safety, zero counter drift, and absolute idempotency**.

---

## 7. Backend Implementation Phases

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Repository Extensions & Atomic Counter JPQL Queries│
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: DTOs & Validation Models                           │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Service Layer (Rating, Favorite, Saved Services)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: Controllers & Security Configuration               │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 5: Automated Integration Tests & Verification         │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1: Repository Layer Extensions & Atomic Counter Queries
- **Objective:** Add required query methods and atomic counter operations to Spring Data repositories without modifying any database tables.
- **Affected Files:**
  - `RatingRepository.java`
  - `FavoriteRepository.java`
  - `SavedItineraryRepository.java`
  - `ItineraryRepository.java`
- **Deliverables:**
  - `RatingRepository.findByUser_UserIdAndItinerary_ItineraryId(userId, itineraryId)`
  - `RatingRepository.findAverageRatingByItineraryId(itineraryId)`
  - `RatingRepository.countStarDistributionByItineraryId(itineraryId)`
  - `FavoriteRepository.findByUser_UserId(Integer userId, Pageable pageable)`
  - `SavedItineraryRepository.findActivePublicSavedItineraries(Integer userId, Pageable pageable)` (joins `itinerary` with status/visibility filter)
  - `ItineraryRepository`: `incrementFavoriteCount`, `decrementFavoriteCount`, `incrementRatingCount`, `decrementRatingCount`.
- **Success Criteria:** Method signatures compile cleanly; queries pass JPA validation on application startup.

### Phase 2: DTOs & Validation Layer
- **Objective:** Create standardized request and response transfer objects following the project's Lombok `@Builder`, `@Getter`, `@Setter` conventions.
- **Affected Files:**
  - New Request: `dto/request/RateItineraryRequest.java`
  - New Response: `dto/response/RatingResponse.java`
  - New Response: `dto/response/RatingSummaryResponse.java`
  - New Response: `dto/response/UserRatingStatusResponse.java`
  - New Response: `dto/response/FavoriteResponse.java`
  - New Response: `dto/response/SavedItineraryResponse.java`
  - Update: `dto/response/ItineraryDetailResponse.java` (add `isFavorited`, `isSaved`, `userRating` fields)
- **Deliverables:** Strictly validated DTOs with Jakarta validation annotations and complete serialization support.
- **Success Criteria:** DTOs compile and serialize cleanly to JSON with matching property names.

### Phase 3: Service Layer Implementation
- **Objective:** Encapsulate business logic, self-interaction checks, visibility constraints, atomic counter synchronization, concurrent duplicate handling, and transactional guarantees.
- **Affected Files:**
  - New: `service/RatingService.java` & `service/impl/RatingServiceImpl.java`
  - New: `service/FavoriteService.java` & `service/impl/FavoriteServiceImpl.java`
  - New: `service/SavedItineraryService.java` & `service/impl/SavedItineraryServiceImpl.java`
  - Update: `service/impl/ItineraryServiceImpl.java` (enrich `getItineraryDetail` with contextual flags for authenticated user)
- **Deliverables:**
  - Full CRUD transaction methods with `@Transactional` management.
  - Proper exception throwing (`BadRequestException`, `ResourceNotFoundException`, `UnauthorizedException`).
  - Try-catch block for `DataIntegrityViolationException` ensuring idempotent fallback.
- **Success Criteria:** All business rules and edge cases (upsert, self-action prevention, author save permission, silent filtering) are enforced in service methods.

### Phase 4: Controller Layer & Security Configuration
- **Objective:** Expose the agreed RESTful endpoints, map HTTP methods, extract `@AuthenticationPrincipal UserDetails`, and configure Spring Security authorization filters.
- **Affected Files:**
  - New: `controller/RatingController.java` (`@RequestMapping("/api/itineraries/{itineraryId}/ratings")`)
  - New: `controller/FavoriteController.java` (`@RequestMapping("/api/itineraries/{itineraryId}/favorites")` & `@RequestMapping("/api/user/favorites")`)
  - New: `controller/SavedItineraryController.java` (Maps `GET /api/user/saved-itineraries`, `POST /api/itineraries/{itineraryId}/save`, `DELETE /api/itineraries/{itineraryId}/save`)
  - Update: `security/SecurityConfig.java` (whitelist `GET /api/itineraries/{id:[0-9]+}/ratings`)
- **Deliverables:** Clean, annotated REST controllers delegating to service interfaces.
- **Success Criteria:** Proper HTTP status codes (200, 201, 204, 400, 401, 403, 404) returned matching the API Specification.

### Phase 5: Automated Testing & Verification
- **Objective:** Verify every endpoint, business rule, and edge case with dedicated integration tests.
- **Affected Files:**
  - New: `src/test/java/.../RatingControllerTest.java` (15+ test cases)
  - New: `src/test/java/.../FavoriteControllerTest.java` (14+ test cases)
  - New: `src/test/java/.../SavedItineraryControllerTest.java` (14+ test cases)
  - Update: `src/test/java/.../ItineraryControllerTest.java` (verify `isFavorited`, `isSaved`, `userRating` in detail response)
- **Deliverables:** 45+ new automated tests executing against SpringBootTest test context.
- **Success Criteria:** All 157 existing tests + 45+ new tests pass (`0 failures, 0 errors`).

---

## 8. Files and Modules Expected to Change

### 8.1 New Files to Create (14 files)

```text
Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/
├── controller/
│   ├── RatingController.java
│   ├── FavoriteController.java
│   └── SavedItineraryController.java
├── dto/
│   ├── request/
│   │   └── RateItineraryRequest.java
│   └── response/
│       ├── FavoriteResponse.java
│       ├── RatingResponse.java
│       ├── RatingSummaryResponse.java
│       ├── SavedItineraryResponse.java
│       └── UserRatingStatusResponse.java
└── service/
    ├── FavoriteService.java
    ├── RatingService.java
    ├── SavedItineraryService.java
    └── impl/
        ├── FavoriteServiceImpl.java
        ├── RatingServiceImpl.java
        └── SavedItineraryServiceImpl.java

Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/
├── FavoriteControllerTest.java
├── RatingControllerTest.java
└── SavedItineraryControllerTest.java
```

### 8.2 Existing Files to Modify (6 files)

```text
Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/
├── dto/response/ItineraryDetailResponse.java   (Add isFavorited, isSaved, userRating fields)
├── repository/ItineraryRepository.java          (Add atomic increment/decrement counter queries)
├── repository/RatingRepository.java             (Add user lookup and single itinerary AVG query)
├── repository/FavoriteRepository.java           (Add paginated user favorites query)
├── repository/SavedItineraryRepository.java      (Add filtered paginated saved query)
├── security/SecurityConfig.java                 (Whitelist GET ratings endpoint)
└── service/impl/ItineraryServiceImpl.java       (Populate contextual flags in getItineraryDetail)
```

---

## 9. Testing Strategy & Test Cases

### 9.1 Test Matrix

#### Rating Test Cases (`RatingControllerTest`):
1. `rateItinerary_Success_FirstTime_Returns201AndIncrementsCounter`: User submits 5 stars; rating created, `ratingCount` incremented by 1.
2. `rateItinerary_Success_ReRating_Returns200AndUpdatesScore`: User submits 4 stars for an already rated itinerary; score updated to 4, `ratingCount` remains unchanged.
3. `rateItinerary_SelfRating_Returns400`: Author tries to rate their own itinerary; returns 400 with message `"Bạn không thể tự đánh giá lịch trình của chính mình"`.
4. `rateItinerary_InvalidScore_Zero_Returns400`: Score = 0; validation error returned.
5. `rateItinerary_InvalidScore_Six_Returns400`: Score = 6; validation error returned.
6. `rateItinerary_PrivateItinerary_Returns404`: Trying to rate a private itinerary of another user returns 404.
7. `rateItinerary_DeletedItinerary_Returns404`: Trying to rate a deleted itinerary returns 404.
8. `rateItinerary_Unauthenticated_Returns401`: Missing Authorization header returns 401.
9. `rateItinerary_BannedUser_Returns403`: Banned user attempting to rate returns 403.
10. `getUserRating_WhenRated_ReturnsScoreAndDetails`: Returns score 5 and rated=true.
11. `getUserRating_WhenNotRated_ReturnsRatedFalse`: Returns rated=false, score=null.
12. `getRatingSummary_Public_ReturnsAverageAndDistribution`: Anyone (even guest) can view average rating and star distribution.
13. `deleteRating_Success_Returns200AndDecrementsCounter`: Rating deleted, `ratingCount` decremented, average recalculated.
14. `deleteRating_NotRated_Returns404`: Deleting a non-existent rating returns 404.
15. `concurrentRating_HandledIdempotently`: Simulating concurrent duplicate ratings does not cause double increment or SQL exceptions.

#### Favorite Test Cases (`FavoriteControllerTest`):
1. `addFavorite_Success_Returns201AndIncrementsCounter`: First time favorite; `favoriteCount` incremented.
2. `addFavorite_AlreadyFavorited_Returns200Idempotent`: Duplicate favorite returns 200 without double-incrementing.
3. `addFavorite_SelfFavorite_Returns400`: Author favoriting own itinerary rejected with `"Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"`.
4. `addFavorite_PrivateItinerary_Returns404`: Private itinerary returns 404.
5. `addFavorite_DeletedItinerary_Returns404`: Deleted itinerary returns 404.
6. `removeFavorite_Success_Returns200AndDecrementsCounter`: Removes favorite and decrements counter.
7. `removeFavorite_NotFavorited_Returns200Idempotent`: Removing non-existent favorite returns 200 without negative count.
8. `getFavoriteStatus_Favorited_ReturnsTrue`: Returns `favorited: true`.
9. `getFavoriteStatus_NotFavorited_ReturnsFalse`: Returns `favorited: false`.
10. `getUserFavorites_Success_ReturnsPaginatedList`: Returns list of favorited itineraries sorted by `createdAt DESC`.
11. `getUserFavorites_ExcludesDeletedItineraries`: Does not include itineraries deleted since being favorited.
12. `favorite_Unauthenticated_Returns401`: Anonymous request returns 401.
13. `concurrentFavorite_HandledIdempotentlyWithoutCounterDrift`: Two concurrent favorite calls yield count=1 and single record.

#### Saved Itineraries Test Cases (`SavedItineraryControllerTest`):
1. `saveItinerary_Success_Returns201`: User saves an itinerary via `POST /api/itineraries/{id}/save`; record created.
2. `saveItinerary_AlreadySaved_Returns200Idempotent`: Duplicate save returns 200.
3. `saveItinerary_OwnItinerary_Success_Returns201`: Author saving own itinerary **succeeds** (confirmed business rule).
4. `saveItinerary_PrivateItinerary_Returns404`: Saving private itinerary of another user returns 404.
5. `saveItinerary_DeletedItinerary_Returns404`: Saving deleted itinerary returns 404.
6. `unsaveItinerary_Success_Returns200`: Unsaving via `DELETE /api/itineraries/{id}/save` removes record.
7. `unsaveItinerary_NotSaved_Returns200Idempotent`: Unsaving non-existent record returns 200.
8. `getSavedItineraries_Success_ReturnsPaginatedList`: Returns paginated list of saved itineraries for current user via `GET /api/user/saved-itineraries`.
9. `getSavedItineraries_SilentFilter_HidesUnavailableItineraries`: Source itineraries that are DELETED, HIDDEN, or PRIVATE are omitted from the list.
10. `getSavedItineraries_Preservation_RestoredItineraryReappears`: Source itinerary restored from HIDDEN back to ACTIVE immediately reappears in saved list without re-saving.
11. `saveItinerary_Unauthenticated_Returns401`: Missing token returns 401.
12. `concurrentSave_HandledIdempotently`: Two concurrent save requests return clean response with no duplicated rows.

#### Detail Context Integration Test (`ItineraryControllerTest`):
1. `getItineraryDetail_WhenAuthenticated_IncludesContextualFlags`: User who favorited, saved, and rated an itinerary sees `isFavorited: true`, `isSaved: true`, `userRating: 5`.
2. `getItineraryDetail_WhenAnonymous_ContextualFlagsAreDefault`: Guest sees `isFavorited: false`, `isSaved: false`, `userRating: null`.

---

## 10. Security & Data Integrity

### 10.1 Authentication & Principal Extraction
All mutating endpoints extract the authenticated user identity exclusively from Spring Security's `UserDetails` injected via `@AuthenticationPrincipal`:
```java
@PostMapping
public ResponseEntity<RatingResponse> rateItinerary(
        @PathVariable Integer itineraryId,
        @Valid @RequestBody RateItineraryRequest request,
        @AuthenticationPrincipal UserDetails userDetails) {
    if (userDetails == null) {
        throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
    }
    String username = userDetails.getUsername();
    ...
}
```
Clients cannot spoof identity by passing a `userId` in query parameters or request body.

### 10.2 Preventing Data Leaks via 404 Obfuscation
When an itinerary is:
- `visibility = PRIVATE` (and caller is not owner)
- `status = DELETED`
- `status = HIDDEN`
- Author `status = BANNED`

The system must consistently return `404 Not Found` with `"Không tìm thấy lịch trình"` across all rating, favorite, and save endpoints. This prevents timing or status probing attacks.

### 10.3 Race Condition Prevention (Database Level)
Even under extreme concurrent requests from the same user:
- The composite unique constraints (`uk_rating_user_itinerary`, `uk_favorite_user_itinerary`, `uk_saved_user_itinerary`) guarantee that the database engine rejects duplicate inserts with a constraint violation.
- In Java service code, duplicate insert attempts catch `DataIntegrityViolationException` and gracefully fall back to returning the existing record (guaranteeing idempotency).

---

## 11. Dependencies and Potential Risks

| Risk / Dependency | Impact | Mitigation Strategy |
|:---|:---|:---|
| **Counter Desynchronization** | If an itinerary is deleted or a user is purged, denormalized counters (`favoriteCount`, `ratingCount`) could become inaccurate. | Counters are updated exclusively via atomic SQL queries with `where count > 0`. `DataSeeder.synchronizeItineraryCounters()` already provides an idempotent repair mechanism for maintenance. |
| **Cascade Deletes** | Deleting an itinerary must not violate foreign keys in `ratings`, `favorites`, or `saved_itineraries`. | The project uses soft deletes (`status = DELETED`) for itineraries. The physical rows remain in the DB, preserving historical ratings and favorites without foreign key constraint errors. |
| **Negative Counter Anomaly** | Under edge-case concurrency, decrementing could theoretically drop a counter below 0. | SQL JPQL guards decrements with `where i.favoriteCount > 0` and `where i.ratingCount > 0`. |
| **SecurityConfig Endpoint Ordering** | Adding new endpoints could accidentally be exposed as public or blocked incorrectly. | Standard Spring Security ordering: specific public matchers first, then `/api/admin/**`, then `.anyRequest().authenticated()`. Public rating aggregate `GET /api/itineraries/{id:[0-9]+}/ratings` explicitly registered before `.anyRequest().authenticated()`. |

---

## 12. Acceptance Criteria

The Backend Social Interaction implementation will be considered complete and ready for merge when:

1. ✅ **Rating Operations:**
   - Authenticated user can rate an active public itinerary (1–5 stars) and receive `201 Created`.
   - Re-rating the same itinerary updates the score, returns `200 OK`, and does NOT increment `ratingCount`.
   - Deleting a rating returns `200 OK`, decrements `ratingCount`, and updates average rating.
   - Author attempting to rate their own itinerary receives `400 Bad Request`.
   - Rating a private/deleted itinerary returns `404 Not Found`.
2. ✅ **Favorite Operations:**
   - Authenticated user can favorite an itinerary (`201 Created`), incrementing `favoriteCount`.
   - Favoriting an already favorited itinerary returns `200 OK` without double-incrementing.
   - Unfavoriting returns `200 OK` and decrements `favoriteCount`.
   - Author attempting to favorite own itinerary receives `400 Bad Request`.
   - `GET /api/user/favorites` returns paginated public favorited itineraries.
3. ✅ **Saved Itinerary Operations (3 Endpoints):**
   - Authenticated user can save an itinerary via `POST /api/itineraries/{itineraryId}/save` (`201 Created`).
   - Author saving their own itinerary succeeds (`201 Created` / `200 OK`).
   - Unsaving via `DELETE /api/itineraries/{itineraryId}/save` returns `200 OK`.
   - `GET /api/user/saved-itineraries` returns paginated list of saved itineraries, silently filtering out any non-ACTIVE or non-PUBLIC items while preserving their bookmark in DB.
4. ✅ **Detail Enrichment:**
   - `GET /api/itineraries/{id}` returns accurate `isFavorited`, `isSaved`, and `userRating` for authenticated callers.
5. ✅ **Verification Suite:**
   - All existing 157 backend tests pass without modification.
   - At least 40 new integration test cases across `RatingControllerTest`, `FavoriteControllerTest`, and `SavedItineraryControllerTest` pass with 0 errors and 0 failures.
   - Mobile and Web test suites remain 100% passing (regression guard).

---

## 13. Implementation Checklist

Use this checklist during implementation to track progress step-by-step:

- [ ] **Phase 1: Repository Extensions**
  - [ ] Update `RatingRepository.java` with user lookup and average calculation queries.
  - [ ] Update `FavoriteRepository.java` with pagination query `findByUser_UserId`.
  - [ ] Update `SavedItineraryRepository.java` with filtered pagination query joining active & public itineraries.
  - [ ] Update `ItineraryRepository.java` with atomic `@Modifying` increment/decrement queries.
- [ ] **Phase 2: DTOs & Validation**
  - [ ] Create `RateItineraryRequest.java` with `@Min(1)` and `@Max(5)` validation.
  - [ ] Create `RatingResponse.java`.
  - [ ] Create `RatingSummaryResponse.java` and `UserRatingStatusResponse.java`.
  - [ ] Create `FavoriteResponse.java`.
  - [ ] Create `SavedItineraryResponse.java`.
  - [ ] Add `isFavorited`, `isSaved`, `userRating` to `ItineraryDetailResponse.java`.
- [ ] **Phase 3: Services**
  - [ ] Implement `RatingService.java` interface and `RatingServiceImpl.java` (self-rating blocked, upsert support).
  - [ ] Implement `FavoriteService.java` interface and `FavoriteServiceImpl.java` (self-favorite blocked, atomic toggle).
  - [ ] Implement `SavedItineraryService.java` interface and `SavedItineraryServiceImpl.java` (self-save allowed, silent filter on list).
  - [ ] Update `ItineraryServiceImpl.getItineraryDetail` to populate contextual flags.
- [ ] **Phase 4: Controllers & Security**
  - [ ] Implement `RatingController.java`.
  - [ ] Implement `FavoriteController.java`.
  - [ ] Implement `SavedItineraryController.java` with exactly 3 routes:
    - `GET /api/user/saved-itineraries`
    - `POST /api/itineraries/{itineraryId}/save`
    - `DELETE /api/itineraries/{itineraryId}/save`
  - [ ] Update `SecurityConfig.java` to permit public access to `GET /api/itineraries/{id:[0-9]+}/ratings`.
- [ ] **Phase 5: Automated Tests & Verification**
  - [ ] Create `RatingControllerTest.java` with 15 test cases.
  - [ ] Create `FavoriteControllerTest.java` with 13 test cases.
  - [ ] Create `SavedItineraryControllerTest.java` with 12 test cases.
  - [ ] Update `ItineraryControllerTest.java` to assert contextual flags.
  - [ ] Run full test suite: `./mvnw.cmd test` (Target: 197+ tests passing, 0 failures).

---

## 14. Confirmed Business Decisions Summary

The following decisions were officially confirmed on 2026-11-04 and incorporated into this technical design:

1. **Self-Interaction Policy:**
   - **Rating:** Prohibited (`400 Bad Request`, `"Bạn không thể tự đánh giá lịch trình của chính mình"`).
   - **Favorite:** Prohibited (`400 Bad Request`, `"Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"`).
   - **Saved Itinerary:** **Permitted** (`201 Created` / `200 OK`).
2. **Saved Itinerary Endpoints:**
   - Unified to exactly 3 non-redundant endpoints:
     - `GET /api/user/saved-itineraries`
     - `POST /api/itineraries/{itineraryId}/save`
     - `DELETE /api/itineraries/{itineraryId}/save`
   - Removed `/api/user/saved-itineraries/{itineraryId}` to prevent route duplication.
3. **Handling Unavailable Saved Itineraries (Silent Filtering & Preservation):**
   - In `GET /api/user/saved-itineraries`, query filters for `itinerary.status == ACTIVE` and `itinerary.visibility == PUBLIC`.
   - Inactive/deleted/private items are hidden from the feed without deleting the underlying `SavedItinerary` row in MySQL.
   - When a source itinerary is restored or unhidden, it automatically becomes visible in the saved list again without any user intervention.
