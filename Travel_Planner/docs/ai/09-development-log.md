# Travel Planner - Development Log

## 1. Project Overview & Current Status

- **Project Name:** Travel Planner (Community travel itinerary sharing & planning platform)
- **Log Initialized:** 2026-10-19
- **Current Git Branch:** `auth` (working branch for authentication hardening)
- **Technology Stack:**
  - **Backend:** Spring Boot 3 (Java 22), Spring Security, Spring Data JPA, MySQL 8
  - **Mobile:** Flutter (Dart 3.13.5, Flutter 3.47.7)
  - **Web:** Flutter Web (Admin/Moderation & Content Management)
  - **API:** RESTful JSON API with JWT Bearer Token Authentication

---

## 2. Verified Implementation Status

### 2.1. Completed Modules (Code Verified)

1. **Authentication & Authorization (`/api/auth`)**
   - **Backend:**
     - Endpoints: `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`.
     - Security: BCrypt password hashing, stateless JWT tokens (`JwtTokenProvider`, `JwtAuthenticationFilter`, `SecurityConfig`).
     - Validation: Input validation via Jakarta Validation (`@Valid`, custom error response).
     - Global Exception Handling: `GlobalExceptionHandler` with unified `ErrorResponse` (handling `NoResourceFoundException` to 404).
     - Automated Tests: 21 integration tests in `AuthControllerTest` (all verified passing, covering valid token, expired token, tampered signature, banned user, RBAC admin endpoints).
   - **Frontend (Mobile & Web):**
     - Architecture: `ApiClient`, `ApiException`, `AuthRepository`, `AuthStorage`, `AuthNotifier` (ChangeNotifier).
     - UI: `LoginScreen`, `RegisterScreen` with form validation, error states, and loading indicators.
     - Tests: `widget_test.dart` testing `LoginScreen` rendering (verified passing on both mobile and web).

2. **User Profile Management (`/api/user/profile`)**
   - **Backend:**
     - Endpoints: `GET /api/user/profile`, `PUT /api/user/profile`.
     - Service: `ProfileService`, `ProfileServiceImpl` retrieving and updating user profile (full name, phone, address, bio, avatar).
     - DTOs: `UpdateProfileRequest`, `UserResponse`.
   - **Frontend (Mobile & Web):**
     - Architecture: `ProfileRepository` consuming `/api/user/profile`.
     - UI: `ProfileScreen` with user information display, edit profile modal sheet/dialog, form validation, and save feedback.

3. **System Health & Baseline Configuration**
   - **Backend:** `GET /api/health` returning system status (`UP`) and service name (tested in `HealthControllerTest`).
   - **Theme & Design System:** `app_colors.dart`, `app_theme.dart` adhering to `04-ui-design-system.md`.
   - **Shared Components:** `AppPrimaryButton`, `AppTextField`.

---

### 2.2. Partially Implemented / Skeleton Modules

1. **Domain Data Models (Backend JPA Entities)**
   - Entities defined: `Itinerary`, `ItineraryDay`, `Activity`, `Destination`, `Comment`, `Rating`, `Favorite`, `Follow`, `SavedItinerary`, `ItineraryShare`, `OfflineDownload`.
   - Enums defined: `Role`, `UserStatus`, `Visibility`, `ItineraryStatus`, `DestinationStatus`, `CommentStatus`.
   - *Current reality:* Entities are mapped to MySQL tables, but **no** repositories, services, or controllers exist yet for these entities (only `User` has `UserRepository`).

2. **Frontend Placeholders**
   - Mobile: `PlaceholderHomeScreen` displayed upon successful authentication with a greeting, role badge, profile shortcut, and logout button.
   - Web: `WebPlaceholderScreen` with portal title, account menu, and placeholder content.
   - Folder structure prepared with `.gitkeep`: `comments`, `explore`, `itinerary`/`itineraries`, `notifications`, `reviews`, `saved_itineraries`, `social`, `dashboard`, `locations`, `moderation`, `users`, `violations`.

---

### 2.3. Not Yet Implemented (Described in Docs Only)

- **Itinerary Management:** Itinerary creation wizard, day-by-day scheduler, activity management, budget tracking, privacy/visibility control.
- **Itinerary Discovery & Feed:** Search, filtering (destination, duration, budget, tags), sorting (popular, latest, top rated).
- **Destinations & Map Integration:** Destination catalog, location points, interactive map.
- **Social & Interactions:** Rating itineraries (1-5 stars), comments with moderation, saving/copying/personalizing existing itineraries, user follows.
- **Web Admin & Moderation:** User administration, itinerary moderation, destination approval, violation handling, analytics dashboard.
- **Notifications:** Push and in-app notifications.

---

## 3. Verified Verification & Test Results

Executed and verified on local environment (2026-10-19):

| Component | Check / Command | Result | Notes |
| :--- | :--- | :--- | :--- |
| **Backend** | `./mvnw.cmd test-compile` | **SUCCESS** | 43 main sources + 3 test sources compiled |
| **Backend** | `./mvnw.cmd test` | **SUCCESS** | 15/15 tests passed (13 Auth, 1 Health, 1 App context) |
| **Frontend Mobile** | `flutter analyze` | **SUCCESS** | No issues found (24.8s) |
| **Frontend Mobile** | `flutter test` | **SUCCESS** | 1/1 widget test passed (`LoginScreen`) |
| **Frontend Web** | `flutter analyze` | **SUCCESS** | No issues found (2.3s) |
| **Frontend Web** | `flutter test` | **SUCCESS** | 1/1 widget test passed (`Web LoginScreen`) |

---

## 4. Notable Technical Decisions & Architecture Alignment

1. **Shared API Contract:** Mobile and Web use identical DTO structures and endpoints defined in `docs/ai/03-api-contract.md`.
2. **State Management:** Using Flutter's native `ChangeNotifier` with `ListenableBuilder` to keep the application lightweight without introducing heavyweight external state frameworks prematurely.
3. **Security Architecture:** Stateless JWT Bearer token authentication. Passwords hashed using Spring Security's `BCryptPasswordEncoder`. Role-based access control with `ROLE_USER` and `ROLE_ADMIN`.
4. **Error Handling Strategy:** Uniform error structure returned across all REST endpoints via `GlobalExceptionHandler` mapping to `ErrorResponse`.

---

## 5. Known Issues, Gaps & Blockers

