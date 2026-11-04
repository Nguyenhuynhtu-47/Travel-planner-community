# Implementation Plan 02: Favorite & Saved Itinerary APIs with Mobile "Bộ sưu tập" UI Integration

**Document Reference:** `plan/04-favorite-saved-api-plan.md`  
**Location:** `Travel_Planner/docs/plan/04-favorite-saved-api-plan.md`  
**Creation Date:** 2026-11-04  
**Last Updated:** 2026-11-04 (Final Polish: 10 New vs 1 Existing Endpoint, Atomic Counter Transactionality, Idempotency Edge Cases, Multi-Platform Back Interception & Git Conflict Handling)  
**Author / Technical Lead:** Senior Software Architect & Technical Lead  
**Assignee:** Member 2 (Favorite & Saved Backend Slice + Mobile Collection UI Integration Lead)  
**Active Working Branch:** `develop` (Changes reside strictly in local Working Tree, uncommitted and unpushed)  
**Scope:** Full-Stack Vertical Feature Slice:
- **Backend:** Repositories ➔ DTOs ➔ Services ➔ Controllers ➔ Integration Tests
- **Mobile Client:** Repositories ➔ State Notifiers ➔ Collection Screen ➔ Navigation Integration ➔ Widget Tests  
**Parent Plan:** [`plan/02-backend-social-interaction-plan.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/plan/02-backend-social-interaction-plan.md)  
**Target Milestones:** Phase 2 Tasks P2-F1, P2-SA1, P2-F2, P2-SA2  

---

## 1. Objectives & Scope

### 1.1 Objectives
1. **Favorite Backend API (Strictly 3 NEW Endpoints):**
   - Provide idempotent endpoints to favorite (like), unfavorite (unlike), and retrieve the authenticated user's favorited itineraries with silent filtering.
   - Maintain `favoriteCount` with concurrency-safe atomic database increments and decrements, executed **strictly upon physical record insertion/deletion**.
   - Enforce author self-favorite prohibition (`400 Bad Request`).
   - Remove redundant `GET /favorites/status` endpoint (status is natively provided by `ItineraryDetailResponse`).
2. **Saved Itinerary Backend API (Strictly 3 NEW Endpoints):**
   - Implement exactly the **three agreed non-redundant endpoints**:
     - `GET /api/user/saved-itineraries`
     - `POST /api/itineraries/{itineraryId}/save`
     - `DELETE /api/itineraries/{itineraryId}/save`
   - **Author Self-Save Requirement & Consistency:**
     - Authors **ARE PERMITTED** to save their own itineraries, **provided the itinerary is currently `ACTIVE` and `PUBLIC`**.
     - If an author attempts to save their own `PRIVATE` or `HIDDEN` itinerary, the request is rejected with `400 Bad Request` (`"Chỉ có thể lưu các lịch trình đang ở trạng thái công khai (PUBLIC). Vui lòng công khai lịch trình trước khi lưu vào Bộ sưu tập."`). (Drafts and private itineraries are managed under Tab 5 Profile ➔ "Lịch trình của tôi").
     - If another user attempts to save a private itinerary, return `404 Not Found`.
   - **Silent Filtering & Data Preservation:**
     - Query silently filters out source itineraries that are not `ACTIVE` and `PUBLIC`.
     - Underlying record in `saved_itineraries` is **never deleted** upon source soft-delete or hide; restored itineraries automatically reappear.
3. **Endpoint Architecture Breakdown (10 NEW vs 1 EXISTING):**
   - Across the entire Social Interaction feature, there are **10 NEW REST endpoints** built from scratch:
     - 4 Rating endpoints (`POST /ratings`, `GET /ratings`, `GET /ratings/me`, `DELETE /ratings`) — Member 1.
     - 3 Favorite endpoints (`GET /user/favorites`, `POST /favorites`, `DELETE /favorites`) — Member 2.
     - 3 Saved endpoints (`GET /user/saved-itineraries`, `POST /save`, `DELETE /save`) — Member 2.
   - AND **1 EXISTING endpoint** (`GET /api/itineraries/{id}`), which already exists and passes tests in `ItineraryController.java`, is enriched during **Phase 9 Joint Integration** with `isFavorited`, `isSaved`, and `userRating`.
4. **Mobile Bottom Navigation Architecture:**
   - Maintain the standard **5-tab bottom navigation bar** (`MainNavigationShell`):
     1. `Khám phá` (Explore - default index 0)
     2. `Cộng đồng` (Community - index 1)
     3. `Tạo lịch trình` (Create Itinerary - center action index 2)
     4. `Bộ sưu tập` (Collection - index 3, adjusted from "Đã lưu")
     5. `Cá nhân` (Profile / Hồ sơ cá nhân - index 4)
   - Do **NOT** add a 6th bottom navigation tab.
   - Keep the existing **Cá nhân / Hồ sơ cá nhân** (Profile) tab completely intact.
5. **Mobile "Bộ sưu tập" (Collection) Screen:**
   - Rename Tab 4 from **"Đã lưu"** to **"Bộ sưu tập"** (`Icons.collections_bookmark_outlined` / `Icons.collections_bookmark`).
   - Inside the Collection screen, provide two dedicated sub-views via Segmented Control / TabBar:
     - **"Đã lưu" (Bookmark):** Displays itineraries saved via `POST /api/itineraries/{id}/save`.
     - **"Yêu thích" (Heart):** Displays itineraries favorited via `POST /api/itineraries/{id}/favorites`.
   - Robust immutable pagination: separate generation counters (`_savedGeneration`, `_favoriteGeneration`), intra/inter-page deduplication matching backend `PageResponse` exactly, and preserving data on load-more errors.
   - Retain independent scroll positions across sub-tabs via `PageStorageKey`.
   - Support direct unbookmark and unfavorite actions from cards, updating UI **strictly after API success**, with informational SnackBar (**NO Undo button**).
6. **Cross-Screen State Synchronization (`SocialStateUpdate`):**
   - Tri-state semantics (`true`, `false`, `null` where `null` means no change).
   - Multi-platform back interception across UI Back button, hardware Back, and system edge swipe gestures (`PopScope`), with documented platform limitations and test procedures.

### 1.2 Scope & Test Status Delineation
- **AUDITED REPOSITORY BASELINE (Session 83 Live Test Execution):**
  - **157 / 157 Backend tests passing** (`mvnw.cmd test` in 44.8s). Regression guard.
  - **305 / 305 Mobile tests passing** (`flutter test` in 43.0s). Regression guard.
  - **39 / 39 Web tests passing** (`flutter test` in 14.0s). Regression guard.
  - *Note: In Sessions 84 and 85, no automated test commands were re-run because work was strictly confined to plan documentation without modifying application source code.*
- **IN SCOPE (PLANNED TASKS FOR MEMBER 2):**
  - **Backend (Member 2 Exclusive):**
    - `FavoriteRepository` and `SavedItineraryRepository` query extensions.
    - Atomic counter operations in `ItineraryRepository` (`incrementFavoriteCount`, `decrementFavoriteCount`).
    - DTOs: `FavoriteResponse`, `SavedItineraryResponse`.
    - Services: `FavoriteService`, `FavoriteServiceImpl`, `SavedItineraryService`, `SavedItineraryServiceImpl`.
    - Controllers: `FavoriteController` (strictly 3 endpoints), `SavedItineraryController` (strictly 3 endpoints).
    - **Planned Backend Automated Tests:** `FavoriteControllerTest` (11 test cases to implement), `SavedItineraryControllerTest` (12 test cases to implement).
  - **Mobile Client (Member 2 as Integration Lead):**
    - Repositories: `CollectionRepository` consuming both Saved and Favorite API endpoints.
    - State Management: `CollectionNotifier` (`ChangeNotifier`) with immutable `SubListState` containers for `savedState` and `favoriteState`.
    - Presentation: `CollectionScreen` with top AppBar, Segmented Control, sub-list views, `ItineraryCard` reuse, `AppEmptyState`, `AppErrorState`.
    - Cross-Screen Sync: Synchronize states with Explore and Detail screens via `PopScope` and `SocialStateUpdate`.
    - Shell Integration: update Tab 4 in `MainNavigationShell.dart`.
    - **Planned Mobile Widget Tests:** `collection_screen_test.dart` (12 test cases to implement) and update `bottom_navigation_test.dart`.
  - **Joint Integration (Member 2 + Member 1 in Phase 9):**
    - Enrich existing `ItineraryDetailResponse` with `isFavorited` and `isSaved` in `ItineraryServiceImpl.getItineraryDetail()`.
- **EXPLICITLY OUT OF SCOPE:**
  - Rating API backend and dynamic average engine (assigned to Member 1 in Plan 03).
  - Web Admin moderation screens (Phase 4).
  - Modifying `ProfileScreen.dart` (retained as personal profile management).
  - Standalone `GET .../favorites/status` and `GET .../save/status` endpoints (unnecessary and eliminated).
  - Implementing full Community social feed or follow-graph features.

---

## 2. Codebase Audit & Architectural Reality

### 2.1 Bottom Navigation Bar Reality (`main_navigation_shell.dart`)
Inspection of `Travel_Planner/frontend/mobile/lib/shared/navigation/main_navigation_shell.dart` confirms:
- The shell uses an `IndexedStack` with exactly 5 destinations:
  ```dart
  IndexedStack(
    index: _currentIndex,
    children: [
      ExploreScreen(...),           // Index 0: Khám phá
      const CommunityScreen(),       // Index 1: Cộng đồng
      CreateItineraryScreen(...),    // Index 2: Tạo lịch trình
      const SavedItinerariesScreen(),// Index 3: Đã lưu -> to be replaced by CollectionScreen
      ProfileScreen(...),            // Index 4: Hồ sơ / Cá nhân
    ],
  )
  ```
- Tab 4 (`SavedItinerariesScreen`) is currently a static placeholder displaying `AppEmptyState`.
- Adjusting Tab 4 into "Bộ sưu tập" with two sub-tabs ("Đã lưu" and "Yêu thích") naturally accommodates both interaction types without adding a 6th bottom navigation tab.

### 2.2 Community Tab Reality & Scope Boundary
Inspection of `CommunityScreen.dart`, `Follow.java`, `FollowRepository.java`, and `Travel_Planner_Function_Specification.md` Section 10 confirms:

| Layer | Implemented Reality | Specification Status | Gap Analysis |
| :--- | :--- | :--- | :--- |
| **Mobile UI** | `CommunityScreen.dart` renders `AppEmptyState`. | Spec Section 10 mentions public profile view, follow/unfollow, and activity feed. | Placeholder only. No UI feed or interaction cards exist. |
| **Backend Entity** | `Follow.java` exists with composite unique constraint `(follower_id, following_id)`. | Required for user following. | Entity exists and is seeded with sample relationships in `DataSeeder.java`. |
| **Backend Repo** | `FollowRepository.java` exists with follower/following list and count queries. | Basic JPA interface exists. | Ready for service consumption, but no service layer exists. |
| **Backend Service & Controller** | **None.** No `FollowService` or `FollowController` exists in the codebase. | Spec notes: *"Cần xác nhận: bảng tin hoạt động, thông báo người theo dõi mới và chia sẻ liên kết ngoài có thuộc phạm vi phiên bản hiện tại không."* | Missing completely. |

> [!IMPORTANT]
> **Community Scope Policy:**
> 1. Tab 2 (`Cộng đồng`) **REMAINS** in the Bottom Navigation Bar at index 1 to avoid breaking UI layout or test suites.
> 2. This plan **DOES NOT** invent or expand Community features. Community features remain in placeholder status pending formal clarification from the course instructor / product owner.

---

## 3. Database & Entity Specifications

### 3.1 Entity Models: `Favorite.java` & `SavedItinerary.java`

#### `Favorite.java` (`Travel_Planner.Travel_Planner.model.Favorite`):
```java
@Entity
@Table(name = "favorites", uniqueConstraints = {
    @UniqueConstraint(name = "uk_favorite_user_itinerary", columnNames = {"user_id", "itinerary_id"})
})
@Getter @Setter @Builder
public class Favorite {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "favorite_id")
    private Integer favoriteId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
```

#### `SavedItinerary.java` (`Travel_Planner.Travel_Planner.model.SavedItinerary`):
```java
@Entity
@Table(name = "saved_itineraries", uniqueConstraints = {
    @UniqueConstraint(name = "uk_saved_user_itinerary", columnNames = {"user_id", "itinerary_id"})
})
@Getter @Setter @Builder
public class SavedItinerary {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "save_id")
    private Integer saveId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
```

### 3.2 Atomic Denormalized Counter & Transactional Execution Rules
- `Itinerary.favoriteCount` (`Integer`, default `0`, non-null).
- **Execution Condition:**
  - `incrementFavoriteCount` is called **ONLY** when a new `Favorite` entity row is physically created and inserted into MySQL.
  - If a user sends a duplicate favorite request, or if the row already exists, `incrementFavoriteCount` **MUST NOT be called**.
  - `decrementFavoriteCount` is called **ONLY** when an existing `Favorite` row is physically deleted. If the entity did not exist, it **MUST NOT be called**.
- **Transactional Rollback Guard:**
  All mutating service methods MUST be annotated with `@Transactional(rollbackFor = Exception.class)`. If an unexpected exception occurs after counter increment, the database transaction automatically rolls back in its entirety, preventing lost updates or counter drift:
  ```java
  @Modifying
  @Query("UPDATE Itinerary i SET i.favoriteCount = i.favoriteCount + 1 WHERE i.itineraryId = :id")
  void incrementFavoriteCount(@Param("id") Integer id);

  @Modifying
  @Query("UPDATE Itinerary i SET i.favoriteCount = CASE WHEN i.favoriteCount > 0 THEN i.favoriteCount - 1 ELSE 0 END WHERE i.itineraryId = :id")
  void decrementFavoriteCount(@Param("id") Integer id);
  ```

---

## 4. API Specifications (Non-Redundant Contract)

All endpoints require JWT Bearer Authentication (`Authorization: Bearer <jwt_token>`).

### 4.1 Favorite Endpoints (3 NEW Endpoints)

#### 1. Lấy danh sách Favorite (Get User's Favorited Itineraries)
- **Method & Path:** `GET /api/user/favorites`
- **Query Parameters:**
  - `page` (int, default `0`, min `0`)
  - `size` (int, default `10`, min `1`, max `50`)
  - `sort` (string, default `createdAt,desc`)
- **Authentication:** Required (`Bearer <jwt_token>`)
- **Request Body:** None
- **Silent Filter Behavior:** Uses JPQL query joining `Itinerary` where `status = 'ACTIVE'` and `visibility = 'PUBLIC'`. Inactive, soft-deleted, or private itineraries are silently omitted.
- **Success Response (`200 OK`):**
  ```json
  {
    "content": [
      {
        "itineraryId": 1,
        "title": "Khám phá Hà Giang 3N2Đ",
        "location": "Hà Giang",
        "coverImage": "https://res.cloudinary.com/.../hagiang.jpg",
        "totalDays": 3,
        "budget": 2500000.0,
        "theme": "Phượt",
        "viewCount": 150,
        "favoriteCount": 25,
        "ratingCount": 8,
        "averageRating": 4.8,
        "creator": {
          "userId": 2,
          "username": "phuot_thu",
          "fullName": "Trần Văn Phượt",
          "avatarUrl": "https://res.cloudinary.com/.../avatar.jpg"
        }
      }
    ],
    "pageNumber": 0,
    "pageSize": 10,
    "totalElements": 1,
    "totalPages": 1,
    "last": true
  }
  ```
- **Error Responses:**
  - `401 Unauthorized`: Token missing, malformed, or expired.
  - `403 Forbidden`: Account is banned or disabled.

#### 2. Thêm Favorite (Add Favorite / Like)
- **Method & Path:** `POST /api/itineraries/{itineraryId}/favorites`
- **Path Variable:** `itineraryId` (int, required)
- **Authentication:** Required (`Bearer <jwt_token>`)
- **Request Body:** None
- **Validation & Idempotency Rules:**
  - Verify itinerary exists: if not found, return `404 Not Found`.
  - Verify itinerary visibility: must be `ACTIVE` and `PUBLIC`. Otherwise return `404 Not Found`.
  - **Self-Favorite Blocked:** If `itinerary.getUser().getUserId().equals(currentUser.getUserId())`, throw `BadRequestException("Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích")`.
  - **Idempotency & Concurrent Duplicates:**
    - Service first checks `favoriteRepository.existsByUser_UserIdAndItinerary_ItineraryId(userId, itineraryId)`.
    - If already favorited: return `200 OK` with `favorited: true` without incrementing counter.
    - If newly favorited: insert `Favorite`, execute `incrementFavoriteCount(itineraryId)`, return `201 Created`.
    - If two concurrent requests hit MySQL simultaneously, one commits while the other triggers `uk_favorite_user_itinerary`, throwing `DataIntegrityViolationException`. The service catches this exception, performs a fallback query for the committed row, and returns `200 OK` without double incrementing.
- **Success Response:**
  - `201 Created` (newly favorited) or `200 OK` (already favorited)
  ```json
  {
    "itineraryId": 1,
    "favorited": true,
    "favoriteCount": 26
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: User attempts to favorite their own itinerary (`"Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"`).
  - `401 Unauthorized`: Missing or invalid token.
  - `404 Not Found`: Itinerary not found or not active/public (`"Không tìm thấy lịch trình"`).

#### 3. Bỏ Favorite (Remove Favorite / Unlike)
- **Method & Path:** `DELETE /api/itineraries/{itineraryId}/favorites`
- **Path Variable:** `itineraryId` (int, required)
- **Authentication:** Required (`Bearer <jwt_token>`)
- **Request Body:** None
- **Validation & Business Rules:**
  - Verify itinerary exists: if not found, return `404 Not Found`.
  - **Idempotency:** If `Favorite` record exists, delete it, execute `decrementFavoriteCount(itineraryId)` (guarded at 0), and return `200 OK`.
  - If no record exists, return `200 OK` with `favorited: false` without decrementing.
- **Success Response (`200 OK`):**
  ```json
  {
    "itineraryId": 1,
    "favorited": false,
    "favoriteCount": 25
  }
  ```
- **Error Responses:**
  - `401 Unauthorized`: Missing or invalid token.
  - `404 Not Found`: Itinerary does not exist (`"Không tìm thấy lịch trình"`).

---

### 4.2 Saved Itinerary Endpoints (3 NEW Endpoints)

#### 1. Lấy danh sách Saved (Get User's Saved Itineraries)
- **Method & Path:** `GET /api/user/saved-itineraries`
- **Query Parameters:**
  - `page` (int, default `0`, min `0`)
  - `size` (int, default `10`, min `1`, max `50`)
  - `sort` (string, default `createdAt,desc`)
- **Authentication:** Required (`Bearer <jwt_token>`)
- **Request Body:** None
- **Silent Filtering & Data Preservation Behavior:**
  - Query uses JPQL JOIN:
    ```sql
    SELECT s.itinerary FROM SavedItinerary s
    WHERE s.user.userId = :userId
      AND s.itinerary.status = 'ACTIVE'
      AND s.itinerary.visibility = 'PUBLIC'
      AND s.itinerary.user.status = 'ACTIVE'
    ORDER BY s.createdAt DESC
    ```
  - Soft-deleted (`DELETED`), hidden (`HIDDEN`), or private (`PRIVATE`) itineraries are **silently omitted** from the response list.
  - The record in `saved_itineraries` is **never deleted**. If the itinerary is restored to `ACTIVE + PUBLIC`, it automatically reappears in the user's saved list.
- **Success Response (`200 OK`):** `PageResponse<ItinerarySummaryResponse>`.
- **Error Responses:**
  - `401 Unauthorized`: Token missing, malformed, or expired.
  - `403 Forbidden`: Account is banned or disabled.

#### 2. Thêm Saved (Save Itinerary / Bookmark)
- **Method & Path:** `POST /api/itineraries/{itineraryId}/save`
- **Path Variable:** `itineraryId` (int, required)
- **Authentication:** Required (`Bearer <jwt_token>`)
- **Request Body:** None
- **Author Self-Save, Visibility & Idempotency Rules:**
  - Verify itinerary exists: if not found, return `404 Not Found`.
  - **Public Requirement:** The target itinerary **must be currently `ACTIVE` and `PUBLIC`**.
  - **Author Self-Save on Draft/Private:** If the author attempts to save their own itinerary while it is `PRIVATE` or `HIDDEN`, reject with `400 Bad Request`:
    `"Chỉ có thể lưu các lịch trình đang ở trạng thái công khai (PUBLIC). Vui lòng công khai lịch trình trước khi lưu vào Bộ sưu tập."`
    *(Rationale: Authors manage their private/draft itineraries via Profile ➔ "Lịch trình của tôi". Saving a private itinerary that would immediately be hidden by the silent filter violates UX transparency).*
  - **Non-Author on Private/Hidden:** Return `404 Not Found` (`"Không tìm thấy lịch trình"`).
  - **Author Self-Save on Public Itinerary:** **PERMITTED** (`201 Created` / `200 OK`).
  - **Idempotency & Concurrent Duplicates:**
    - Service checks `savedItineraryRepository.findByUser_UserIdAndItinerary_ItineraryId(userId, itineraryId)`.
    - If already saved, return `200 OK` with existing `saveId`.
    - If newly saved, insert into `saved_itineraries` and return `201 Created`.
    - Concurrent duplicates hitting `uk_saved_user_itinerary` throw `DataIntegrityViolationException`, which is caught to return `200 OK` with the existing `saveId`.
- **Success Response:**
  - `201 Created` (newly saved) or `200 OK` (already saved)
  ```json
  {
    "saveId": 12,
    "itineraryId": 1,
    "saved": true,
    "savedAt": "2026-11-04T10:20:00"
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Author attempts to save own private/hidden itinerary.
  - `401 Unauthorized`: Missing or invalid token.
  - `404 Not Found`: Itinerary not found or inaccessible private itinerary.

#### 3. Bỏ Saved (Remove Saved Itinerary / Unbookmark)
- **Method & Path:** `DELETE /api/itineraries/{itineraryId}/save`
- **Path Variable:** `itineraryId` (int, required)
- **Authentication:** Required (`Bearer <jwt_token>`)
- **Request Body:** None
- **Validation & Business Rules:**
  - **Idempotency:** If `SavedItinerary` record exists for `(userId, itineraryId)`, delete it and return `200 OK`.
  - If no record exists, return `200 OK` with `saved: false`.
- **Success Response (`200 OK`):**
  ```json
  {
    "saveId": null,
    "itineraryId": 1,
    "saved": false,
    "savedAt": null
  }
  ```
- **Error Responses:**
  - `401 Unauthorized`: Missing or invalid token.
  - `404 Not Found`: Itinerary does not exist.

---

## 5. Mobile UI & Interaction Architecture: "Bộ sưu tập" (Collection)

### 5.1 Navigation Integration (`main_navigation_shell.dart`)
- **Position:** Index 3 in Bottom Navigation Bar.
- **Label / Tooltip:** `'Bộ sưu tập'` (Accessibility label & semantics).
- **Icons:**
  - Inactive: `Icons.collections_bookmark_outlined`
  - Active: `Icons.collections_bookmark`
- **Destination Screen:** `CollectionScreen(authNotifier: widget.authNotifier)` replacing `SavedItinerariesScreen`.

### 5.2 Immutable State Management & Generation-Guarded Pagination (`CollectionNotifier`)

#### 1. Immutable SubListState Definition:
```dart
class SubListState {
  final List<ItinerarySummary> items;
  final int currentPage;
  final int totalPages;
  final int totalElements;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final String? loadMoreErrorMessage;

  const SubListState({
    this.items = const [],
    this.currentPage = 0,
    this.totalPages = 1,
    this.totalElements = 0,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.loadMoreErrorMessage,
  });

  SubListState copyWith({
    List<ItinerarySummary>? items,
    int? currentPage,
    int? totalPages,
    int? totalElements,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    String? loadMoreErrorMessage,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return SubListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalElements: totalElements ?? this.totalElements,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loadMoreErrorMessage: clearLoadMoreError ? null : (loadMoreErrorMessage ?? this.loadMoreErrorMessage),
    );
  }
}
```

#### 2. Request Generation Invalidation & Exact Model Mapping:
- **Exact JSON Parsing:** Utilizes existing `PageResult<ItinerarySummary>.fromJson` parsing exact backend fields:
  - `content`: List of items
  - `pageNumber` / `page`: int
  - `pageSize` / `size`: int
  - `totalElements`: int
  - `totalPages`: int
  - `last`: boolean
- **Separate Generation Counters:**
  ```dart
  int _savedGeneration = 0;
  int _favoriteGeneration = 0;
  ```
- **Stale Response Invalidation:**
  ```dart
  Future<void> fetchSavedItineraries({bool isRefresh = false}) async {
    final activeGeneration = ++_savedGeneration; // Invalidates any pending loadMore requests
    ...
    final pageResult = await _repository.getSavedItineraries(...);
    if (activeGeneration != _savedGeneration) return; // Drop stale response
    ...
  }
  ```
- **Two-Pass Deduplication on Append:**
  ```dart
  // Step A: Deduplicate items inside incoming page
  final seenInPage = <int>{};
  final distinctPageItems = pageResult.content.where((item) => seenInPage.add(item.itineraryId)).toList();

  // Step B: Deduplicate against existing state
  final existingIds = state.items.map((e) => e.itineraryId).toSet();
  final newUniqueItems = distinctPageItems.where((item) => !existingIds.contains(item.itineraryId)).toList();

  // Step C: Produce new immutable state
  final combinedItems = List<ItinerarySummary>.unmodifiable([...state.items, ...newUniqueItems]);
  ```
- **Load More Error Preservation:**
  If `loadMore()` catches an exception:
  ```dart
  _savedState = _savedState.copyWith(
    isLoadingMore: false,
    loadMoreErrorMessage: 'Không thể tải thêm lịch trình. Chạm để thử lại.',
  );
  notifyListeners();
  ```
  **Existing loaded items are preserved 100%.**
- **Pull-To-Refresh Handling:**
  Keeps existing items visible under `RefreshIndicator`. Replaces items with page 0 only upon network success. On failure, preserves existing items and displays an error SnackBar.

### 5.3 Cross-Screen State Synchronization Architecture (`SocialStateUpdate`)

#### 1. Tri-State Semantics Definition:
```dart
class SocialStateUpdate {
  final int itineraryId;
  final bool? isFavorited;     // null = unchanged; true = favorited; false = unfavorited
  final int? favoriteCount;    // null = unchanged; int = updated count
  final bool? isSaved;         // null = unchanged; true = saved; false = unsaved
  final int? userRating;       // null = unchanged; 1..5 = rated; 0 = rating deleted
  final double? averageRating; // null = unchanged
  final int? ratingCount;      // null = unchanged

  const SocialStateUpdate({
    required this.itineraryId,
    this.isFavorited,
    this.favoriteCount,
    this.isSaved,
    this.userRating,
    this.averageRating,
    this.ratingCount,
  });

  bool get hasChanges =>
      isFavorited != null ||
      favoriteCount != null ||
      isSaved != null ||
      userRating != null ||
      averageRating != null ||
      ratingCount != null;
}
```

#### 2. Multi-Platform Back Navigation Interception & Edge-Swipe Nuances:
To guarantee that `SocialStateUpdate` is returned regardless of how the user exits `ItineraryDetailScreen`:

- **Platform Reality & Known Flutter Limitations:**
  - **AppBar UI Back Button:** Explicit, 100% deterministic cross-platform. Calls `Navigator.of(context).pop(_latestSocialUpdate)`.
  - **Android System Back (Hardware button & system back gesture):** Handled via `PopScope`. On Android 13/14+ predictive back, `canPop: false` cancels the OS-level predictive window animation.
  - **iOS Edge-Swipe Back Gesture (`CupertinoPageRoute`):**
    > [!WARNING]
    > In Flutter, wrapping a route in `PopScope(canPop: false)` **disables native iOS interactive edge-swipe gestures entirely** because the iOS gesture recognizer detects that the route cannot pop. Furthermore, if `canPop: true` is used, the gesture can be cancelled mid-swipe by the user (releasing finger before crossing the threshold). If an update was dispatched prematurely, it would result in stale state.

- **Resilient Multi-Platform Implementation:**
  Inside `_ItineraryDetailScreenState`:
  ```dart
  SocialStateUpdate _latestSocialUpdate = SocialStateUpdate(itineraryId: widget.itineraryId);

  void _recordSocialChange({bool? isFavorited, int? favoriteCount, bool? isSaved, int? userRating}) {
    _latestSocialUpdate = SocialStateUpdate(
      itineraryId: widget.itineraryId,
      isFavorited: isFavorited ?? _latestSocialUpdate.isFavorited,
      favoriteCount: favoriteCount ?? _latestSocialUpdate.favoriteCount,
      isSaved: isSaved ?? _latestSocialUpdate.isSaved,
      userRating: userRating ?? _latestSocialUpdate.userRating,
    );
  }
  ```
  Wrap with `PopScope`:
  ```dart
  PopScope<SocialStateUpdate>(
    canPop: true, // Preserves native iOS interactive swipe and Android predictive back
    onPopInvokedWithResult: (bool didPop, SocialStateUpdate? result) {
      if (!didPop) return; // Mid-gesture swipe was cancelled by user; DO NOTHING!
      // In Flutter 3.19+, if popped by system gesture, result is null.
      // Fallback: Notify callback or shared coordinator
      widget.onSocialUpdate?.call(_latestSocialUpdate);
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_latestSocialUpdate),
        ),
      ),
      ...
    ),
  )
  ```

- **Required Platform Verification Tests (To run on Simulator / Emulator):**
  1. *Test 1 (AppBar UI):* Tap AppBar back button ➔ verify `SocialStateUpdate` received by caller.
  2. *Test 2 (Android Back):* Execute `tester.binding.handlePopRoute()` ➔ verify update processed.
  3. *Test 3 (iOS Gesture):* Simulate edge swipe drag from `dx: 0 ➔ dx: 300` ➔ verify route pops and update delivered.
  4. *Test 4 (Cancelled Gesture):* Simulate partial drag from `dx: 0 ➔ dx: 60 ➔ dx: 0` ➔ verify route does NOT pop and no update is triggered.
  5. *Test 5 (No Changes):* Open detail, tap back immediately ➔ verify `hasChanges == false` and caller executes zero re-renders.

#### 3. State Ingestion in Explore & Collection:
- **`ExploreScreen`:** Calls `ExploreNotifier.updateSocialStatus(...)` updating the specific card in memory. **Does NOT call `refreshAll()`** (eliminates redundant API calls).
- **`CollectionScreen`:**
  - If `result.isSaved == false`: Removes the item from `savedState.items` in memory.
  - If `result.isFavorited == false`: Removes the item from `favoriteState.items` in memory.
  - If newly saved or favorited from Detail: Marks that tab as `needsRevalidation = true` so it re-fetches cleanly when focused.
- **Direct Collection Actions:**
  - Card unbookmark / unfavorite: Calls DELETE endpoint.
  - **Item removed from UI strictly AFTER `200 OK` is returned.**
  - Shows informational SnackBar (**NO Undo button**).

---

## 6. Shared Files Ownership & Git Protocol

### 6.1 Shared File Ownership Matrix

| File Path | Owner | Permitted Editors | Independent Phases (Phases 1–8) | Joint Phase 9 |
| :--- | :--- | :--- | :--- | :--- |
| `SecurityConfig.java` | **Member 1** | Member 1 ONLY | Member 1 whitelists public rating summary. Member 2 touches 0 lines. | Frozen |
| `ItineraryRepository.java` | **Member 1** | Member 1 first, then Member 2 | Member 1 commits rating atomic queries on `feature/rating-api` and merges to `develop` first. Member 2 rebases `feature/favorite-saved-api` onto `develop` before adding favorite queries. | Verified Clean |
| `ItineraryDetailResponse.java` | **Member 2** | Member 2 (Joint Lead) | **FROZEN**. Neither member edits during individual feature slices. | Member 2 enriches `isFavorited`, `isSaved`, `userRating`. |
| `ItineraryServiceImpl.java` | **Member 2** | Member 2 (Joint Lead) | **FROZEN**. Neither member edits `getItineraryDetail()` during individual feature slices. | Member 2 enriches contextual fields in coordination with Member 1. |
| `ProfileScreen.dart` | N/A | NONE | **FROZEN**. Profile remains strictly personal identity and account management. | Frozen |
| `CommunityScreen.dart` | N/A | NONE | **FROZEN**. Community remains placeholder pending formal instructor specification. | Frozen |

### 6.2 Realistic Git Rebase & Conflict Resolution Workflow

> [!CAUTION]
> Git rebase significantly reduces divergence, but **does NOT guarantee 0% conflicts** if adjacent context or method placements overlap. Member 2 must follow this exact verification and conflict resolution procedure:

1. **Member 1 Merges First:**
   Member 1 finishes `feature/rating-api`, verifies 15 tests, opens PR, and merges into `develop`.
2. **Member 2 Rebase Execution:**
   Member 2 runs:
   ```powershell
   git fetch origin
   git checkout feature/favorite-saved-api
   git rebase origin/develop
   ```
3. **Conflict Detection & Inspection:**
   Run `git status`. If Git flags a conflict in `ItineraryRepository.java`:
   - Open `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryRepository.java`.
   - Inspect markers (`<<<<<<< HEAD ... ======= ... >>>>>>>`).
   - Manually merge to preserve **both** Member 1's rating atomic methods (`incrementRatingCount`, `decrementRatingCount`) **and** Member 2's favorite atomic methods (`incrementFavoriteCount`, `decrementFavoriteCount`).
4. **Resolution Staging & Rebase Continuation:**
   ```powershell
   git add Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryRepository.java
   git rebase --continue
   ```
5. **Post-Rebase Verification:**
   Before pushing, run backend regression tests:
   ```powershell
   ./mvnw.cmd test -Dtest=ItineraryRepositoryTest,RatingControllerTest,FavoriteControllerTest
   ```
   Only when tests pass 100% green is the branch pushed to `origin/feature/favorite-saved-api` for PR review.

---

## 7. Implementation Phases (Member 2)

- **Phase 1 (Backend Repositories):** `FavoriteRepository`, `SavedItineraryRepository` (silent filter query), rebase `develop` for `ItineraryRepository`.
- **Phase 2 (Backend DTOs):** `FavoriteResponse`, `SavedItineraryResponse`.
- **Phase 3 (Backend Services):** `FavoriteService/Impl`, `SavedItineraryService/Impl` (author public-save allowed, private-save rejected with 400).
- **Phase 4 (Backend Controllers):** `FavoriteController` (3 endpoints), `SavedItineraryController` (3 endpoints).
- **Phase 5 (Backend Tests):** `FavoriteControllerTest` (11 tests), `SavedItineraryControllerTest` (12 tests).
- **Phase 6 (Mobile Data & State):** `CollectionRepository`, `CollectionNotifier` (immutable `SubListState`, separate generations `_savedGeneration`/`_favoriteGeneration`, two-pass deduplication, error preservation).
- **Phase 7 (Mobile UI):** `CollectionScreen` with SegmentedControl, `PageStorageKey` scroll retention, `PopScope` returning `SocialStateUpdate`.
- **Phase 8 (Mobile Shell & Tests):** Update Tab 4 in `MainNavigationShell.dart`, update `bottom_navigation_test.dart`, implement `collection_screen_test.dart` (12 tests).
- **Phase 9 (Final Joint Integration):** Cut `feature/social-integration`, add detail contextual fields, regression test pass.

---

## 8. Testing Strategy & Test Matrix

### 8.1 Planned Test Cases for Member 2

#### `FavoriteControllerTest` (11 Planned Tests):
1. `addFavorite_success_returns201AndIncrementsCount`
2. `addFavorite_duplicate_idempotent_returns200WithoutDoubleIncrement`
3. `addFavorite_authorSelfFavorite_returns400BadRequest`
4. `addFavorite_nonExistentItinerary_returns404NotFound`
5. `addFavorite_privateItinerary_returns404NotFound`
6. `addFavorite_softDeletedItinerary_returns404NotFound`
7. `removeFavorite_success_returns200AndDecrementsCount`
8. `removeFavorite_whenNotFavorited_idempotent_returns200`
9. `removeFavorite_counterNeverNegative_guardedAtZero`
10. `getUserFavorites_paginated_returnsActivePublicOnly`
11. `favorite_concurrentRequests_handledSafely`

#### `SavedItineraryControllerTest` (12 Planned Tests):
1. `saveItinerary_success_returns201AndSaveId`
2. `saveItinerary_duplicate_idempotent_returns200AndExistingId`
3. `saveItinerary_authorSavesOwnPublicItinerary_success_returns201`
4. `saveItinerary_authorSavesOwnPrivateItinerary_returns400BadRequest`
5. `saveItinerary_nonExistentItinerary_returns404NotFound`
6. `saveItinerary_privateItineraryByOtherUser_returns404NotFound`
7. `removeSavedItinerary_success_returns200`
8. `removeSavedItinerary_whenNotSaved_idempotent_returns200`
9. `getUserSavedItineraries_paginated_returnsSavedList`
10. `getUserSavedItineraries_silentFilter_omitsSoftDeletedAndHidden`
11. `getUserSavedItineraries_dataPreservation_reappearsWhenRestored`
12. `savedItinerary_concurrentRequests_handledSafely`

#### `collection_screen_test.dart` (12 Planned Widget Tests):
1. `CollectionScreen_RendersAppBarAndSegmentedTabs`: Asserts title `"Bộ sưu tập"`, notification bell, and both segments (`Đã lưu`, `Yêu thích`).
2. `CollectionScreen_DefaultTabIsSaved_DisplaysSavedCards`: Asserts saved itineraries are loaded and rendered using `ItineraryCard`.
3. `CollectionScreen_SwitchToFavoriteTab_DisplaysFavoriteCards`: Tapping `"Yêu thích"` switches list and renders favorited cards.
4. `CollectionScreen_IndependentScroll_PreservesOffsets`: Switching between tabs preserves scroll offsets via `PageStorageKey`.
5. `CollectionScreen_EmptyState_SavedTab_ShowsEncouragingMessageAndExploreButton`: Displays `AppEmptyState` with explore action.
6. `CollectionScreen_EmptyState_FavoriteTab_ShowsEncouragingMessage`: Displays `AppEmptyState`.
7. `CollectionScreen_UnbookmarkAction_RemovesCardOnlyAfterApiSuccess`: Card removed strictly after `200 OK`.
8. `CollectionScreen_UnbookmarkAction_ShowsNonUndoableSnackBar`: Asserts informational SnackBar appears with NO "Hoàn tác" button.
9. `CollectionScreen_UnfavoriteAction_RemovesCardOnlyAfterApiSuccess`: Card removed strictly after `200 OK`.
10. `CollectionScreen_Pagination_DeduplicatesIntraAndInterPageItems`: Infinite scroll deduplicates items correctly.
11. `CollectionScreen_Pagination_ErrorRetainsExistingItems`: Network error during load-more preserves all previously loaded items.
12. `BottomNavigationTest_UpdatedForCollectionTab`: Asserts Tab 4 label is `'Bộ sưu tập'`, icon is `Icons.collections_bookmark_outlined`, and navigates to `CollectionScreen`.

---

## 9. Acceptance Criteria

1. ✅ **Backend Favorite:** Authenticated users can favorite and unfavorite public itineraries; author self-favorite is rejected (`400 Bad Request`); `favoriteCount` is updated atomically; strictly 3 endpoints.
2. ✅ **Backend Saved:** Authenticated users can save and unsave itineraries via `POST/DELETE /api/itineraries/{id}/save`; author self-save on public itinerary succeeds (`201 Created`); author self-save on private/hidden itinerary returns `400 Bad Request`; `GET /api/user/saved-itineraries` applies silent filter for `ACTIVE + PUBLIC`.
3. ✅ **Mobile Navigation:** Bottom navigation retains exactly 5 tabs. Tab 4 is named `'Bộ sưu tập'` with `Icons.collections_bookmark_outlined`.
4. ✅ **Mobile Collection Screen:** Displays two independent sub-tabs (`Đã lưu` và `Yêu thích`), each with dedicated list, loading, empty, and error retry states.
5. ✅ **Pagination & Invalidation:** Request generations (`_savedGeneration`, `_favoriteGeneration`) prevent stale overwrites; deduplicates intra-page and inter-page items; preserves data on load-more errors.
6. ✅ **State Synchronization:** `PopScope` intercepts back navigation reliably across gestures and UI buttons; `SocialStateUpdate` updates Explore and Collection in-memory without redundant network refetches.
7. ✅ **Card Actions & SnackBar:** Items are removed ONLY after API success. SnackBar is purely informational with NO Undo button.
8. ✅ **Tests:** 23 backend integration tests pass; all mobile collection widget tests pass; existing 501 baseline tests remain regression-free.
