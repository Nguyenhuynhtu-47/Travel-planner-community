# Travel Planner — Project Status & Next Steps

**Audit Date:** 2026-11-04  
**Auditor:** Senior Software Architect / AI Technical Lead  
**Branch Audited:** `develop` (HEAD: `7d86338`)  
**Methodology:** Actual source code inspection + live test execution. No assumptions from documentation alone.

---

## 1. Verified Test Results (Executed 2026-11-11 — Phase 2.1.1 Final Acceptance)

| Component | Command | Result | Notes |
|:---|:---|:---|:---|
| Backend | `mvnw.cmd test` | **321 / 321 PASS** ✅ | Exit code 0, 0 failures, 0 errors, 0 skipped (includes PlaceNormalization, PlaceService, PlaceController, DataSeeder multi-branch Cases A-F, DestinationConsolidationMigrationRunner real MySQL tests) |
| Mobile | `flutter test` | **364 PASS / 3 FAILED (367 Total)** ⚠️ | Exit code 1; 364 passed, 3 deferred pre-existing tests preserved (`explore_test.dart`, `rating_ui_layout_test.dart`) |
| Web | `flutter test` | **33 / 33 PASS** ✅ | Exit code 0, 0 failures, 0 errors (includes 33 tests in `admin_place_test.dart`) |
| **Total Executed** | | **721 Tests (718 PASS / 3 FAILED)** | Robust multi-layer verification across Backend, Mobile, and Web |

---

## 2. Current Implementation Status

### Module Status Summary