1. **Missing Profile Tests:** `ProfileController` and `ProfileServiceImpl` are implemented and merged into `develop`, but have no corresponding automated unit/integration tests in `src/test/java`.
2. **Test Database Coupling:** Backend integration tests connect directly to local MySQL (`localhost:3306/travel_planner`). Tests will fail if local MySQL is unavailable or misconfigured; no H2 in-memory test configuration is configured yet.
3. **Minimal Frontend Test Coverage:** Only `LoginScreen` has a basic widget test on Mobile and Web. `RegisterScreen`, `ProfileScreen`, and `AuthNotifier` logic lack automated tests.
4. **Residual Staged File:** `Travel_Planner/frontend/mobile/android/build/reports/problems/problems-report.html` is staged in Git from a previous manual build.

---

## 6. Prioritized Next Steps

1. **Priority 1 (Core Feature): Itinerary Management API (Backend)**
   - Implement `ItineraryRepository`, `ItineraryDayRepository`, `ActivityRepository`.
   - Implement `ItineraryService` and `ItineraryController` for CRUD operations on itineraries.
   - Write integration tests for itinerary creation and retrieval.

2. **Priority 1 (Quality Assurance): Add Profile Tests (Backend)**
   - Implement `ProfileControllerTest` covering profile retrieval, profile updates with validation, and unauthorized access rejection.

3. **Priority 2 (Mobile Feature): Itinerary Feed & Explore Screen**
   - Replace `PlaceholderHomeScreen` on Mobile with an itinerary feed screen displaying public itineraries.
   - Implement itinerary summary cards according to `04-ui-design-system.md`.

4. **Priority 2 (Mobile Feature): Itinerary Creation Flow**
   - Build UI for creating an itinerary (title, destination, dates, budget, day-by-day activities).

5. **Priority 3 (Web Admin): Admin Dashboard & User Management**
   - Implement admin layout (sidebar navigation) and user list/management screens on Flutter Web.

---

## 7. Audit Session: Authentication & Authorization (2026-10-19)

> **Activity Type:** Technical Review & Security Assessment (Audit) — NO APPLICATION SOURCE CODE MODIFIED.

### 7.1. Summary of Audit Findings
- **Backend:** Basic registration, login, and JWT security functioned correctly; passwords hashed with BCrypt without exposing sensitive attributes. However, Role-Based Access Control (RBAC) was not activated (`@EnableMethodSecurity` was missing), and there was no token verification endpoint on the server.
- **Frontend (Mobile & Web):** UI flows were synchronized with solid double-submission prevention. Gaps existed in session restoration (only checking local `exp` expiration without server validation), lack of centralized HTTP 401 handling for automatic logout, and the Android default IP address hardcoded a specific LAN IP.
- **Testing:** 13/13 existing baseline tests passed, but advanced security test cases were missing (expired token, tampered signature, token revocation after account suspension).

A comprehensive findings matrix and prioritized remediation roadmap (P0 -> P2) were compiled and delivered to the user.

---

## 8. Implementation Session: Fixing P0 Authentication Issues (2026-10-19)

> **Activity Type:** Bug Fix & Security Hardening — Priority P0.

### 8.1. Changes Implemented
1. **Role-Based Access Control (RBAC) Enforcement on Backend:**
   - Activated `@EnableMethodSecurity` in [SecurityConfig.java](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java).
   - Configured prefix-based role protection for admin routes: `.requestMatchers("/api/admin/**").hasRole("ADMIN")`.
   - Handled `NoResourceFoundException` in [GlobalExceptionHandler.java](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/exception/GlobalExceptionHandler.java) to return standard HTTP 404 REST response instead of falling back to HTTP 500 when no controller matches.
   - Added 3 integration tests in [AuthControllerTest.java](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AuthControllerTest.java): verifying 401 Unauthorized without token, 403 Forbidden for `ROLE_USER`, and access granted for `ROLE_ADMIN`.
2. **Centralized 401 Handling & Auto-Logout Navigation on Flutter Mobile & Web:**
   - **Network Layer (`ApiClient`):** Added `onUnauthorized` and `globalOnUnauthorized` callbacks triggered exclusively on `response.statusCode == 401`. Added 2-second throttle (`_unauthorizedThrottle`) to prevent burst logout triggers when concurrent requests fail. Does not trigger on network errors, timeouts, or HTTP 400, 403, 500.
   - **State Management (`AuthNotifier`):** Added `handleSessionExpired()` guarded with `_isHandlingSessionExpired` concurrency flag, purging token and user profile from storage and setting state to `unauthenticated`.
   - **App Navigation (`main.dart`):** Connected `ApiClient.globalOnUnauthorized` in `initState()`, resetting navigation stack via `Navigator.popUntil((route) => route.isFirst)` to immediately route user to `LoginScreen`.
3. **Automated 401 Test Suites:**
   - Created [auth_401_test.dart](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/auth_401_test.dart) on Mobile and Web verifying: 401 callback triggering, non-triggering for other HTTP status codes, throttle mechanism, and `AuthNotifier` session cleanup.

### 8.2. Files Created / Modified
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java`
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/exception/GlobalExceptionHandler.java`
- `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AuthControllerTest.java`
- `Travel_Planner/frontend/mobile/lib/core/network/api_client.dart`
- `Travel_Planner/frontend/mobile/lib/features/auth/presentation/auth_notifier.dart`
- `Travel_Planner/frontend/mobile/lib/main.dart`
- `Travel_Planner/frontend/mobile/test/auth_401_test.dart` *(Created)*
- `Travel_Planner/frontend/web/lib/core/network/api_client.dart`
- `Travel_Planner/frontend/web/lib/features/auth/presentation/auth_notifier.dart`
- `Travel_Planner/frontend/web/lib/main.dart`
- `Travel_Planner/frontend/web/test/auth_401_test.dart` *(Created)*

### 8.3. Verified Test Results
- **Backend Spring Boot:** `./mvnw.cmd test` -> **18/18 tests PASS** (16 AuthControllerTest, 1 HealthControllerTest, 1 ContextLoads).
- **Frontend Mobile (Flutter):**
  - `flutter analyze` -> **No issues found** (1.8s).
  - `flutter test` -> **6/6 tests PASS** (5 auth_401_test, 1 widget_test).
- **Frontend Web (Flutter Web):**
  - `flutter analyze` -> **No issues found** (1.1s).
  - `flutter test` -> **6/6 tests PASS** (5 auth_401_test, 1 widget_test).

### 8.4. Remaining Issues Post-P0
- Missing `/api/auth/me` endpoint for cold-start session verification on the server. (Resolved in Section 9)
- Android default IP address in `api_constants.dart` hardcoded LAN IP. (Resolved in Section 9)
- Frontend username validation missing regex `^[a-zA-Z0-9_.]+$`. (P2 - Resolved in Section 10)
- Backend CORS configuration hardcoded to port 8081. (P2 - Resolved in Section 10)

