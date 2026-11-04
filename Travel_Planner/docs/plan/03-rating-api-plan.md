# Implementation Plan 01: Rating API & Dynamic Aggregate Engine

**Document Reference:** `plan/03-rating-api-plan.md`  
**Location:** `Travel_Planner/docs/plan/03-rating-api-plan.md`  
**Creation Date:** 2026-11-04  
**Last Updated:** 2026-11-04 (Final Polish: 10 New vs 1 Existing Endpoint, Atomic Counter Transactionality, Idempotency & Rebase Conflict Protocol)  
**Author / Technical Lead:** Senior Software Architect & Technical Lead  
**Assignee:** Member 1 (Rating API Full-Stack Slice)  
**Active Working Branch:** `develop` (Changes currently in Working Tree, uncommitted and unpushed)  
**Scope:** Backend Vertical Slice (Repository ➔ DTO ➔ Service ➔ Controller ➔ Tests ➔ Detail Integration)  
**Parent Plan:** [`plan/02-backend-social-interaction-plan.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/plan/02-backend-social-interaction-plan.md)  
**Target Milestone:** Phase 2 Task P2-R1  

---

## 1. Objectives & Scope

### 1.1 Objectives
1. Implement the complete **Rating API** for the Travel Planner platform, allowing authenticated users to rate public travel itineraries on a 1-to-5 star scale.
2. Provide seamless **Re-rating (Upsert)** behavior: if a user submits a new rating score for an already-rated itinerary, update the existing score and timestamp without incrementing the total `ratingCount`.
3. Support **Delete Rating**: allow users to withdraw their rating, atomically decrementing `ratingCount` and updating the average rating.
4. Calculate **Average Rating (`averageRating`) dynamically** via database aggregation (`SELECT AVG(r.score)`), avoiding floating-point drift and denormalization inconsistencies.
5. Enforce strict **Self-Rating Prohibition**: prevent authors from rating their own itineraries (`400 Bad Request`).
6. Guarantee **Concurrency & Data Integrity**: handle concurrent duplicate submissions gracefully via database unique constraints and atomic queries.
7. Integrate contextual rating data (`userRating`, `ratingCount`, `averageRating`) into `ItineraryDetailResponse`.
8. **Endpoint Architecture Breakdown (10 NEW vs 1 EXISTING):**
   - This plan implements **4 NEW REST endpoints** for Rating (out of 10 new endpoints across the entire Social Interaction feature):
     1. `POST /api/itineraries/{itineraryId}/ratings` (Create or update rating)
     2. `GET /api/itineraries/{itineraryId}/ratings/me` (Current user's rating)
     3. `GET /api/itineraries/{itineraryId}/ratings` (Public aggregate rating summary & star distribution)
     4. `DELETE /api/itineraries/{itineraryId}/ratings` (Delete own rating)
   - The **1 EXISTING endpoint** (`GET /api/itineraries/{id}`) in `ItineraryController.java` is enriched with `userRating` (alongside `isFavorited` and `isSaved`) during Phase 6 / Joint Phase 9.

### 1.2 Scope & Test Status Delineation
- **AUDITED REPOSITORY BASELINE (Session 83 Live Test Execution):**
  - **157 / 157 Backend tests passing** (`mvnw.cmd test` in 44.8s). Regression guard.
  - *Note: In Sessions 84 and 85, no automated test commands were re-run because no application source code was modified.*
- **IN SCOPE (PLANNED TASKS FOR MEMBER 1):**
  - `RatingRepository` query extensions.
  - Atomic counter operations in `ItineraryRepository` (`incrementRatingCount`, `decrementRatingCount`).
  - Request/Response DTOs (`RateItineraryRequest`, `RatingResponse`, `RatingSummaryResponse`, `UserRatingStatusResponse`).
  - `RatingService` interface and `RatingServiceImpl` implementation.
  - `RatingController` REST endpoints under `/api/itineraries/{itineraryId}/ratings`.
  - Spring Security whitelist for public rating summary.
  - **Planned Automated Tests:** 15 test cases in `RatingControllerTest` (to be implemented in Phase 5).
  - Integration of `userRating` field into `ItineraryDetailResponse` and `ItineraryServiceImpl` (during Joint Phase 9).
- **EXPLICITLY OUT OF SCOPE:**
  - Favorite and Saved Itinerary APIs (handled independently by Member 2 in Plan 04).
  - Frontend Mobile/Web UI widgets (handled in subsequent sprint tasks).
  - Comment moderation or reporting.

---

## 2. Existing Architecture Analysis

### 2.1 Layer Design & Technology Standards
- **Framework:** Spring Boot 4.1.1 (Java 22), Spring Data JPA, Spring Security (Stateless JWT).
- **Architecture:** Layered REST architecture with separation of concerns:
  - `controller/RatingController.java`: HTTP routing, `@Valid` body checks, extracting `@AuthenticationPrincipal UserDetails`.
  - `service/RatingService.java` & `service/impl/RatingServiceImpl.java`: Transactional business logic (`@Transactional`), self-interaction validation, entity lifecycle.
  - `repository/RatingRepository.java`: JPA repository with derived queries and JPQL `@Query`.
  - `repository/ItineraryRepository.java`: Atomic `@Modifying` queries for counter updates.

### 2.2 Reusable Components (Do Not Recreate)
- **Entity:** `Travel_Planner.Travel_Planner.model.Rating` (Already mapped to MySQL table `ratings`).
- **Entity:** `Travel_Planner.Travel_Planner.model.Itinerary` (Contains `ratingCount`, `user`, `status`, `visibility`).
- **Exception Classes:** `BadRequestException` (400), `UnauthorizedException` (401), `ForbiddenException` (403), `ResourceNotFoundException` (404) in package `Travel_Planner.Travel_Planner.exception`.
- **Exception Handler:** `GlobalExceptionHandler` automatically maps custom exceptions to standard `ErrorResponse`.

---

## 3. Database & Entity Analysis

### 3.1 Entity Model: `Rating.java`
Located at `backend/.../model/Rating.java`:
- Fields:
  - `ratingId`: `Integer` (PK, Identity)
  - `user`: `User` (ManyToOne, FK `user_id`, non-null)
  - `itinerary`: `Itinerary` (ManyToOne, FK `itinerary_id`, non-null)
  - `score`: `Integer` (non-null, valid range 1..5)
  - `createdAt`: `LocalDateTime` (updatable = false)
  - `updatedAt`: `LocalDateTime`
- **Unique Constraint:**
  ```java
  @Table(name = "ratings", uniqueConstraints = {
      @UniqueConstraint(name = "uk_rating_user_itinerary", columnNames = {"user_id", "itinerary_id"})
  })
  ```
  The database engine already enforces that a user can never possess more than one rating record per itinerary.

### 3.2 Denormalized Counter on `Itinerary.java`
- `ratingCount`: `Integer` (default 0, nullable = false).
- **Rule on Average Rating:** Average rating is **NOT** a column in table `itineraries`. It is computed dynamically via SQL `AVG(r.score)` to eliminate rounding drift.

---

## 4. API Specifications

All endpoints use JSON and are prefixed with `/api/itineraries/{itineraryId}/ratings`.

### 4.1 Endpoint Overview

| Method | Endpoint | Auth | Purpose | Success Status |
|:---|:---|:---|:---|:---|
| `POST` | `/api/itineraries/{itineraryId}/ratings` | Required | Rate or update rating (Upsert) | `201 Created` (new) / `200 OK` (update) |
| `GET` | `/api/itineraries/{itineraryId}/ratings/me` | Required | Get current user's rating for itinerary | `200 OK` |
| `GET` | `/api/itineraries/{itineraryId}/ratings` | Public | Get aggregate summary & star distribution | `200 OK` |
| `DELETE`| `/api/itineraries/{itineraryId}/ratings` | Required | Delete own rating | `200 OK` |

---

### 4.2 Endpoint Details

#### 1. Submit or Update Rating (Upsert)
- **`POST /api/itineraries/{itineraryId}/ratings`**
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Request Body (`RateItineraryRequest`):**
  ```json
  {
    "score": 5
  }
  ```
- **Validation:**
  - `@NotNull(message = "Điểm đánh giá không được để trống")`
  - `@Min(value = 1, message = "Điểm đánh giá tối thiểu là 1 sao")`
  - `@Max(value = 5, message = "Điểm đánh giá tối đa là 5 sao")`
- **Logic:**
  1. Authenticate user. If author == current user: throw `BadRequestException("Bạn không thể tự đánh giá lịch trình của chính mình")`.
  2. Verify itinerary is `status == ACTIVE`, `visibility == PUBLIC`, author `status == ACTIVE`. Otherwise throw `ResourceNotFoundException("Không tìm thấy lịch trình")`.
  3. Look up existing `Rating` via `findByUser_UserIdAndItinerary_ItineraryId(userId, itineraryId)`.
  4. If found (Update): update `score`, update `updatedAt`, save. Do **NOT** increment `ratingCount`. Return `200 OK`.
  5. If not found (Create): create new `Rating`, save. Increment `ratingCount` (+1) atomically in `ItineraryRepository`. Return `201 Created`.
  6. Compute dynamic `averageRating` and return `RatingResponse`.
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

#### 2. Get Current User's Rating
- **`GET /api/itineraries/{itineraryId}/ratings/me`**
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Response Body (`UserRatingStatusResponse`):**
  - If rated:
    ```json
    {
      "itineraryId": 1,
      "rated": true,
      "score": 5,
      "ratingId": 42,
      "updatedAt": "2026-11-04T10:15:30"
    }
    ```
  - If not rated:
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
- **`GET /api/itineraries/{itineraryId}/ratings`**
- **Auth:** Public (Whitelisted in `SecurityConfig`).
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
- **`DELETE /api/itineraries/{itineraryId}/ratings`**
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Logic:**
  1. Find rating by user and itinerary. If not found: throw `ResourceNotFoundException("Bạn chưa đánh giá lịch trình này")`.
  2. Delete rating record.
  3. Atomically decrement `itinerary.ratingCount` (-1, guarded at 0).
  4. Compute updated `averageRating`.
- **Response Body:** `200 OK`
  ```json
  {
    "message": "Đã xóa đánh giá thành công",
    "itineraryId": 1,
    "averageRating": 4.64,
    "ratingCount": 14
  }
  ```

---

## 5. Business Rules & Concurrency Control

1. **Self-Rating Blocked:** Authors cannot rate their own itinerary. Returns `HTTP 400 Bad Request` with `"Bạn không thể tự đánh giá lịch trình của chính mình"`.
2. **Score Range:** Strictly integers from 1 to 5 (`@Min(1)`, `@Max(5)`).
3. **Atomic Counter Execution Conditions:**
   - `incrementRatingCount`: Executed **STRICTLY ONCE** upon physical insertion of a new `Rating` entity.
   - **Re-Rating (Score Update):** When a user submits a new rating for an already-rated itinerary, the service updates `score` and `updatedAt`, but **MUST NOT** execute `incrementRatingCount`.
   - `decrementRatingCount`: Executed **STRICTLY ONCE** upon physical deletion of an existing `Rating` entity.
4. **Transactional Boundary & Rollback Consistency:**
   - All mutating methods in `RatingServiceImpl` are annotated with `@Transactional(rollbackFor = Exception.class)`.
   - Because `ratingRepository.save(...)` and `itineraryRepository.incrementRatingCount(...)` execute within the same database transaction, any runtime exception or database error automatically triggers a **full rollback** of both the entity mutation and the counter update, guaranteeing zero counter drift.
5. **Availability & Obfuscation:** Itineraries that are `PRIVATE` (to non-owners), `DELETED`, `HIDDEN`, or authored by a `BANNED` user return `404 Not Found` (`"Không tìm thấy lịch trình"`), preventing resource existence probing.
6. **Concurrency Safety & Idempotent Fallback:**
   - Under concurrent duplicate requests from the same user, MySQL composite constraint `uk_rating_user_itinerary` prevents duplicate rows and throws Spring's `DataIntegrityViolationException`.
   - The service layer wraps insertion in a try-catch block catching `DataIntegrityViolationException`, retrieves the existing record, and updates the score without double-incrementing `ratingCount`.

---

## 6. Implementation Phases (Member 1)

### Phase 1: Repository Extensions
- File: `repository/RatingRepository.java`
  - `Optional<Rating> findByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);`
  - `@Query("SELECT AVG(r.score) FROM Rating r WHERE r.itinerary.itineraryId = :itineraryId") Double findAverageRatingByItineraryId(@Param("itineraryId") Integer itineraryId);`
  - `@Query("SELECT r.score, COUNT(r) FROM Rating r WHERE r.itinerary.itineraryId = :itineraryId GROUP BY r.score") List<Object[]> countStarDistributionByItineraryId(@Param("itineraryId") Integer itineraryId);`
- File: `repository/ItineraryRepository.java`
  - Add atomic queries:
    ```java
    @Modifying
    @Query("update Itinerary i set i.ratingCount = i.ratingCount + 1 where i.itineraryId = :itineraryId")
    int incrementRatingCount(@Param("itineraryId") Integer itineraryId);

    @Modifying
    @Query("update Itinerary i set i.ratingCount = i.ratingCount - 1 where i.itineraryId = :itineraryId and i.ratingCount > 0")
    int decrementRatingCount(@Param("itineraryId") Integer itineraryId);
    ```

### Phase 2: DTOs & Validation Models
Create in `dto/request/` and `dto/response/`:
- `RateItineraryRequest.java`: score validation (`@NotNull`, `@Min(1)`, `@Max(5)`).
- `RatingResponse.java`: ratingId, itineraryId, score, averageRating, ratingCount, createdAt, updatedAt.
- `RatingSummaryResponse.java`: itineraryId, averageRating, ratingCount, starCounts (`Map<Integer, Long>`).
- `UserRatingStatusResponse.java`: itineraryId, rated, score, ratingId, updatedAt.

### Phase 3: Service Layer Implementation
- Interface: `service/RatingService.java`
- Implementation: `service/impl/RatingServiceImpl.java`
  - Methods: `rateItinerary(itineraryId, request, username)`, `getUserRating(itineraryId, username)`, `getRatingSummary(itineraryId)`, `deleteRating(itineraryId, username)`.
  - Transaction boundary: `@Transactional` on mutations, `@Transactional(readOnly = true)` on queries.
  - Concurrency fallback: Catch `DataIntegrityViolationException`.

### Phase 4: Controller Layer & Security Whitelist
- Create `controller/RatingController.java` (`@RequestMapping("/api/itineraries/{itineraryId}/ratings")`).
- Update `security/SecurityConfig.java`:
  - Add `requestMatchers(HttpMethod.GET, "/api/itineraries/{id:[0-9]+}/ratings").permitAll()` to public list.

### Phase 5: Automated Testing
- Create `src/test/java/.../RatingControllerTest.java` with 15+ comprehensive test cases.
- Execute: `./mvnw.cmd test -Dtest=RatingControllerTest`.

### Phase 6: Final Integration with `ItineraryDetailResponse`
*(Execute in coordination with Member 2 after both test suites pass)*
- Add `private Integer userRating;` to `ItineraryDetailResponse.java`.
- Update `ItineraryServiceImpl.getItineraryDetail()` to populate `userRating`.

---

## 7. Expected Files to Create / Modify

### Files to CREATE (Member 1 Exclusive):
1. `backend/src/main/java/.../dto/request/RateItineraryRequest.java`
2. `backend/src/main/java/.../dto/response/RatingResponse.java`
3. `backend/src/main/java/.../dto/response/RatingSummaryResponse.java`
4. `backend/src/main/java/.../dto/response/UserRatingStatusResponse.java`
5. `backend/src/main/java/.../service/RatingService.java`
6. `backend/src/main/java/.../service/impl/RatingServiceImpl.java`
7. `backend/src/main/java/.../controller/RatingController.java`
8. `backend/src/test/java/.../RatingControllerTest.java`

### Files to MODIFY:
1. `backend/src/main/java/.../repository/RatingRepository.java` (Exclusive to Member 1)
2. `backend/src/main/java/.../security/SecurityConfig.java` (Exclusive to Member 1 for whitelist)
3. `backend/src/main/java/.../repository/ItineraryRepository.java` (SHARED with Member 2 — add only `ratingCount` queries at end of interface)
4. `backend/src/main/java/.../dto/response/ItineraryDetailResponse.java` (SHARED with Member 2 — add `userRating` field during Phase 6 integration)
5. `backend/src/main/java/.../service/impl/ItineraryServiceImpl.java` (SHARED with Member 2 — populate `userRating` during Phase 6 integration)

---

## 8. Testing Strategy & Test Cases

Integration test suite `RatingControllerTest` must cover:

| # | Test Method Name | Description | Expected HTTP Status |
|:---|:---|:---|:---|
| 1 | `rateItinerary_Success_FirstTime` | First-time rating submits 5 stars; increments counter | `201 Created` |
| 2 | `rateItinerary_Success_ReRating` | Updating score from 5 to 4; counter unchanged | `200 OK` |
| 3 | `rateItinerary_SelfRating_Returns400` | Author rates own itinerary; rejected with message | `400 Bad Request` |
| 4 | `rateItinerary_InvalidScore_Zero_Returns400` | Score = 0 rejected by validation | `400 Bad Request` |
| 5 | `rateItinerary_InvalidScore_Six_Returns400` | Score = 6 rejected by validation | `400 Bad Request` |
| 6 | `rateItinerary_PrivateItinerary_Returns404` | Rating another user's private itinerary returns 404 | `404 Not Found` |
| 7 | `rateItinerary_DeletedItinerary_Returns404` | Rating deleted itinerary returns 404 | `404 Not Found` |
| 8 | `rateItinerary_Unauthenticated_Returns401` | Missing JWT token returns 401 | `401 Unauthorized` |
| 9 | `rateItinerary_BannedUser_Returns403` | Banned user blocked | `403 Forbidden` |
| 10 | `getUserRating_WhenRated_ReturnsScore` | Queries `/me`, returns rated=true and score | `200 OK` |
| 11 | `getUserRating_WhenNotRated_ReturnsRatedFalse` | Queries `/me` when not rated; returns rated=false | `200 OK` |
| 12 | `getRatingSummary_Public_ReturnsBreakdown` | Guest queries public summary; returns AVG & star counts | `200 OK` |
| 13 | `deleteRating_Success_Returns200` | User deletes rating; counter decremented, AVG updated | `200 OK` |
| 14 | `deleteRating_NotRated_Returns404` | Deleting non-existent rating returns 404 | `404 Not Found` |
| 15 | `concurrentRating_HandledIdempotently` | Simultaneous duplicate requests handled safely | `201 Created` / `200 OK` |

---

## 9. Dependencies & Shared File Coordination

### 9.1 Shared File Ownership Matrix & Git Protocol
> [!CAUTION]
> **Git Conflict Reality & Ownership:** Appending lines to the bottom of the same file on two diverging feature branches causes Git merge conflicts (`<<<<<<< HEAD ... ======= ... >>>>>>>`). Appending methods to the bottom does NOT guarantee clean merges. Ownership and branch sequencing are defined as follows:

| File Path | Owner | Permitted Editors | Phase 1–5 Rule | Joint Integration Rule |
| :--- | :--- | :--- | :--- | :--- |
| `SecurityConfig.java` | **Member 1** | Member 1 ONLY | Member 1 whitelists `GET /api/itineraries/{id:[0-9]+}/ratings`. Member 2 touches 0 lines. | Frozen |
| `ItineraryRepository.java` | **Member 1** | Member 1 first, then Member 2 | Member 1 adds `incrementRatingCount`, `decrementRatingCount` on `feature/rating-api` and merges to `develop` first. Member 2 rebases after PR merge. | Verified Clean |
| `ItineraryDetailResponse.java` | **Member 2** | Member 2 (Joint Lead) | **FROZEN**. Member 1 does not touch this file during Phase 1–5. | Joint branch `feature/social-integration` adds `userRating`, `isFavorited`, `isSaved`. |
| `ItineraryServiceImpl.java` | **Member 2** | Member 2 (Joint Lead) | **FROZEN**. Member 1 does not touch `getItineraryDetail()` during Phase 1–5. | Joint branch populates contextual fields. |

### 9.2 Branch Handover Protocol & Git Rebase Flow
1. **Member 1 Branch (`feature/rating-api`):**
   - Implements Rating Repository, DTOs, Service, Controller, and `RatingControllerTest` (15 planned test cases).
   - Modifies `SecurityConfig.java` and `ItineraryRepository.java`.
   - Opens PR to `develop`. Upon green CI, **merges first** into `develop`.
2. **Member 2 Rebase & Conflict Resolution Flow:**
   - Member 2 fetches `origin` and rebases `feature/favorite-saved-api` onto `origin/develop`:
     ```powershell
     git fetch origin
     git checkout feature/favorite-saved-api
     git rebase origin/develop
     ```
   - In case Git pauses with a merge conflict in `ItineraryRepository.java`:
     1. Member 2 inspects `git status` to identify conflicting markers.
     2. Resolves conflict manually by preserving **BOTH** Member 1's rating counter queries and Member 2's favorite counter queries.
     3. Stages the file: `git add backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryRepository.java`.
     4. Continues rebase: `git rebase --continue` (DO NOT commit).
   - Member 2 runs local regression verification (`./mvnw.cmd test` ensuring 157 baseline + new tests pass) before pushing with `--force-with-lease` and merging second into `develop`.
3. **Joint Integration (Phase 6 / Joint Phase 9):**
   - Member 2 cuts `feature/social-integration` from `develop`.
   - Both members verify contextual detail enrichment and run full regression tests.

---

## 10. Integration Requirements (Phase 6 / Joint Phase 9)

After both `feature/rating-api` and `feature/favorite-saved-api` pass independent tests and merge to `develop`:
1. On `feature/social-integration`, open `ItineraryDetailResponse.java` and declare:
   ```java
   private Boolean isFavorited;
   private Boolean isSaved;
   private Integer userRating;
   ```
2. In `ItineraryServiceImpl.getItineraryDetail()`, if `currentUsername != null`, resolve `userRating`:
   ```java
   Integer userRating = ratingRepository.findByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), id)
           .map(Rating::getScore)
           .orElse(null);
   ```
3. Verify existing `ItineraryControllerTest` continues to pass.

---

## 11. Acceptance Criteria

1. ✅ Authenticated user can submit rating (1..5 stars), receiving `201 Created` on first submit and `200 OK` on re-rating.
2. ✅ Author rating own itinerary receives `400 Bad Request` (`"Bạn không thể tự đánh giá lịch trình của chính mình"`).
3. ✅ Public users (including guests) can query `/api/itineraries/{id}/ratings` and receive average rating and star distribution.
4. ✅ Authenticated user can query `/api/itineraries/{id}/ratings/me` and delete their rating via `DELETE`.
5. ✅ `ratingCount` increments/decrements atomically without drift.
6. ✅ All 15+ test cases in `RatingControllerTest` pass with 0 errors and 0 failures.

---

## 12. Implementation Checklist (Member 1)

- [ ] **Phase 1: Repository Layer**
  - [ ] Add query methods to `RatingRepository.java`.
  - [ ] Add atomic increment/decrement queries to `ItineraryRepository.java`.
- [ ] **Phase 2: DTOs & Validation**
  - [ ] Create `RateItineraryRequest.java`.
  - [ ] Create `RatingResponse.java`.
  - [ ] Create `RatingSummaryResponse.java`.
  - [ ] Create `UserRatingStatusResponse.java`.
- [ ] **Phase 3: Service Layer**
  - [ ] Create `RatingService.java` interface.
  - [ ] Implement `RatingServiceImpl.java` (self-rating check, upsert, delete, concurrency fallback).
- [ ] **Phase 4: Controller & Security**
  - [ ] Implement `RatingController.java`.
  - [ ] Add public GET matcher to `SecurityConfig.java`.
- [ ] **Phase 5: Automated Tests**
  - [ ] Write `RatingControllerTest.java` (15 tests).
  - [ ] Run test suite: `./mvnw.cmd test -Dtest=RatingControllerTest` (100% pass).
- [ ] **Phase 6: Integration**
  - [ ] Coordinate with Member 2 to add `userRating` to `ItineraryDetailResponse` & `ItineraryServiceImpl`.
  - [ ] Run full regression suite: `./mvnw.cmd test`.

---

## 13. Handover Requirements

Upon finishing Phase 5, Member 1 must provide:
1. Git branch name / diff containing exclusively Rating files.
2. Proof of test execution: `./mvnw.cmd test -Dtest=RatingControllerTest` results.
3. Confirmation of readiness for Phase 6 joint integration.