| # | Module | Status | Evidence |
|:--|:---|:---|:---|
| 1 | Authentication & JWT (Register, Login, Me, 401 interception) | **COMPLETED** | `AuthController`, `JwtAuthenticationFilter`, `SecurityConfig`, 21 backend tests, mobile + web auth tests |
| 2 | User Profile (View & Edit own profile, avatar upload) | **COMPLETED** | `ProfileController`, `ProfileServiceImpl`, `ProfileScreen` mobile + web |
| 3 | Explore & Search (keyword, theme, budget, days, rating, pagination, recommendations) | **COMPLETED** | `ItineraryController` GET endpoints, `ExploreScreen`, `ExploreNotifier`, `FilterBottomSheet`, `ItinerarySpecification`, explore + filter tests |
| 4 | Itinerary CRUD (Create, Read, Edit, Delete soft, cover image, ownership) | **COMPLETED** | `ItineraryController`, `ItineraryCrudRepository`, `CreateItineraryScreen`, `EditItineraryScreen`, `MyItinerariesScreen`, CRUD tests |
| 5 | Itinerary Days & Activities (Add/Edit/Delete days + activities, two-pass reorder) | **COMPLETED** | `ItineraryController` day+activity endpoints, `ItineraryDayCard`, `ActivityFormDialog`, `ReorderActivitiesDialog`, day+activity management tests |
| 6 | Destination Catalog | **CONSOLIDATED INTO PLACE CATALOG (Phase 2.1)** | Table `destinations` contracted/dropped; data consolidated into `places`; `activities.canonical_place_id` replaces legacy `destination_id`. |
| 7 | Map Integration — Map Rendering (flutter_map, CARTO Voyager tiles, attribution) | **COMPLETED** | `flutter_map: ^7.0.2` in pubspec, `AppBaseMap`, `AppMapView`, `WebMapView`, map smoke tests |
| 8 | Map Integration — Activity Location Architecture (Authoritative Activity Location Snapshot, Map Picker, backfilled database) | **COMPLETED (Phase 1, 1.1 & 2.1 Final Acceptance)** | `Activity` entity authoritative `location_*` snapshot (unidirectional sync, legacy mirror). `DestinationConsolidationMigrationRunner` with single-connection MySQL advisory locking (`destination_consolidation_lock`), bounded retry, fail-startup protection, coordinate bounds validation, and safe idempotency. `canonical_place_id` (nullable FK to `places.place_id`) links catalog place without overriding snapshot coordinates. Mobile client (`activity_detail.dart`, `activity_form_dialog.dart`, `activity_timeline_item.dart`, `itinerary_day_card.dart`) completely decoupled from Catalog coordinates/names/addresses (`effectiveLocationName` / `effectiveAddress` strictly isolated). 313 Backend tests PASS (exit code 0), 364 Mobile tests PASS (3 pre-existing failed tests preserved, exit code 1), 33 Web tests PASS (exit code 0). |
| 9 | Map Integration — Route Calculation (Direct Activity snapshot waypoint extraction, ORS backend proxy, in-memory cache, Haversine fallback) | **COMPLETED** | `RouteController`, `RouteServiceImpl` (direct snapshot extraction decoupled from Place status), `OpenRouteServiceRoutingProvider`, `RouteRepository`, `ItineraryMapScreen`, route tests |
| 10 | Map Integration — Itinerary Map View (markers, polylines, day-filter, navigation deep-link) | **COMPLETED** | `ItineraryMapScreen`, `ItineraryMapPreviewCard`, `NavigationLauncherHelper`, `ItineraryMapHelper`, map view tests |
| 11 | Place Catalog — Canonical Places, Multi-Provider Mappings, Deduplication, Public & Admin APIs (Phase 2 & 2.1) | **COMPLETED (Phase 2 & 2.1 Final Acceptance)** | `Place` & `PlaceProviderMapping` entities, `PlaceNormalizationService` (Vietnamese diacritics NFD, address abbreviations, protected compound names e.g. Hồ Hoàn Kiếm, chain branch separation >100m, multi-signal confidence score >=0.85), `PlaceService` & `PlaceServiceImpl`, `PlaceController` (`GET /api/places`, `GET /api/places/{id}`), `AdminPlaceController` (`POST/PUT/DELETE /api/admin/places`), `DestinationConsolidationMigrationRunner` (safe single-connection advisory lock `@Order(3)` consolidating 24 destinations and contracting schema). Full Web Admin management in `AdminPlacesScreen`. |
| 12 | Image Upload (Cloudinary, SHA-1 signed, magic bytes check, mobile + web) | **COMPLETED** | `ImageUploadController`, `CloudinaryImageUploadService`, `ImagePickerService`, upload tests |
| 13 | Comments (Read list + Create, paginated, in itinerary detail) | **COMPLETED** | `CommentController`, `CommentServiceImpl`, `CommentsNotifier`, `ItineraryCommentsSection` |
| 14 | Web Admin — Place Management | **COMPLETED (Phase 2.1)** | `AdminPlacesScreen`, `PlaceFormDialog`, `HidePlaceDialog`, `WebMapView`, `PlaceRepository`, 33 admin place web tests passing |
| 14 | Ratings / Star ratings | **NOT IMPLEMENTED** | `Rating` entity + `RatingRepository` exist; no Controller, Service, or mobile UI |
| 15 | Favorites (like itinerary) | **NOT IMPLEMENTED** | `Favorite` entity + `FavoriteRepository` exist; no Controller, Service, or mobile UI |
| 16 | Saved Itineraries | **NOT IMPLEMENTED** | `SavedItinerary` entity + `SavedItineraryRepository` exist; `SavedItinerariesScreen` is a placeholder empty state |
| 17 | Clone / Personalize Itinerary | **NOT IMPLEMENTED** | `original_itinerary_id` and `reuse_count` columns exist in DB; no API or UI |
| 18 | Follow / Social Graph | **NOT IMPLEMENTED** | `Follow` entity + `FollowRepository` exist; `CommunityScreen` is empty state |
| 19 | Notifications | **NOT IMPLEMENTED** | `NotificationsScreen` is a placeholder; no backend entity or API |
| 20 | Web Admin — Dashboard & Statistics | **NOT IMPLEMENTED** | `dashboard/` directory contains only `.gitkeep` |
| 21 | Web Admin — User Management | **NOT IMPLEMENTED** | `users/` directory contains only `.gitkeep`; no backend controller for admin user ops |
| 22 | Web Admin — Itinerary Moderation | **NOT IMPLEMENTED** | `itineraries/` and `moderation/` directories contain only `.gitkeep` |
| 23 | View Another User's Public Profile | **NOT IMPLEMENTED** | No `GET /api/users/{id}/profile` endpoint; only own-profile endpoints exist |
| 24 | Itinerary Visibility Public/Private Toggle | **PARTIALLY COMPLETED** | `visibility` field exists in DB and entity; `CreateItineraryScreen` likely sets default; needs verification that UI exposes toggle |
| 25 | Comment Moderation / Delete | **NOT IMPLEMENTED** | `CommentStatus` enum exists; no admin delete/hide comment API |
| 26 | Password Reset / Email Verification | **NOT IMPLEMENTED** | Flagged "Needs confirmation" in spec; not in backend |