---

## 9. Implementation Session: Completing P1 Authentication Items (2026-10-19)

> **Activity Type:** Feature Enhancement & Session Integrity — Priority P1.

### 9.1. Changes Implemented
1. **Endpoint `GET /api/auth/me` on Backend:**
   - **Service Layer:** Added `getCurrentUser(String username)` in `AuthService` and `AuthServiceImpl`. Validated that the user exists and status is neither `BANNED` nor `INACTIVE` (throws `UnauthorizedException` if invalid).
   - **Controller Layer:** Added endpoint `GET /api/auth/me` in `AuthController`, extracting `UserDetails` from `@AuthenticationPrincipal` and returning `UserResponse` (contains only id, username, email, fullName, avatarUrl, role, status, createdAt, updatedAt; strictly no passwords or sensitive data).
   - **Security:** Updated `SecurityConfig` so that `/api/auth/me` is protected under `.anyRequest().authenticated()`.
   - **Integration Tests:** Added 5 integration tests in `AuthControllerTest`:
     - Valid token returns HTTP 200 with accurate user profile.
     - Missing Authorization header returns HTTP 401.
     - Expired token returns HTTP 401.
     - Tampered signature returns HTTP 401.
     - Valid token with user banned after issuance returns HTTP 401.
2. **Cold-Start Session Restoration & Verification on Flutter Mobile & Web:**
   - **Repository Layer:** Added `getCurrentUser(String token)` in `AuthRepository` on both Mobile and Web calling `GET /api/auth/me` with Bearer token.
   - **State Management Layer (`AuthNotifier`):**
     - On app startup (`checkAuthStatus()`), if a locally valid token exists (`!AuthStorage.isTokenExpired(savedToken)`), calls `_repository.getCurrentUser(savedToken)` to verify with the backend.
     - If backend returns HTTP 401 / 403: purges session (`_storage.clear()`), transitions state to `unauthenticated`, and routes to Login.
     - If encountering network failure (`statusCode == 0`) or server error (`statusCode >= 500`): does **not** assume the token is invalid; preserves session with locally cached user data (`_currentUser = cachedUser`), preventing spurious logouts during temporary offline states.
     - If token is expired locally according to `exp`: purges storage immediately without redundant network requests.
   - **Synchronization:** 100% identical implementation across Flutter Mobile and Flutter Web.
3. **Flexible Android API Base URL Configuration (`api_constants.dart`):**
   - Supports build-time environment variable `--dart-define=API_BASE_URL=<URL>`.
   - Smart defaults:
     - Android Emulator: `http://10.0.2.2:8080`.
     - Web & Desktop: `http://localhost:8080`.
     - Physical devices on LAN: pass `--dart-define=API_BASE_URL=http://<LAN_IP>:8080` without changing code.
   - Added `meEndpoint = '/api/auth/me'` on both Mobile and Web.
4. **Extended Automated Test Suites:**
   - Added 4 unit/widget tests in `auth_401_test.dart` (Mobile and Web) verifying:
     - Successful session restoration with valid token + backend 200.
     - Server 401 response triggers full session purge and `unauthenticated` state.
     - Server 500 retains existing session and cached user profile.
     - Locally expired token is cleared without sending backend requests.

### 9.2. Files Modified
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/AuthService.java`
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/AuthServiceImpl.java`
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AuthController.java`
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java`
- `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AuthControllerTest.java`
- `Travel_Planner/frontend/mobile/lib/core/constants/api_constants.dart`
- `Travel_Planner/frontend/mobile/lib/features/auth/data/auth_repository.dart`
- `Travel_Planner/frontend/mobile/lib/features/auth/presentation/auth_notifier.dart`
- `Travel_Planner/frontend/mobile/test/auth_401_test.dart`
- `Travel_Planner/frontend/web/lib/core/constants/api_constants.dart`
- `Travel_Planner/frontend/web/lib/features/auth/data/auth_repository.dart`
- `Travel_Planner/frontend/web/lib/features/auth/presentation/auth_notifier.dart`
- `Travel_Planner/frontend/web/test/auth_401_test.dart`

### 9.3. Verified Test Results
- **Backend Spring Boot:**
  - Command: `.\mvnw.cmd test`
  - Result: **23/23 tests PASS (BUILD SUCCESS)** (21 AuthControllerTest, 1 HealthControllerTest, 1 TravelPlannerApplicationTests).
- **Frontend Mobile (Flutter):**
  - Command `flutter test`: **10/10 tests PASS** (9 auth_401_test, 1 widget_test).
  - Command `flutter analyze`: **No issues found!** (0 errors, 0 warnings).
- **Frontend Web (Flutter Web):**
  - Command `flutter test`: **10/10 tests PASS** (9 auth_401_test, 1 widget_test).
  - Command `flutter analyze`: **No issues found!** (0 errors, 0 warnings).

### 9.4. Remaining Issues Post-P1
- Frontend username validation missing regex rule (Resolved in Section 10).
- CORS configuration hardcoded (Resolved in Section 10).
- JWT Secret production safety (Resolved in Section 10).
- Test Database coupling (Evaluated in Section 10).

---

## 10. Implementation Session: Reviewing and Resolving P2 Authentication Items (2026-10-19)

> **Activity Type:** Production Hardening, Environment Configuration & Input Validation Synchronization — Priority P2.

### 10.1. Changes Implemented
1. **JWT Secret Production Hardening:**
   - **Code Layer (`JwtTokenProvider.java`):**
     - Declared `DEFAULT_DEV_SECRET` constant.
     - Integrated Spring `Environment` in constructor to inspect active profiles.
     - Strict fail-fast check: if active profile is `prod` or `production`, using `DEFAULT_DEV_SECRET` or blank secret is strictly forbidden. Throws `IllegalStateException` during startup with a descriptive error message.
     - Enforced minimum secret key length of 256 bits (32 bytes) for HMAC-SHA256.
     - Retained fallback dev secret for local/dev/test environments to ensure smooth developer workflow.
   - **Configuration (`application-prod.properties`):**
     - Created dedicated production configuration requiring `jwt.secret=${JWT_SECRET}` (no default fallback), guaranteeing the application cannot boot if the environment variable is absent.
   - **Unit Tests (`JwtTokenProviderTest.java`):**
     - Added 5 automated tests:
       1. Successful initialization with dev profile and default secret.
       2. Fail-fast rejection (`IllegalStateException`) under `prod` profile with default secret.
       3. Fail-fast rejection (`IllegalStateException`) under `production` profile with blank secret.
       4. Successful initialization under `prod` profile with custom secure key.
       5. Rejection (`IllegalStateException`) when secret is shorter than 32 bytes.
