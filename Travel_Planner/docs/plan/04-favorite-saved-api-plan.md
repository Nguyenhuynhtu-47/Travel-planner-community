# Implementation Plan 02: Favorite & Saved Itinerary APIs

**Document Reference:** `plan/04-favorite-saved-api-plan.md`  
**Location:** `Travel_Planner/docs/plan/04-favorite-saved-api-plan.md`  
**Creation Date:** 2026-11-04  
**Author / Technical Lead:** Senior Software Architect & Technical Lead  
**Assignee:** Member 2 (Favorite & Saved APIs Full-Stack Slice)  
**Scope:** Backend Vertical Slice (Repository ➔ DTO ➔ Service ➔ Controller ➔ Tests ➔ Detail Integration)  
**Parent Plan:** [`plan/02-backend-social-interaction-plan.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/plan/02-backend-social-interaction-plan.md)  
**Target Milestone:** Phase 2 Tasks P2-F1 & P2-SA1  

---

## 1. Objectives & Scope

### 1.1 Objectives
1. Implement the complete **Favorite API**, enabling authenticated users to favorite (like) and unfavorite public travel itineraries, maintaining `favoriteCount` with concurrency-safe atomic database increments and decrements.
2. Implement the complete **Saved Itinerary API** using strictly the **three agreed non-redundant endpoints** (`GET /api/user/saved-itineraries`, `POST /api/itineraries/{itineraryId}/save`, `DELETE /api/itineraries/{itineraryId}/save`), powering the mobile app's "Đã Lưu" tab (`SavedItinerariesScreen`).
3. Enforce **Confirmed Self-Interaction Policies**:
   - **Self-Favorite Blocked:** Authors cannot favorite their own itineraries (`400 Bad Request`).
   - **Self-Save Permitted:** Authors **CAN** save/bookmark their own itineraries (`201 Created` / `200 OK`).
4. Implement **Silent Filtering & Data Preservation** for saved itineraries:
   - Query filters out any saved itineraries that are not currently `ACTIVE` and `PUBLIC`.
   - The underlying bookmark in `saved_itineraries` is **NEVER deleted** when an itinerary is hidden or soft-deleted; if the itinerary is restored to active public status, it automatically reappears in the user's saved list.
5. Provide **Concurrency Safety**: handle duplicate simultaneous requests using database unique constraints (`uk_favorite_user_itinerary`, `uk_saved_user_itinerary`) and graceful idempotent fallback.
6. Integrate contextual flags (`isFavorited`, `isSaved`) into `ItineraryDetailResponse`.

### 1.2 Scope
- **IN SCOPE:**
  - `FavoriteRepository` and `SavedItineraryRepository` query extensions.
  - Atomic counter operations in `ItineraryRepository` (`incrementFavoriteCount`, `decrementFavoriteCount`).
  - Response DTOs (`FavoriteResponse`, `SavedItineraryResponse`).
  - `FavoriteService` / `FavoriteServiceImpl` and `SavedItineraryService` / `SavedItineraryServiceImpl`.
  - `FavoriteController` and `SavedItineraryController` REST endpoints.
  - Comprehensive integration and concurrency tests (`FavoriteControllerTest`, `SavedItineraryControllerTest`).
  - Integration of `isFavorited` and `isSaved` into `ItineraryDetailResponse` and `ItineraryServiceImpl`.
- **EXPLICITLY OUT OF SCOPE:**
  - Rating API & dynamic average rating engine (handled independently by Member 1 in Plan 03).
  - Redundant routes like `/api/user/saved-itineraries/{itineraryId}` (explicitly forbidden).
  - Frontend Mobile/Web UI screens.
  - Push notifications for new favorites.

---

## 2. Existing Architecture Analysis

### 2.1 Layer Design & Technology Standards
- **Framework:** Spring Boot 4.1.1 (Java 22), Spring Data JPA, Spring Security (Stateless JWT).
- **Architecture:** Layered REST architecture with separation of concerns:
  - `controller/FavoriteController.java`: Endpoints for favoriting, checking status, and listing favorites.
  - `controller/SavedItineraryController.java`: Exactly 3 endpoints for saving, unsaving, and listing saved itineraries.
  - `service/FavoriteServiceImpl.java` & `service/SavedItineraryServiceImpl.java`: Transactional business logic (`@Transactional`), self-interaction validation, entity lifecycle, atomic counter coordination.
  - `repository/FavoriteRepository.java` & `repository/SavedItineraryRepository.java`: JPA repository queries.
  - `repository/ItineraryRepository.java`: Atomic `@Modifying` queries for `favoriteCount`.

### 2.2 Reusable Components (Do Not Recreate)
- **Entities:** `Travel_Planner.Travel_Planner.model.Favorite` and `SavedItinerary` (already mapped to MySQL tables `favorites` and `saved_itineraries`).
- **Entity:** `Itinerary.java` (Contains `favoriteCount`, `user`, `status`, `visibility`).
- **DTOs:** `ItinerarySummaryResponse.java` and `PageResponse.java` (already exist; reuse directly for `GET /api/user/saved-itineraries` and `GET /api/user/favorites`).
- **Exception Classes:** `BadRequestException` (400), `UnauthorizedException` (401), `ForbiddenException` (403), `ResourceNotFoundException` (404).

---

## 3. Database & Entity Analysis

### 3.1 Entity Models: `Favorite.java` & `SavedItinerary.java`

#### `Favorite.java` (`backend/.../model/Favorite.java`):
- Fields: `favoriteId` (PK), `user` (FK `user_id`), `itinerary` (FK `itinerary_id`), `createdAt`.
- **Unique Constraint:**
  ```java
  @Table(name = "favorites", uniqueConstraints = {
      @UniqueConstraint(name = "uk_favorite_user_itinerary", columnNames = {"user_id", "itinerary_id"})
  })
  ```

#### `SavedItinerary.java` (`backend/.../model/SavedItinerary.java`):
- Fields: `saveId` (PK), `user` (FK `user_id`), `itinerary` (FK `itinerary_id`), `createdAt`.
- **Unique Constraint:**
  ```java
  @Table(name = "saved_itineraries", uniqueConstraints = {
      @UniqueConstraint(name = "uk_saved_user_itinerary", columnNames = {"user_id", "itinerary_id"})
  })
  ```

Both tables are already created in MySQL with matching foreign keys and unique constraints. **Zero database DDL changes required.**

### 3.2 Denormalized Counter: `favoriteCount`
- `Itinerary.favoriteCount` (`Integer`, default 0, non-null).
- Must be updated exclusively via atomic SQL queries to prevent lost updates.

---

## 4. API Specifications

### 4.1 Favorite Endpoints (`/api/itineraries/{itineraryId}/favorites` & `/api/user/favorites`)

All endpoints require authentication (`Authorization: Bearer <jwt_token>`).

#### 1. Add Favorite (Like)
- **`POST /api/itineraries/{itineraryId}/favorites`**
- **Business Behavior:**
  - If `itinerary.user.userId == currentUser.userId`: throw `BadRequestException("Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích")`.
  - Itinerary must be active & public. Otherwise throw `ResourceNotFoundException("Không tìm thấy lịch trình")`.
  - Idempotent: If already favorited, return `200 OK` with `favorited: true`.
  - If newly favorited: insert `Favorite`, atomically increment `itinerary.favoriteCount` (+1), return `201 Created`.
- **Response Body (`FavoriteResponse`):**
  ```json
  {
    "itineraryId": 1,
    "favorited": true,
    "favoriteCount": 24
  }
  ```

#### 2. Remove Favorite (Unlike)
- **`DELETE /api/itineraries/{itineraryId}/favorites`**
- **Business Behavior:**
  - Idempotent: If record exists, delete `Favorite`, atomically decrement `itinerary.favoriteCount` (-1, guarded at 0).
  - Return `200 OK`.
- **Response Body (`FavoriteResponse`):**
  ```json
  {
    "itineraryId": 1,
    "favorited": false,
    "favoriteCount": 23
  }
  ```

#### 3. Check Favorite Status
- **`GET /api/itineraries/{itineraryId}/favorites/status`**
- **Response Body (`FavoriteResponse`):**
  ```json
  {
    "itineraryId": 1,
    "favorited": true,
    "favoriteCount": 24
  }
  ```

#### 4. List User's Favorited Itineraries
- **`GET /api/user/favorites?page=0&size=10`**
- **Response Body:** `PageResponse<ItinerarySummaryResponse>` (silently filters out deleted, hidden, or private items).

---

### 4.2 Saved Itinerary Endpoints (Strictly 3 Agreed Endpoints)

All endpoints require authentication (`Authorization: Bearer <jwt_token>`).

#### 1. Save Itinerary (Bookmark)
- **`POST /api/itineraries/{itineraryId}/save`**
- **Business Behavior:**
  - **Self-Save Permitted:** If author saves own itinerary, allow with `201 Created` / `200 OK`.
  - Idempotent: If already saved, return `200 OK` with existing `saveId`. If newly saved, insert into `saved_itineraries` and return `201 Created`.
- **Response Body (`SavedItineraryResponse`):**
  ```json
  {
    "saveId": 18,
    "itineraryId": 1,
    "saved": true,
    "savedAt": "2026-11-04T10:20:00"
  }
  ```

#### 2. Remove Saved Itinerary (Unbookmark)
- **`DELETE /api/itineraries/{itineraryId}/save`**
- **Business Behavior:**
  - Idempotent: Delete `SavedItinerary` record if present. Return `200 OK`.
- **Response Body (`SavedItineraryResponse`):**
  ```json
  {
    "saveId": null,
    "itineraryId": 1,
    "saved": false,
    "savedAt": null
  }
  ```

#### 3. Get User's Saved Itineraries (Mobile "Đã Lưu" Tab)
- **`GET /api/user/saved-itineraries?page=0&size=10`**
- **Query Parameters:** `page` (default 0), `size` (default 10, max 50).
- **Business Behavior (Silent Filter & Preservation):**
  - Uses JPQL JOIN query filtering `where s.user.userId = :userId and s.itinerary.status = 'ACTIVE' and s.itinerary.visibility = 'PUBLIC' and s.itinerary.user.status = 'ACTIVE'`.
  - Inactive/deleted/private itineraries are **silently omitted** from the response list.
  - The `SavedItinerary` row in MySQL is **never deleted**. If the source itinerary becomes `ACTIVE + PUBLIC` again, it immediately reappears in the list.
- **Response Body:** `PageResponse<ItinerarySummaryResponse>` (ordered by `s.createdAt DESC`).

---

## 5. Business Rules

1. **Self-Interaction Policy:**
   - **Favorite:** Authors CANNOT favorite their own itineraries (`400 Bad Request` with `"Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"`).
   - **Save:** Authors **CAN** save their own itineraries (`201 Created` / `200 OK`).
2. **Idempotency:**
   - Calling `POST .../favorites` or `POST .../save` repeatedly returns `200 OK` without error and without duplicating records or double-incrementing counters.
   - Calling `DELETE .../favorites` or `DELETE .../save` when not favorited/saved returns `200 OK` without dropping counters below zero.
3. **Availability & Obfuscation:**
   - Non-active or private itineraries return `404 Not Found` (`"Không tìm thấy lịch trình"`).
4. **Concurrency Safety:**
   - When concurrent duplicate calls hit `uk_favorite_user_itinerary` or `uk_saved_user_itinerary`, catch `DataIntegrityViolationException` in service and return existing state cleanly.

---

## 6. Implementation Phases (Member 2)

### Phase 1: Repository Extensions
- File: `repository/FavoriteRepository.java`
  - Add: `Page<Favorite> findByUser_UserId(Integer userId, Pageable pageable);`
- File: `repository/SavedItineraryRepository.java`
  - Add filtered query with silent filter:
    ```java
    @Query("SELECT s FROM SavedItinerary s " +
           "WHERE s.user.userId = :userId " +
           "AND s.itinerary.status = Travel_Planner.Travel_Planner.model.enums.ItineraryStatus.ACTIVE " +
           "AND s.itinerary.visibility = Travel_Planner.Travel_Planner.model.enums.Visibility.PUBLIC " +
           "AND s.itinerary.user.status = Travel_Planner.Travel_Planner.model.enums.UserStatus.ACTIVE " +
           "ORDER BY s.createdAt DESC")
    Page<SavedItinerary> findActivePublicSavedItineraries(@Param("userId") Integer userId, Pageable pageable);
    ```
- File: `repository/ItineraryRepository.java`
  - Add atomic queries:
    ```java
    @Modifying
    @Query("update Itinerary i set i.favoriteCount = i.favoriteCount + 1 where i.itineraryId = :itineraryId")
    int incrementFavoriteCount(@Param("itineraryId") Integer itineraryId);

    @Modifying
    @Query("update Itinerary i set i.favoriteCount = i.favoriteCount - 1 where i.itineraryId = :itineraryId and i.favoriteCount > 0")
    int decrementFavoriteCount(@Param("itineraryId") Integer itineraryId);
    ```

### Phase 2: DTOs
Create in `dto/response/`:
- `FavoriteResponse.java`: itineraryId, favorited (`boolean`), favoriteCount (`int`).
- `SavedItineraryResponse.java`: saveId (`Integer`), itineraryId (`Integer`), saved (`boolean`), savedAt (`LocalDateTime`).

### Phase 3: Service Layer Implementation
- `service/FavoriteService.java` & `service/impl/FavoriteServiceImpl.java`:
  - `addFavorite(itineraryId, username)`
  - `removeFavorite(itineraryId, username)`
  - `getFavoriteStatus(itineraryId, username)`
  - `getUserFavorites(username, page, size)`
- `service/SavedItineraryService.java` & `service/impl/SavedItineraryServiceImpl.java`:
  - `saveItinerary(itineraryId, username)` (author allowed)
  - `unsaveItinerary(itineraryId, username)`
  - `getUserSavedItineraries(username, page, size)` (silent filter)
  - `getSaveStatus(itineraryId, username)`
- Catch `DataIntegrityViolationException` for race condition idempotency.

### Phase 4: Controller Layer
- Create `controller/FavoriteController.java`:
  - `POST /api/itineraries/{itineraryId}/favorites`
  - `DELETE /api/itineraries/{itineraryId}/favorites`
  - `GET /api/itineraries/{itineraryId}/favorites/status`
  - `GET /api/user/favorites`
- Create `controller/SavedItineraryController.java`:
  - `GET /api/user/saved-itineraries`
  - `POST /api/itineraries/{itineraryId}/save`
  - `DELETE /api/itineraries/{itineraryId}/save`

### Phase 5: Automated Testing
- Create `src/test/java/.../FavoriteControllerTest.java` (13+ test cases).
- Create `src/test/java/.../SavedItineraryControllerTest.java` (12+ test cases).
- Execute: `./mvnw.cmd test -Dtest=FavoriteControllerTest,SavedItineraryControllerTest`.

### Phase 6: Final Integration with `ItineraryDetailResponse`
*(Execute in coordination with Member 1 after both test suites pass)*
- Add `private Boolean isFavorited;` and `private Boolean isSaved;` to `ItineraryDetailResponse.java`.
- Update `ItineraryServiceImpl.getItineraryDetail()` to populate both flags.

---

## 7. Expected Files to Create / Modify

### Files to CREATE (Member 2 Exclusive):
1. `backend/src/main/java/.../dto/response/FavoriteResponse.java`
2. `backend/src/main/java/.../dto/response/SavedItineraryResponse.java`
3. `backend/src/main/java/.../service/FavoriteService.java`
4. `backend/src/main/java/.../service/impl/FavoriteServiceImpl.java`
5. `backend/src/main/java/.../service/SavedItineraryService.java`
6. `backend/src/main/java/.../service/impl/SavedItineraryServiceImpl.java`
7. `backend/src/main/java/.../controller/FavoriteController.java`
8. `backend/src/main/java/.../controller/SavedItineraryController.java`
9. `backend/src/test/java/.../FavoriteControllerTest.java`
10. `backend/src/test/java/.../SavedItineraryControllerTest.java`

### Files to MODIFY:
1. `backend/src/main/java/.../repository/FavoriteRepository.java` (Exclusive to Member 2)
2. `backend/src/main/java/.../repository/SavedItineraryRepository.java` (Exclusive to Member 2)
3. `backend/src/main/java/.../repository/ItineraryRepository.java` (SHARED with Member 1 — add only `favoriteCount` queries at end of interface)
4. `backend/src/main/java/.../dto/response/ItineraryDetailResponse.java` (SHARED with Member 1 — add `isFavorited` and `isSaved` during Phase 6 integration)
5. `backend/src/main/java/.../service/impl/ItineraryServiceImpl.java` (SHARED with Member 1 — populate `isFavorited` and `isSaved` during Phase 6 integration)

---

## 8. Testing Strategy & Test Cases

### 8.1 Favorite Test Cases (`FavoriteControllerTest`):
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

### 8.2 Saved Itineraries Test Cases (`SavedItineraryControllerTest`):
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

---

## 9. Dependencies & Shared File Coordination

### 9.1 Shared File Rules:
- **`ItineraryRepository.java`:** Member 2 appends `incrementFavoriteCount` and `decrementFavoriteCount`. Member 1 appends `incrementRatingCount` and `decrementRatingCount`. Placing both at the bottom of the interface guarantees clean Git three-way merges.
- **`SecurityConfig.java`:** Member 2 **DOES NOT EDIT** `SecurityConfig.java`. All favorite and save endpoints require authentication, which is already handled by `.anyRequest().authenticated()`.
- **`ItineraryDetailResponse.java` & `ItineraryServiceImpl.java`:** Kept untouched during independent phases, integrated jointly in Phase 6.

---

## 10. Integration Requirements

During Phase 6, after `FavoriteControllerTest` and `SavedItineraryControllerTest` pass:
1. Coordinate with Member 1 to open `ItineraryDetailResponse.java`.
2. Ensure both `isFavorited` and `isSaved` (Member 2) and `userRating` (Member 1) are declared.
3. In `ItineraryServiceImpl.getItineraryDetail()`, if `currentUsername != null`, resolve flags:
   ```java
   boolean isFavorited = favoriteRepository.existsByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), id);
   boolean isSaved = savedItineraryRepository.existsByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), id);
   ```
4. Verify all tests pass with `./mvnw.cmd test`.

---

## 11. Acceptance Criteria

1. ✅ Authenticated user can favorite and unfavorite active public itineraries, updating `favoriteCount` atomically.
2. ✅ Author attempting to favorite own itinerary receives `400 Bad Request` (`"Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"`).
3. ✅ Authenticated user can save and unsave itineraries via `POST/DELETE /api/itineraries/{id}/save`.
4. ✅ Author **CAN** save own itinerary (`201 Created` / `200 OK`).
5. ✅ `GET /api/user/saved-itineraries` returns paginated saved items, silently omitting unavailable items while preserving bookmarks in MySQL.
6. ✅ All 25 test cases across `FavoriteControllerTest` and `SavedItineraryControllerTest` pass with 0 errors and 0 failures.

---

## 12. Implementation Checklist (Member 2)

- [ ] **Phase 1: Repository Layer**
  - [ ] Add `findByUser_UserId` to `FavoriteRepository.java`.
  - [ ] Add `findActivePublicSavedItineraries` to `SavedItineraryRepository.java`.
  - [ ] Add `incrementFavoriteCount` and `decrementFavoriteCount` to `ItineraryRepository.java`.
- [ ] **Phase 2: DTOs**
  - [ ] Create `FavoriteResponse.java`.
  - [ ] Create `SavedItineraryResponse.java`.
- [ ] **Phase 3: Service Layer**
  - [ ] Create `FavoriteService.java` & `FavoriteServiceImpl.java` (self-favorite check, atomic count).
  - [ ] Create `SavedItineraryService.java` & `SavedItineraryServiceImpl.java` (author save allowed, silent filter).
- [ ] **Phase 4: Controllers**
  - [ ] Create `FavoriteController.java`.
  - [ ] Create `SavedItineraryController.java` (exactly 3 endpoints).
- [ ] **Phase 5: Automated Tests**
  - [ ] Write `FavoriteControllerTest.java` (13 tests).
  - [ ] Write `SavedItineraryControllerTest.java` (12 tests).
  - [ ] Run test suite: `./mvnw.cmd test -Dtest=FavoriteControllerTest,SavedItineraryControllerTest` (100% pass).
- [ ] **Phase 6: Integration**
  - [ ] Coordinate with Member 1 to add `isFavorited` and `isSaved` to `ItineraryDetailResponse` & `ItineraryServiceImpl`.
  - [ ] Run full regression suite: `./mvnw.cmd test`.

---

## 13. Handover Requirements

Upon finishing Phase 5, Member 2 must provide:
1. Git branch name / diff containing exclusively Favorite and Saved files.
2. Proof of test execution: `./mvnw.cmd test -Dtest=FavoriteControllerTest,SavedItineraryControllerTest` results.
3. Confirmation of readiness for Phase 6 joint integration.