---

## 3. Detailed Gap Analysis

### 3.1. Critical Gaps (Blocking Demonstration)

| Gap | Location | Impact | Recommended Fix |
|:---|:---|:---|:---|
| **Ratings API missing** | Backend (no `RatingController`/`RatingServiceImpl`) | Cannot show star-rating feature; `ratingCount` counter never updates from real data | Implement `POST/DELETE /api/itineraries/{id}/ratings` + `GET` aggregate |
| **Favorites API missing** | Backend (no `FavoriteController`/`FavoriteServiceImpl`) | Cannot show favorite/like feature; `favoriteCount` counter stale | Implement `POST/DELETE /api/itineraries/{id}/favorites` toggle |
| **Saved Itineraries API missing** | Backend (no SavedItinerary controller); Mobile `SavedItinerariesScreen` is empty state | "Đã Lưu" tab in mobile nav shows nothing — a bottom nav dead-end | Implement `POST/DELETE /api/user/saved-itineraries/{id}` + `GET /api/user/saved-itineraries` |
| **API credentials in README** | `Travel_Planner/README.md` lines 11–14 | Cloudinary API Secret + ORS API key exposed in plain text in Git repository | Immediately revoke and rotate credentials; remove from README; document environment variable setup only |

### 3.2. High Priority Gaps (Core Feature Gaps)

| Gap | Location | Impact |
|:---|:---|:---|
| **Clone/Personalize Itinerary** | No API (`POST /api/itineraries/{id}/clone`); schema supports it | Key differentiating feature of the platform; "reuse_count" always zero |
| **CommunityScreen is placeholder** | `community_screen.dart` renders `AppEmptyState` | Entire "Cộng đồng" bottom nav tab is dead |
| **Admin Dashboard** | Web: `dashboard/` empty; no backend stats API | Admin portal has no value beyond destination management |
| **Admin User Management** | Web: `users/` empty; no backend `GET/PUT /api/admin/users` | Cannot ban, unban, or view users from web admin |

### 3.3. Medium Priority Gaps

| Gap | Impact |
|:---|:---|
| **Admin Itinerary Moderation** | Cannot hide/flag/delete community itineraries from web |
| **View Public User Profile** | Cannot navigate to another user's profile from itinerary detail |
| **Comment Delete (own)** | Users cannot delete their own comments |
| **Itinerary visibility toggle UI** | Need to verify `CreateItineraryScreen` / `EditItineraryScreen` exposes PUBLIC/PRIVATE toggle |

### 3.4. Security Issues

| Issue | Severity | Location |
|:---|:---|:---|
| **Cloudinary API Secret + ORS key in README.md** | 🔴 CRITICAL | `Travel_Planner/README.md` lines 11–14; plaintext in Git history |
| **`hibernate.ddl-auto=update` in production** | 🟡 HIGH | `application.properties`; schema managed by Hibernate, no Flyway/Liquibase |
| **JWT secret fallback in properties** | 🟡 MEDIUM | Hardcoded fallback secret in `application.properties` |
| **No Docker / no CI/CD** | 🟡 MEDIUM | No `Dockerfile` or `.github/workflows`; deployment is manual |

### 3.5. Technical Debt

| Item | Location |
|:---|:---|
| Itinerary counter fields (`ratingCount`, `favoriteCount`, `commentCount`) are denormalized and may drift from actual data | `Itinerary.java`; `DataSeeder` syncs them manually but no live triggers |
| `DataSeeder` synchronizes counters by scanning all records in-memory — will degrade as data grows | `DataSeeder.synchronizeItineraryCounters()` |
| Backend test suite requires a live MySQL connection (no H2 in-memory test profile) | `src/test/resources/application.properties` |
| Old development-log entry still references `PlaceholderHomeScreen` and 15/15 tests from early phase | `09-development-log.md` — historical accuracy, not a code issue |
| `12-project-progress-audit.md` already existed (Vietnamese language, written on map branch) — this new document supersedes it for English planning |