2. **CORS Externalization & Origin Protection:**
   - **Configuration (`application.properties`):**
     - Externalized origins to `cors.allowed-origins` and `cors.allowed-origin-patterns`, overridable via `ALLOWED_ORIGINS` and `ALLOWED_ORIGIN_PATTERNS` environment variables.
     - Default values support multi-port Flutter Web local development: `http://localhost:8081`, `http://127.0.0.1:8081`, `http://localhost:3000`, `http://localhost:8082` along with patterns `http://localhost:*`, `http://127.0.0.1:*` (enabling dynamic port assignments during Flutter Web debugging).
   - **Security Layer (`SecurityConfig.java`):**
     - Updated `corsConfigurationSource()` to parse comma-delimited strings into lists.
     - Defensive safeguard: automatically removes global wildcard `*` from origins/patterns when `allowCredentials(true)` is enabled, preventing credential leaks to arbitrary origins.
   - **Integration Tests (`AuthControllerTest.java`):**
     - Added test verifying allowed origin (`http://localhost:8081`) receives valid `Access-Control-Allow-Origin` and `Access-Control-Allow-Credentials: true`.
     - Added test verifying untrusted origin (`http://malicious-untrusted-site.com`) is rejected with HTTP 403 Forbidden without CORS permission headers.
3. **Username Validation Synchronization (Mobile & Web):**
   - **Frontend Mobile & Web (`register_screen.dart`):**
     - Added `static String? validateUsername(String? value)` synchronized 100% with backend `RegisterRequest` rules: `@Pattern(regexp = "^[a-zA-Z0-9_.]+$")` and `@Size(min = 3, max = 50)`.
     - Clear, user-friendly error messages:
       - Empty or whitespace only: *"Vui lòng nhập tên đăng nhập"*
       - Contains spaces: *"Tên đăng nhập không được chứa khoảng trắng"*
       - Length outside [3, 50]: *"Tên đăng nhập phải từ 3 đến 50 ký tự"*
       - Invalid characters: *"Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm"*
   - **Frontend Unit Tests:**
     - Created [username_validation_test.dart](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/username_validation_test.dart) (Mobile) and [username_validation_test.dart](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/test/username_validation_test.dart) (Web) testing all 5 scenarios: empty, spaces, length boundary, special characters, and valid usernames.
   - **Backend Integration Tests (`AuthControllerTest.java`):**
     - Added registration test with username containing spaces -> HTTP 400.
     - Added registration test with username containing special characters (`user@invalid#name!`) -> HTTP 400.
4. **Test Database Isolation Evaluation:**
   - **Current State:** Test suite uses `@SpringBootTest` connecting directly to local MySQL at `localhost:3306/travel_planner`.
   - **H2 In-Memory Evaluation (`jdbc:h2:mem:...;MODE=MySQL`):**
     - *Compatibility:* All 12 current JPA entities (`User`, `Itinerary`, `Activity`, `Destination`, ...) use standard JPA mappings (`GenerationType.IDENTITY`, `EnumType.STRING`, `TEXT`) without MySQL-specific functions (like native JSON or Spatial/GIS). H2 is already present in `.m2/repository`.
     - *Risks & Trade-offs:* H2 MySQL mode is a dialect simulation. As the travel planner evolves to include location/map features (spatial index, `ST_Distance_Sphere`) or migration scripts (Flyway/Liquibase), behavioral discrepancies with MySQL 8 will emerge.
   - **Testcontainers Evaluation (MySQL 8 Docker):**
     - *Pros:* 100% fidelity with production MySQL.
     - *Cons:* Strictly requires a running Docker daemon. Tests fail on developer environments without Docker Desktop or non-privileged CI containers.
   - **Decision:** Do not modify production database configuration. Recommend establishing a dedicated `test` profile with a `travel_planner_test` schema locally, or enabling H2 in-memory via `src/test/resources/application.properties` when configuring automated CI/CD runners.

### 10.2. Files Created / Modified
- `Travel_Planner/backend/src/main/resources/application.properties`
- `Travel_Planner/backend/src/main/resources/application-prod.properties` *(Created)*
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/JwtTokenProvider.java`
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java`
- `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/security/JwtTokenProviderTest.java` *(Created)*
- `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AuthControllerTest.java`
- `Travel_Planner/frontend/mobile/lib/features/auth/presentation/screens/register_screen.dart`
- `Travel_Planner/frontend/mobile/test/username_validation_test.dart` *(Created)*
- `Travel_Planner/frontend/web/lib/features/auth/presentation/screens/register_screen.dart`
- `Travel_Planner/frontend/web/test/username_validation_test.dart` *(Created)*

### 10.3. Verified Test Results
- **Backend Spring Boot:**
  - Command: `.\mvnw.cmd test`
  - Result: **32/32 tests PASS (BUILD SUCCESS)**:
    - 25 tests in `AuthControllerTest` (including username whitespace/symbol validation and CORS allow/block).
    - 5 tests in `JwtTokenProviderTest` (testing prod fail-fast, dev default, key length >= 32 bytes).
    - 1 test in `HealthControllerTest`.
    - 1 test in `TravelPlannerApplicationTests`.
- **Frontend Mobile (Flutter):**
  - Command `flutter test`: **15/15 tests PASS** (9 auth_401_test, 5 username_validation_test, 1 widget_test).
  - Command `flutter analyze`: **No issues found!** (0 errors, 0 warnings).
- **Frontend Web (Flutter Web):**
  - Command `flutter test`: **15/15 tests PASS** (9 auth_401_test, 5 username_validation_test, 1 widget_test).
  - Command `flutter analyze`: **No issues found!** (0 errors, 0 warnings).

### 10.4. Verification Status Categorization
1. **Resolved and Verified with Automated Tests:**
   - JWT fail-fast validation in production profile & minimum 32-byte secret key length.
   - CORS externalized origins, multi-port localhost origin patterns, and rejection of arbitrary wildcards.
   - Username validation synchronization (spaces, special characters, length 3-50) across Mobile, Web, and Backend.
2. **Configuration Reviewed (Not Yet Production Deployed):**
   - `application-prod.properties` created to enforce environment variables in production; actual deployment on cloud/Kubernetes infrastructure was not conducted in this session.
3. **Evaluated & Recommended:**
   - Test database separation: Evaluated H2 vs Testcontainers vs Dedicated MySQL Schema; current JPA entity mappings are fully compatible for CI/CD integration without altering production database configuration.

---

## 11. Session Entry: UI Documentation Synchronization with DESIGN.md (2026-10-23)

### 11.1. Context and Objective
Synchronized the project documentation with the newly introduced root-level `DESIGN.md` (Airbnb-inspired design system) to establish a unified, canonical UI/UX design standard across Flutter Mobile and Flutter Web. This task is strictly a documentation synchronization effort; no application source code, API contracts, backend logic, or dependencies were altered.

### 11.2. Documents Reviewed and Modified

#### Documents Modified:
1. `docs/ai/04-ui-design-system.md`: Primary update. Established as the canonical project-specific implementation guide translating `DESIGN.md` into concrete Flutter design tokens, color palettes, typographic hierarchy, 4px spacing scale, component specifications (buttons, pill search bar, photo cards, action rail), single-tier elevation, and responsive breakpoints.
2. `docs/ai/05-ux-guidelines.md`: Aligned end-to-end user journeys (discovery feed, pill search/filter, photo-led itinerary details, creation/editing, saving vs. reusing, community ratings in ink `#222222`, and profile management) with the new design reference and mobile/web ergonomic adaptations.
3. `docs/ai/00-project-context.md`: Updated product & design principles and the Sources of Truth inventory to reference `DESIGN.md` as the root visual reference and `04-ui-design-system.md` as the canonical implementation guide.
4. `docs/ai/02-coding-rules.md`: Added UI coding conventions enforcing theme token consumption from `Theme.of(context)` / `lib/core/theme/`, reuse of shared widgets in `lib/shared/widgets/`, responsive breakpoint discipline, and prohibition of arbitrary hardcoded styling.
5. `docs/ai/06-feature-spec.md`: Clarified that visual feature presentation must adhere to canonical UI design tokens without altering business logic, acceptance criteria, or permissions defined in `docs/Travel_Planner_Function_Specification.md`.
6. `docs/ai/07-testing-quality.md`: Expanded the Flutter testing and quality checklist to include theme token consistency, reusable component verification, WCAG AA contrast (minimum 4.5:1), responsive layout overflow checks, and 48x48dp touch targets.
7. `docs/ai/08-agent-workflow.md`: Updated agent instructions across phases to mandate reading `AGENTS.md` first, reading `DESIGN.md` for visual styling, using `04-ui-design-system.md` as the canonical UI guide, reusing tokens/widgets, and recording dated English entries in the development log.
8. `docs/ai/09-development-log.md`: Appended this session record.

#### Documents Reviewed and Intentionally Left Unchanged:
- `AGENTS.md`: Mandatory instructions and constraints already consistent.
- `DESIGN.md`: Root visual reference; remains untracked source reference as installed.
- `docs/ai/01-architecture.md`: Confirmed system architecture, platform roles, and folder structures remain consistent; no changes required.
- `docs/ai/03-api-contract.md`: Confirmed REST contracts, endpoints, and DTOs are independent of visual styling; no changes required.
- `docs/promts/entity_generation.md`: Backend database/entity prompt contains no UI dependencies; left unchanged.
- `docs/Travel_Planner_Function_Specification.md`: Functional business specification remains the authoritative source of truth for business scope and permissions; left unchanged.

### 11.3. Key Design-System Decisions Synchronized
1. **Visual Direction & Canvas:**
   - Warm, generous, photo-first consumer travel marketplace anchored on pure white canvas (`#FFFFFF`) with generous section breathing room (64px padding) and dense card grids (16px gap).
2. **Color Palette:**
   - Single brand accent: **Rausch** (`primary`: `#FF385C`), active (`#E00B41`), disabled (`#FFD1DA`).
   - Neutrals: Ink (`#222222`), Body text (`#3F3F3F`), Muted (`#6A6A6A`), Hairline border (`#DDDDDD`), and Scrim (`#000000` at 50% opacity).
   - Rating stars: Rendered in solid Ink (`#222222`) rather than yellow, establishing a high-trust, authentic aesthetic.
   - Semantic error: `#C13515` for inline form error messages.
   - Scoped sub-brands: Luxe (`#460479`) and Plus (`#92174D`) restricted strictly to premium/curated itinerary badges.
   - Retained project tokens: Success (`#10B981`), Warning (`#F59E0B`), Info (`#3B82F6`) retained for system alerts and moderation states.
3. **Typography Hierarchy:**
   - Primary typeface: `Airbnb Cereal VF` with fallbacks `Circular`, `-apple-system`, `Roboto`, `sans-serif`.
   - Open-source Flutter substitute: **Inter** (line-height adjusted ~2% tighter).
   - Display weights kept modest (20px–28px, w500–w700) to allow photography to lead. Signature 64px `rating-display` (w700) serves as the primary typographic trust signal.
4. **Shape Language & Radii:**
   - Rounded geometry across all interactive elements: 8px (`rounded.sm`) for buttons and text inputs; 14px (`rounded.md`) for itinerary cards and dialogs; 9999px (`rounded.full`) for the pill search bar, circular search orb, category chips, and badges.
5. **Elevation:**
   - Baseline is flat (no shadow for 95% of surfaces). A single subtle shadow tier (`box-shadow: rgba(0,0,0,0.02) 0 0 0 1px, rgba(0,0,0,0.04) 0 2px 6px 0, rgba(0,0,0,0.1) 0 4px 8px 0`) is applied to card hover states, the search bar at rest, sticky action cards, and dropdowns.
6. **Components & Layouts:**
   - Signature pill search bar (`search-bar-pill`, 64px) with segmented Where/When/Who fields and circular Rausch search orb (`search-orb`, 48x48px).
   - Photo-first itinerary cards (`property-card`) with 14px rounded clipping, floating favorite badge, and heart button.
   - Detail screen two-column layout on desktop (~64% content, ~32% sticky action rail) collapsing to a persistent sticky bottom bar on mobile.
   - Form inputs (`text-input`, 56px height, 8px radius) with stacked labels and 2px ink focus border (no colored glow).
7. **Responsive Breakpoints:**
   - Mobile: `< 744px`
   - Tablet: `744px – 1128px`
   - Desktop: `1128px – 1440px`
   - Wide: `> 1440px` (max width ~1280px–1440px centered).

### 11.4. Conflicts, Decisions, and Unresolved Follow-Ups
1. **Frontend Codebase Theme Migration (Follow-up Task):**
   - The existing code in `frontend/mobile/lib/core/theme/app_colors.dart` and `frontend/web/lib/core/theme/app_colors.dart` continues to hold legacy Teal (`#0D9488`) / Orange (`#F97316`) tokens.
   - Updating the actual Dart theme files and UI components was explicitly excluded from this task scope and is recommended for a dedicated frontend migration task.