---

## 4. Development Roadmap

> Tasks are ordered by dependency chain and priority. All test counts verified against current codebase.

### Phase 1 — Critical Security Fix (1 task, independent)

| Task ID | Task | Priority | Module | Dependencies | Expected Result | Verification | Effort |
|:---|:---|:---|:---|:---|:---|:---|:---|
| P1-S1 | Remove credentials from `README.md`; rotate Cloudinary API Secret and ORS API key; document env-var-only startup | 🔴 Critical | Backend / Ops | None | Credentials no longer in Git history (squash or reset); README shows only `$env:VAR=...` placeholders | `git log -p README.md` shows no secrets; new credentials work | Small |

### Phase 2 — Core Social Interactions (can begin in parallel after P1-S1)

| Task ID | Task | Priority | Module | Dependencies | Expected Result | Verification | Effort |
|:---|:---|:---|:---|:---|:---|:---|:---|
| P2-R1 | Backend: Implement Rating API (`POST /api/itineraries/{id}/ratings`, `DELETE`, `GET` aggregate); update `ratingCount` counter | 🔴 Critical | Backend | None | Users can submit 1–5 star ratings; GET itinerary returns updated `ratingCount` and average | Backend integration test; Postman | Medium |
| P2-R2 | Mobile: Rating UI in `ItineraryDetailScreen` (star widget, loading state, own rating display) | High | Mobile | P2-R1 | Stars appear in itinerary detail; authenticated users can rate | Manual + widget test | Medium |
| P2-F1 | Backend: Implement Favorites toggle API (`POST/DELETE /api/itineraries/{id}/favorites`); update `favoriteCount` | 🔴 Critical | Backend | None | Users can favorite/unfavorite; counter live-updated | Backend integration test | Small |
| P2-F2 | Mobile: Favorite button in `ItineraryDetailScreen` and `ExploreScreen` cards (heart icon, toggle state) | High | Mobile | P2-F1 | Heart button toggles; count shown on card | Manual + widget test | Small |
| P2-SA1 | Backend: Implement Saved Itineraries API (`POST/DELETE /api/user/saved-itineraries/{id}`, `GET /api/user/saved-itineraries`) | 🔴 Critical | Backend | None | Users can save/unsave itineraries; list endpoint returns saved items | Backend integration test | Small |
| P2-SA2 | Mobile: `SavedItinerariesScreen` — replace empty state with real list (paginated, itinerary cards) | High | Mobile | P2-SA1 | "Đã Lưu" tab shows saved itineraries with pull-to-refresh | Manual + widget test | Medium |

### Phase 3 — Clone/Personalize & Community Screen

| Task ID | Task | Priority | Module | Dependencies | Expected Result | Verification | Effort |
|:---|:---|:---|:---|:---|:---|:---|:---|
| P3-C1 | Backend: Implement `POST /api/itineraries/{id}/clone` — deep-copies itinerary, days, activities; sets `originalItinerary`, increments `reuseCount` | High | Backend | P2-R1, P2-F1 | Cloned itinerary belongs to current user; original `reuseCount` incremented | Backend integration test | Medium |
| P3-C2 | Mobile: "Sao chép lịch trình" button in `ItineraryDetailScreen` (for non-owner public itineraries); navigate to edit clone | High | Mobile | P3-C1 | Users can clone and immediately edit the copy | Manual test | Small |
| P3-CM1 | Mobile: `CommunityScreen` — implement follow-based feed or top-rated public itinerary list (reuse `ExploreNotifier` or new notifier) | Medium | Mobile | P2-R1, P2-F1 | Community tab shows content instead of empty state | Manual + widget test | Large |

### Phase 4 — Web Admin Completion

| Task ID | Task | Priority | Module | Dependencies | Expected Result | Verification | Effort |
|:---|:---|:---|:---|:---|:---|:---|:---|
| P4-W1 | Backend: `GET /api/admin/stats` — counts for users, itineraries, destinations, comments | High | Backend | None | Dashboard can display live stats | Integration test | Small |
| P4-W2 | Web: Admin Dashboard screen with stat cards (total users, itineraries, destinations, comments) | High | Web | P4-W1 | Replacing placeholder with real stats dashboard | Manual + web test | Medium |
| P4-W3 | Backend: `GET /api/admin/users`, `PUT /api/admin/users/{id}/status` (ACTIVE/BANNED) | High | Backend | None | Admin can view and ban/unban users | Integration test | Small |
| P4-W4 | Web: User management screen (data table, search, ban/unban action) | High | Web | P4-W3 | Admin can manage users from web portal | Manual + web test | Medium |
| P4-W5 | Backend: `GET /api/admin/itineraries`, `PUT /api/admin/itineraries/{id}/status` (ACTIVE/HIDDEN/DELETED) | Medium | Backend | None | Admin can moderate itineraries | Integration test | Small |
| P4-W6 | Web: Itinerary moderation screen (table with status badge, hide/restore action) | Medium | Web | P4-W5 | Admin can moderate content from web portal | Manual | Medium |

### Phase 5 — Testing, Quality & Demonstration Preparation

| Task ID | Task | Priority | Module | Dependencies | Expected Result | Verification | Effort |
|:---|:---|:---|:---|:---|:---|:---|:---|
| P5-T1 | Add backend integration tests for Rating, Favorite, SavedItinerary controllers | High | Testing | P2-R1, P2-F1, P2-SA1 | Test coverage ≥ 200 backend tests | `mvnw.cmd test` | Medium |
| P5-T2 | Add mobile widget tests for Rating UI, Favorites button, SavedItinerariesScreen | Medium | Testing | P2-R2, P2-F2, P2-SA2 | Test coverage ≥ 350 mobile tests | `flutter test` | Medium |
| P5-T3 | Add web widget tests for Dashboard and User Management screens | Medium | Testing | P4-W2, P4-W4 | Web test coverage ≥ 60 tests | `flutter test` | Small |
| P5-D1 | Secure credential rotation + `.env.example` or startup guide update | 🔴 Critical | Ops | P1-S1 | No secrets in Git; README shows only env-var names | Git log check | Small |
| P5-D2 | Update `09-development-log.md` with final status | Medium | Docs | All | Log reflects actual implemented state | Manual | Small |
| P5-D3 | Prepare test accounts and demo scenario script | Medium | Docs | Phase 2–4 | Demo can be executed end-to-end in ≤ 15 minutes | Manual walkthrough | Small |

---

## 5. Recommended Immediate Next Task

### ➡ P2-R1 + P2-F1 + P2-SA1 (Backend Social Interaction APIs)

> Implement the three missing social interaction APIs as a single cohesive backend task.

**Why first:**
1. These three features (rating, favorite, save) are the highest-impact missing features relative to effort.
2. They share the same pattern: a toggle-style association between a user and an itinerary.
3. Mobile `SavedItinerariesScreen` is a live dead-end (bottom nav tab with nothing).
4. `ratingCount` and `favoriteCount` are shown in the UI but never updated by real user actions.
5. These are prerequisites for the Clone feature and Community screen.

**Prerequisites needed before starting:**
- Credential security issue (P1-S1) should ideally be fixed first (is a small task), but doesn't technically block development.

**Files/modules likely affected:**
- **Backend new files:** `RatingController.java`, `RatingServiceImpl.java`, `RatingService.java`, `FavoriteController.java`, `FavoriteServiceImpl.java`, `FavoriteService.java`, `SavedItineraryController.java`, `SavedItineraryServiceImpl.java`, `SavedItineraryService.java`
- **Backend DTO new files:** `RatingRequest.java`, `RatingResponse.java`, `FavoriteResponse.java`, `SavedItineraryResponse.java`
- **Backend modified files:** `ItineraryServiceImpl.java` (counter update logic), `SecurityConfig.java` (new endpoint matchers)
- **Backend tests:** `RatingControllerTest.java`, `FavoriteControllerTest.java`, `SavedItineraryControllerTest.java`