2. **Dark Mode Policy:**
   - `DESIGN.md` explicitly notes that Airbnb does not support dark mode on public web. Dark mode policy for Travel Planner is noted as an unresolved future roadmap item.
3. **Map View Styling:**
   - Custom map marker and tile tinting tokens are not fully specified in `DESIGN.md` and will require map SDK integration specs during map feature implementation.

### 11.5. Verification and Execution Results
- **Documentation Relative Links & References Check:** Verified that all document cross-references (`DESIGN.md`, `04-ui-design-system.md`, `05-ux-guidelines.md`, etc.) resolve to valid existing files.
- **Git Whitespace & Diff Check:** `git diff --check` executed with clean exit (code 0, no trailing whitespace or formatting conflicts).
- **Git Status Review:** `git status` confirmed only documentation files (`docs/ai/*.md`) were modified alongside untracked `DESIGN.md`.
- **Source Code Integrity:** Confirmed 0 application source code files (`.dart`, `.java`), configuration files, or database schemas were modified.

---

## 12. Session Entry: UI Documentation Audit and Finalization (2026-10-23)

### 12.1. Context and Objective
Audited the documentation changes from the previous `DESIGN.md` synchronization task. The audit focused on eliminating unsupported assumptions, correcting domain-specific component terminology, refining accessibility contrast standards, clarifying font fallback realities, and verifying cross-document consistency.

### 12.2. Verified Problems Found and Corrected

1. **Font Strategy & Unbundled Font Assumption:**
   - *Problem:* `04-ui-design-system.md` previously described `Inter` as the "designated open-source font for Flutter Mobile and Flutter Web", implying it was already configured. Inspection of `frontend/mobile/pubspec.yaml` and `frontend/web/pubspec.yaml` revealed neither `Airbnb Cereal VF` nor `Inter` is installed or bundled; both projects currently configure `fontFamily: 'Roboto'` (or system defaults) in `app_theme.dart`.
   - *Correction:* Updated `04-ui-design-system.md` Section 3.1 to establish a formal fallback chain: `Airbnb Cereal VF` (unbundled upstream reference) -> `Inter` (recommended open-source substitute, requiring future approval) -> `Roboto` / Platform System Default (current active codebase fallback). Explicitly noted that no font assets or packages were introduced in this documentation task.
2. **Accommodation-Booking Terminology vs. Travel Itinerary Domain:**
   - *Problem:* Previous documentation retained Airbnb-specific accommodation terminology (`reservation-card`, `host-card`, nightly rates), which contradicts the Travel Planner platform domain (itinerary sharing, planning, discovery, saving, and reuse).
   - *Correction:* Replaced accommodation booking terminology with travel planner component equivalents across `04-ui-design-system.md` and `05-ux-guidelines.md`:
     - `property-card` -> `itinerary-card`: Photo-first card summarizing community travel itineraries (cover photo, title, duration, budget, season, rating, favorite heart).
     - `host-card` -> `author-card`: Creator profile card presenting the itinerary author's avatar, name, verification badge, and published trips count.
     - `reservation-card` -> `itinerary-action-card` (Sticky Action Rail / Bottom Bar): Container displaying estimated total trip budget, duration, date details, and primary community CTAs ("Lưu vào chuyến đi của tôi" and "Sao chép lịch trình").
3. **Accessibility Contrast Guidance Imprecision:**
   - *Problem:* Previous documentation stated that "all text must maintain minimum 4.5:1 contrast against light canvas/surfaces". Rausch (`#FF385C`) with white text (`#FFFFFF`) produces a contrast ratio of ~3.52:1, which satisfies WCAG AA for **large text** (>= 18.5px bold or >= 24px regular) and UI component boundaries (minimum 3.0:1), but does not reach 4.5:1 for small running text.
   - *Correction:* Refined contrast rules in `04-ui-design-system.md`, `05-ux-guidelines.md`, and `07-testing-quality.md`:
     - Normal text (< 24px non-bold): minimum 4.5:1 contrast (achieved by `ink` `#222222` at ~16:1 and `body` `#3F3F3F` at ~10.5:1 on `#FFFFFF`).
     - Large text and primary button labels (`button-md` on Rausch `#FF385C` at ~3.52:1): minimum 3.0:1 contrast under WCAG AA large text/component rules.
     - Framed contrast rules as implementation evaluation targets, explicitly avoiding unverified claims of tested compliance.
4. **Web Layouts & Administrative Workflow Clarity:**
   - *Problem:* Documentation required clearer distinction between mobile consumer layouts and desktop administrative workflows.
   - *Correction:* Added Section 7.2 to `04-ui-design-system.md` clarifying that `frontend/web` leverages the shared design tokens (white canvas, 1px hairlines, 8px input radius, 14px card radius, Rausch primary CTA accents) within administrative patterns (persistent side navigation rail, data tables with pagination, and moderation queue split views).

### 12.3. Documents Inspected and Status
- **Modified in Audit:**
  - `docs/ai/04-ui-design-system.md` (font fallback chain, travel itinerary component domain, WCAG AA contrast distinction, web admin layout section).
  - `docs/ai/05-ux-guidelines.md` (component naming and accessibility targets).
  - `docs/ai/07-testing-quality.md` (contrast verification criteria distinguishing normal vs. large text).
  - `docs/ai/09-development-log.md` (appended Session 12 audit record).
- **Inspected and Confirmed Consistent (Left Unchanged):**
  - `AGENTS.md`
  - `DESIGN.md`
  - `docs/ai/00-project-context.md`
  - `docs/ai/01-architecture.md`
  - `docs/ai/02-coding-rules.md`
  - `docs/ai/03-api-contract.md`
  - `docs/ai/06-feature-spec.md`
  - `docs/ai/08-agent-workflow.md`
  - `docs/promts/entity_generation.md`
  - `docs/Travel_Planner_Function_Specification.md`

### 12.4. Remaining Decisions Requiring Project Owner Approval
1. **Font Substitute Integration:** Explicit decision whether to adopt `Inter` (via asset bundling or `google_fonts`) or continue with `Roboto` / platform system defaults.
2. **Codebase Theme Migration Task:** Scheduling a dedicated frontend implementation task to update `lib/core/theme/` Dart files from legacy Teal (`#0D9488`) to canonical Rausch (`#FF385C`) tokens.
3. **Dark Mode Roadmap:** Finalizing whether dark mode will be planned for future phases or omitted as in public Airbnb.
4. **Map Tile and Marker Specs:** Defining custom map tile tinting and marker icon styling for destination exploration.

### 12.5. Actual Verification Results
- `git diff --check`: Exit code 0 (clean, no trailing whitespace or conflict markers).
- **Source Code Integrity:** Confirmed 0 application source code files (`.dart`, `.java`), configuration files, or database schemas were modified.

---

## 13. Session Entry: Final UI Documentation Review — WCAG and Readiness (2026-10-23)

### 13.1. Context and Objective
Executed a final audit and review of UI documentation focusing on WCAG 2.1 AA accessibility contrast rules, font configuration realities, feature scope boundaries, and implementation readiness.

### 13.2. Audited Corrections Made

1. **WCAG Contrast Ratios & Sizing Precision:**
   - *Issue:* Typical 16px button labels (`button-md`) were previously loosely grouped with large text under the 3.0:1 criterion. Under WCAG 2.1 AA (SC 1.4.3), large text is strictly defined as text that is at least 18pt (~24px) regular or at least 14pt (~18.66px) bold (w700+). Standard 14px (`button-sm`) and 16px (`button-md`) button labels are normal text and must target at least **4.5:1**.
   - *Verification of `#FF385C` against `#FFFFFF`:* Calculated exact relative luminance of Rausch `#FF385C` (~0.2486) against `#FFFFFF` (1.0). The resulting contrast ratio is **~3.52:1**.
   - *Outcome:* Documented that white text on `#FF385C` meets the 3.0:1 requirement for non-text UI components (SC 1.4.11) and large text headings, but does not achieve the 4.5:1 requirement for normal text.
   - *Documented Adjustments:* Specified concrete adjustments in `docs/ai/04-ui-design-system.md` and `docs/ai/05-ux-guidelines.md` for strict 4.5:1 compliance:
     - Primary button background adjustment: use an accessible darkened variant such as `#E00B41` (`primary-active`, 4.89:1 contrast vs `#FFFFFF`) or `#D90740` (`primary-accessible`, 5.18:1 contrast vs `#FFFFFF`).
     - Text adjustment: pair `#FF385C` with dark `ink` (`#222222`, 4.52:1 contrast) where appropriate.
     - Prohibition of Rausch for running body copy or plain text links on white canvas.
   - *Testing Framing:* Clarified across `04-ui-design-system.md`, `05-ux-guidelines.md`, and `07-testing-quality.md` that these standards represent design criteria and testing benchmarks, not evidence that the application has already passed accessibility verification.

### 13.3. Final Consistency Verification
1. **Font Strategy:** Confirmed documentation accurately reflects that `Airbnb Cereal VF` is an unbundled reference font, `Inter` is a proposed substitute requiring future integration, and `Roboto` / platform system default is the active configuration in `app_theme.dart`.
2. **Feature Domain:** Confirmed no accommodation-booking features (hotel reservations, nightly pricing) exist in documentation; all components reflect travel itinerary sharing, planning, saving, and reuse.
3. **Platform Adaptation:** Confirmed Mobile and Web share unified visual tokens (white canvas, 1px hairlines, 8px/14px radii, Rausch accents) while supporting platform-appropriate layouts (sticky bottom bar and thumb targets on mobile; persistent side navigation and data tables on web).
4. **Implementation Separation:** Confirmed code migration of `lib/core/theme/` from Teal to Rausch remains a separate, dedicated frontend task.

### 13.4. Actual Verification Results
- `git diff --check`: Exit code 0 (clean, no trailing whitespace or conflict markers).
- `git status --short`: Only 8 documentation files modified under `Travel_Planner/docs/ai/`, alongside untracked `DESIGN.md`.
- Source Code Integrity: Zero `.dart`, `.java`, `.xml`, `.properties`, or `.yaml` files modified.

---

## 14. Session Entry: Mathematical WCAG Contrast Recalculation & Finalization (2026-10-23)

### 14.1. Context and Objective
Audited and recalculated all numerical relative luminance values and WCAG 2.1 AA contrast ratios from actual hexadecimal color codes using the official W3C formulas:
- Linearization: $c = sRGB / 12.92$ if $sRGB \le 0.04045$, else $c = ((sRGB + 0.055) / 1.055)^{2.4}$.
- Relative Luminance: $L = 0.2126 \times R + 0.7152 \times G + 0.0722 \times B$.
- Contrast Ratio: $CR = (L_1 + 0.05) / (L_2 + 0.05)$, where $L_1 > L_2$.

### 14.2. Recalculated Numerical Results and Documented Corrections

| Hex Code | Token / Role | Relative Luminance ($L$) | Contrast vs `#FFFFFF` ($L=1.0$) | Contrast vs `#222222` ($L=0.016$) | WCAG AA Normal Text (>= 4.5:1) |
|---|---|---|---|---|---|
| `#FFFFFF` | Canvas / White text | 1.00000 | 1.00:1 | 15.91:1 | N/A |
| `#FF385C` | `primary` (Rausch, brand reference) | 0.24861 | **3.52:1** | **4.52:1** | Fails on white (3.52 < 4.5); Passes with ink (4.52 >= 4.5) |
| `#E00B41` | `primary-active` (press state in DESIGN.md) | 0.16468 | **4.89:1** | 3.25:1 | **Passes on white** (4.89 >= 4.5) |
| `#D90740` | `primary-accessible` (proposed accessible token) | 0.15274 | **5.18:1** | 3.07:1 | **Passes on white** (5.18 >= 4.5) |
| `#C13515` | `primary-error-text` (inline error) | 0.13938 | **5.54:1** | 2.87:1 | **Passes on white** (5.54 >= 4.5) |
| `#222222` | `ink` (headline / body title) | 0.01600 | **15.91:1** | 1.00:1 | **Passes on white** (15.91 >= 4.5) |
| `#3F3F3F` | `body` (secondary running text) | 0.04971 | **10.53:1** | 1.51:1 | **Passes on white** (10.53 >= 4.5) |
| `#6A6A6A` | `muted` (sub-labels / inactive tabs) | 0.14413 | **5.41:1** | 2.94:1 | **Passes on white** (5.41 >= 4.5) |