**Implementation scope:**
- Rating: POST (create/update), DELETE (remove), GET aggregate (count + user's own score) in itinerary detail response
- Favorite: POST (toggle on), DELETE (toggle off); update `favoriteCount` on itinerary atomically
- Saved: POST (save), DELETE (unsave); GET list (`/api/user/saved-itineraries`) paginated

**Out of scope for this task:**
- Mobile/Web UI (separate follow-on tasks P2-R2, P2-F2, P2-SA2)
- Follow/social graph
- Notifications
- Clone/Personalize

**How to verify:**
1. `mvnw.cmd test` — all existing 157 + new tests pass
2. Postman: POST `/api/itineraries/1/ratings` with `{"score": 4}` → 201 Created
3. Postman: GET `/api/itineraries/1` → `ratingCount` incremented, response includes `userRating: 4`
4. Postman: POST `/api/itineraries/1/favorites` → 200/201; GET `/api/itineraries/1` → `favoriteCount++`
5. Postman: GET `/api/user/saved-itineraries` → returns paginated list

---

## 6. Important Implementation Dependencies

```
P1-S1 (Security) ──────────────────────────────────────────► P5-D1 (Demo)
                                                                 ▲
P2-R1 (Rating API) ───► P2-R2 (Rating UI) ──────────────────► P5-T1
P2-F1 (Fav API) ──────► P2-F2 (Fav UI) ─────────────────────► P5-T1
P2-SA1 (Saved API) ───► P2-SA2 (Saved UI) ───────────────────► P5-T1
                                                                 ▲
P2-R1 + P2-F1 ────────► P3-C1 (Clone API) ──► P3-C2 (Clone UI)
P3-C1 ─────────────────► P3-CM1 (Community Screen)

P4-W1 ─────────────────► P4-W2 (Dashboard)
P4-W3 ─────────────────► P4-W4 (User Mgmt)
P4-W5 ─────────────────► P4-W6 (Moderation)
```

**Independent tasks (no prerequisites):**
- P1-S1, P2-R1, P2-F1, P2-SA1, P4-W1, P4-W3, P4-W5

**Parallel development possible:**
- Backend (P2-R1, P2-F1, P2-SA1) and Web Admin (P4-W1, P4-W3) can proceed simultaneously.

---

### Location & Map Architecture Roadmap (6-Phase Implementation)

To ensure high architectural rigor, zero regression, and prevent monolithic unverified PRs, the location system follows a strict sequential roadmap:

1. **Phase 1 & 1.1: Activity Location Hardening (COMPLETED & ACCEPTANCE READY):**
   - Authoritative snapshot on `Activity` entity (`location_name`, `location_address`, `latitude`, `longitude`, `place_id`, `location_provider`).
   - Mobile getters (`effectiveLocationName`, `effectiveAddress`, `effectiveLatitude`, `effectiveLongitude`) completely decoupled from Destination fallbacks.
   - Idempotent `ActivityLocationMigrationRunner` using a single physical JDBC connection for session-scoped MySQL advisory locking (`GET_LOCK`/`RELEASE_LOCK`), with bounded retries, startup failure (`IllegalStateException`) on lock acquisition timeout with incomplete schema, and independent completeness verification.
   - 100% of 121 activities backfilled with complete snapshots; 0 half-null, 0 invalid coords, 0 destination coordinate dependencies. 298 backend tests PASS.
2. **Phase 2, 2.1 & 2.1.1: Place Catalog & Destination Consolidation (COMPLETED, FINAL VERIFIED & ACCEPTED):**
   - Centralized `places` catalog (`place_id`, `name`, `normalized_name`, `address`, `latitude`, `longitude`, `category`, `status`, etc.).
   - Multi-provider mappings (`place_provider_mappings` on `provider`, `provider_place_id`).
   - Normalization & multi-signal deduplication (`PlaceNormalizationService`).
   - Consolidated legacy `Destination` into `Place`: `DestinationConsolidationMigrationRunner` executed expand-and-contract migration; dropped `destinations` table, `activities.destination_id`, and `places.source_destination_id`.
   - Strict ID distinction: `places.place_id` (BIGINT PK), `activities.canonical_place_id` (BIGINT NULL FK), `activities.place_id` (VARCHAR(100) provider ID never overwritten).
   - Safe migration runner across all 4 operational cases (Case A unmigrated, Case B contracted, Case C fresh DB, Case D incomplete migration).
   - DataSeeder multi-branch collision hardening using Haversine distance matching (< 50m).
   - Full Web Admin management (`AdminPlacesScreen`, `PlaceRepository`, `PlaceFormDialog`, `HidePlaceDialog`).
   - Mobile Activity integration (`PlaceSummary`, snapshot authority preserved).
   - 321 Backend tests PASS (exit code 0), 33 Web tests PASS (exit code 0), 364 Mobile tests PASS (exit code 1, baseline preserved). Total 718 / 721 PASS.
3. **Phase 3: Administrative Areas (STRICT SCOPE — NEXT PHASE):**
   - Administrative hierarchy (`administrative_areas`: provinces, districts, wards) and regional bounding boxes.
4. **Phase 4: User Saved Places:**
   - Personal bookmarks and custom collections (`user_saved_places`).
5. **Phase 5: Clone & Personalize Itinerary:**
   - Forking itineraries with independent snapshot retention.
6. **Phase 6: Explore-to-Itinerary Integration:**
   - Direct injection of Explore places into itinerary timeline days.

---

## 7. Features That Can Be Deferred

| Feature | Reason to defer |
|:---|:---|
| Email verification / password reset | High infrastructure cost (SMTP, token storage); "Needs confirmation" in spec |
| Follow/Social Graph (Follow/Unfollow) | CommunityScreen can initially show top-rated itineraries without user graph |
| Notifications (push + in-app) | Requires WebSocket or FCM; outside scope of a capstone demo |
| Offline download | `OfflineDownload` entity exists but feature is marked out-of-scope in spec |
| Docker / CI/CD | Useful for deployment but not needed for capstone demonstration |
| Flyway/Liquibase schema migration | Hibernate `update` is acceptable for capstone development lifecycle |

---

## 8. Features Outside Project Scope

The following should **not** be added during the remaining development window:
- Real-time chat / messaging
- Payment integration
- Native map SDKs (Google Maps SDK, Apple MapKit) — project uses flutter_map (free)
- Social login (OAuth2 / Google Sign-In)
- AI-based itinerary generation

---

## 9. Audit Limitations

The following items could not be fully verified in this audit and require further investigation:

1. **Itinerary Visibility Toggle (UI):** `CreateItineraryScreen` and `EditItineraryScreen` were not fully read during this audit. Need to confirm that PUBLIC/PRIVATE radio button is exposed to users, not just defaulting to PRIVATE.
2. **Activity Location Picker integration end-to-end:** `LocationPickerSheet` exists in the mobile location feature, but was not fully traced through to verify it correctly saves `latitude`/`longitude` in the Activity via API. The backend `Activity` entity does have `latitude`, `longitude`, `customLocationName`, `customAddress`, `placeId`, `locationProvider` columns — these appear to have been added in the map branch.
3. **CARTO API Key UX:** Map tests show tile 400 errors without an API key (expected in CI). Need to confirm the in-app `MapApiKeyMissingBanner` widget properly handles this for end users running without a key.
4. **Itinerary counter atomicity:** `favoriteCount`, `ratingCount`, `commentCount` are updated with `setX(getX() + 1)` patterns which are not atomic. Under concurrent load this will drift. For capstone purposes this is acceptable; note for future work.

---

## 10. Document History

| Version | Date | Author | Changes |
|:---|:---|:---|:---|
| 1.0 | 2026-11-04 | AI Audit | Initial creation — supersedes `12-project-progress-audit.md` (Vietnamese) for planning purposes |
| 1.1 | 2026-11-11 | AI Lead | Phase 1 & 1.1 Final Verification update |
| 1.2 | 2026-11-11 | AI Lead | Phase 2 Place Catalog implementation and test status update |
| 1.3 | 2026-11-11 | AI Lead | Phase 2.1 Destination Consolidation into Place, contract schema, web admin places update |
| 1.4 | 2026-11-11 | AI Lead | Phase 2.1.1 Post-consolidation stabilization, migration contract guard, DataSeeder multi-attribute lookup & provider mapping seeding |
| 1.5 | 2026-11-11 | AI Lead | Phase 2.1.1 Final Cleanup & Acceptance Gate, multi-branch Cases A-F verification, Fresh DB & Mid-migration test proofs, secure backup rules, 321 backend tests PASS |