### 14.3. Verified Corrections Applied Across Documentation
1. **Token Role Distinctions Clarified:**
   - **`primary` (`#FF385C`):** Canonical brand reference token from `DESIGN.md`. Used as default resting background for `button-primary`, search orb, and heart active save indicators. White text on `#FF385C` yields **3.52:1** (satisfies 3.0:1 for large text and non-text components, but fails 4.5:1 for normal text).
   - **`primary-active` (`#E00B41`):** Canonical active/press state token from `DESIGN.md` for `button-primary-active`. Its relative luminance is $L \approx 0.16468$, producing a contrast ratio of **4.89:1** against `#FFFFFF`. Documented strictly as the active press state, not a default resting CTA replacement.
   - **`primary-accessible` (`#D90740`):** Proposed project-specific accessible alternative token (not in `DESIGN.md`) designated for high-contrast accessibility mode where normal-sized white button text strictly requires $\ge 4.5:1$ contrast at rest. Its relative luminance is $L \approx 0.15274$, producing a contrast ratio of **5.18:1** against `#FFFFFF` (strictly exceeding 4.5:1).
2. **Reported Contrast Values Corrected:**
   - `#D90740`: Corrected relative luminance to **0.15274** and contrast ratio vs `#FFFFFF` to **5.18:1** (contrast vs `#222222` is **3.07:1**).
   - `#E00B41`: Verified relative luminance $L \approx 0.16468$, contrast ratio vs `#FFFFFF` is **4.89:1**.
   - `#C13515`: Verified relative luminance $L \approx 0.13938$, contrast ratio vs `#FFFFFF` is **5.54:1**.
   - `#222222` vs `#FFFFFF`: Refined to **15.91:1**; `#222222` vs `#FF385C` refined to **4.52:1**.
3. **Normal Text Threshold Verification on Proposed Backgrounds:**
   - Confirmed that white text on both proposed primary button backgrounds (`#E00B41` at **4.89:1** and `#D90740` at **5.18:1**) satisfies the WCAG AA minimum 4.5:1 requirement for normal text.
4. **Brand Reference Integrity:**
   - Preserved `#FF385C` as the canonical brand reference color from `DESIGN.md`. Documented that while white normal text on `#FF385C` falls short of 4.5:1 (achieving 3.52:1), it satisfies the 3.0:1 threshold for large text and non-text components.
5. **Non-Text Contrast Scope:**
   - Clarified across `04-ui-design-system.md`, `05-ux-guidelines.md`, and `07-testing-quality.md` that non-text contrast criteria (3.0:1 under WCAG SC 1.4.11) apply to visual information necessary to identify user interface components and states (such as active control boundaries, search orb bounds, and focus indicators) against adjacent backgrounds, where applicable.

### 14.4. Actual Verification Results
- `git diff --check`: Exit code 0 (clean, no trailing whitespace or formatting conflicts).
- `git status --short`: Exactly 8 documentation files modified under `Travel_Planner/docs/ai/`, alongside untracked `DESIGN.md`.
- Source Code Integrity: Zero `.dart`, `.java`, `.xml`, `.properties`, or `.yaml` files modified.

---

## 15. Session Entry: Final WCAG Pair Specification & Token Boundary Audit (2026-10-23)

### 15.1. Context and Objective
Conducted a final review of all WCAG documentation changes to ensure complete mathematical precision, explicit foreground/background pair declarations, faithful alignment with token definitions in `DESIGN.md`, and strict scope control.

### 15.2. Audited Corrections and Finalizations
1. **Kept Verified `#D90740` Numerical Values:**
   - Relative Luminance: $L \approx 0.15274$.
   - Contrast Ratio vs `#FFFFFF`: **5.18:1** (satisfies WCAG 2.1 AA 4.5:1 requirement for normal text).
   - Contrast Ratio vs `#222222`: **3.07:1**.
2. **Explicit Foreground/Background Pairs & Correct Criteria:**
   - Explicitly paired each contrast assertion:
     - White text (`#FFFFFF`) on resting `#FF385C` yields **3.52:1** (satisfies 3.0:1 for large text $\ge$ 18.66px bold or $\ge$ 24px regular and non-text component boundaries under SC 1.4.11, but fails 4.5:1 for normal text under SC 1.4.3).
     - White text (`#FFFFFF`) on `primary-active` (`#E00B41`) yields **4.89:1** (satisfies 4.5:1 for normal text under SC 1.4.3 during press).
     - White text (`#FFFFFF`) on proposed `primary-accessible` (`#D90740`) yields **5.18:1** (satisfies 4.5:1 for normal text under SC 1.4.3 at rest).
     - Dark `ink` text (`#222222`) on `#FF385C` yields **4.52:1** (satisfies 4.5:1 for normal text under SC 1.4.3).
     - Dark `ink` text (`#222222`) on `#FFFFFF` canvas yields **15.91:1**.
     - Dark `body` text (`#3F3F3F`) on `#FFFFFF` canvas yields **10.53:1**.
     - Error text `primary-error-text` (`#C13515`) on `#FFFFFF` canvas yields **5.54:1**.
   - Clarified that passing contrast ratios on these specific pairs satisfies contrast criteria (SC 1.4.3 and SC 1.4.11), but does not guarantee overall WCAG compliance on its own; overall compliance requires comprehensive verification of touch target sizing (48x48dp), keyboard navigation, focus indicators, and screen reader semantics.
3. **Preserved Canonical Brand Token `#FF385C` & Proposal Framing for `#D90740`:**
   - Maintained `#FF385C` (Rausch) as the canonical brand color across all primary CTAs, search orb, and heart active save indicators.
   - Framed `primary-accessible` (`#D90740`) strictly as a documented project design proposal for a potential high-contrast mode or strict 4.5:1 resting requirement, not proof or claim that a complete high-contrast mode already exists in the application.
4. **Confirmed Intended Meaning of `primary-active` (`#E00B41`) from `DESIGN.md`:**
   - Verified against `DESIGN.md` lines 8, 170-172, 351, and 454: `primary-active` is documented strictly as the press / pointer-down state variant for `button-primary-active`.
   - Eliminated any wording that conflated active with hover states or suggested repurposing it as a resting CTA replacement.
5. **Legacy Consistency Cleanup in Log:**
   - Corrected line 491 and 492 in Session 13 of `09-development-log.md` to eliminate legacy rough estimates (~5.4:1 and ~4.8:1) in favor of the exact recalculated values (4.89:1 and 5.18:1).
6. **Scope and File Isolation:**
   - Modifications remained strictly within documentation files under `Travel_Planner/docs/ai/`. Zero application source code (`.dart`, `.java`), configuration files, or database schemas were touched.

### 15.3. Actual Verification Results
- `git diff --check`: Exit code 0 (clean, no trailing whitespace or formatting conflicts).
- `git status --short`: Exactly 8 documentation files modified under `Travel_Planner/docs/ai/`, alongside untracked `DESIGN.md`.
- Source Code Integrity: Zero `.dart`, `.java`, `.xml`, `.properties`, or `.yaml` files modified.


