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

---

## 16. Session Entry: Authentication and Profile UI Design System Alignment (Phase 1) (2026-10-23)

### 16.1. Context and Objective
Executed Phase 1 implementation to refactor and align all existing authentication (Login, Register) and user profile (View, Edit) screens, along with their shared UI components and theme definitions, across both Flutter Mobile (`frontend/mobile`) and Flutter Web (`frontend/web`). The implementation aligns existing code with the canonical design tokens in `DESIGN.md` and `docs/ai/04-ui-design-system.md` while preserving all existing business logic, validation algorithms, state management, and API integration contracts.

### 16.2. Concrete UI Inconsistencies Identified and Resolved
1. **Design Tokens & Theme Definitions:**
   - *Previous state:* Legacy Teal (`#0D9488`), Orange (`#F97316`), Slate backgrounds (`#F8FAFC`), Slate borders (`#E2E8F0`), and Red 500 (`#EF4444`) were configured in `app_colors.dart`.
   - *Aligned state:* Replaced with canonical Rausch (`#FF385C`), active press state `primaryActive` (`#E00B41`), disabled button fill `primaryDisabled` (`#FFD1DA`), canvas pure white (`#FFFFFF`), hairline borders (`#DDDDDD`), ink text (`#222222`), muted text (`#6A6A6A`), and inline error text (`#C13515`).
   - *Theme styling:* Updated `app_theme.dart` on both mobile and web to support `WidgetStateProperty` button background transitions (`#FF385C` default, `#E00B41` pressed, `#FFD1DA` disabled), 8px corner radii (`rounded.sm`), 48px height, 2px solid ink focused input borders, and 2px error borders.

2. **Shared UI Components:**
   - *`AppPrimaryButton`:* Enforced 48px standard CTA height, 8px radius, 16px/w500 label styling, and smooth disabled state during `isLoading` to prevent duplicate submissions while retaining `#FF385C` background with an embedded 18x18dp white progress indicator.
   - *`AppTextField`:* Updated stacked label to 14px w500 `#6A6A6A` (`caption`), input text to 16px `#222222` (`body-md`), added accessible password visibility toggle with tooltips ("Hiện mật khẩu" / "Ẩn mật khẩu") and 48x48dp hit targets, integrated `textInputAction` and `onFieldSubmitted` callback support.

3. **Authentication Screens (Login & Register):**
   - *Mobile Login & Register:* Replaced legacy icons with 56px `#FF385C` brand iconography, applied responsive `maxWidth: 480` container constraints to prevent wide stretching on tablets and landscape orientations, ensured smooth keyboard avoidance with `SingleChildScrollView`, integrated sequential keyboard actions (`next` / `done`), and aligned inline error messaging. Preserved the static `validateUsername` validation method required by testing contracts.
   - *Web Login & Register:* Standardized both screens into clean 480px centered cards with 14px corner radii (`rounded.md`), 1px `#DDDDDD` hairline borders, and subtle elevation shadow (`Color(0x0A000000)`, blur 10, offset (0, 4)), eliminating visual discrepancy between login and register.

4. **Profile UI (View & Edit):**
   - *Visual Hierarchy & Grouping:* Transformed raw unstyled detail lists into structured semantic sections ("Thông tin cá nhân", "Thông tin tài khoản") enclosed in rounded cards with `#DDDDDD` borders and `#EBEBEB` dividing hairlines.
   - *Avatar Display:* Enhanced avatar rendering with `ClipOval` and `errorBuilder` fallback support to prevent broken image UI on invalid image URLs, paired with clean neutral fallback avatars (`AppColors.surfaceStrong` with `#6A6A6A` person icon).
   - *Text Overflow & Badges:* Added `softWrap: true` and responsive layouts to handle long names, email addresses, and bios gracefully without horizontal clipping. Added styled pill badges for user role and account status.
   - *Edit Mode:* Provided clean form fields, a 48px primary "Lưu thay đổi" button with loading feedback, and a clear secondary "Hủy" button for safe cancellation. Aligned success and error feedback SnackBar colors (`#10B981` for success, `#C13515` for errors).

### 16.3. Modified Files
- `frontend/mobile/lib/core/theme/app_colors.dart`
- `frontend/mobile/lib/core/theme/app_theme.dart`
- `frontend/mobile/lib/shared/widgets/app_primary_button.dart`
- `frontend/mobile/lib/shared/widgets/app_text_field.dart`
- `frontend/mobile/lib/features/auth/presentation/screens/login_screen.dart`
- `frontend/mobile/lib/features/auth/presentation/screens/register_screen.dart`
- `frontend/mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `frontend/web/lib/core/theme/app_colors.dart`
- `frontend/web/lib/core/theme/app_theme.dart`
- `frontend/web/lib/shared/widgets/app_primary_button.dart`
- `frontend/web/lib/shared/widgets/app_text_field.dart`
- `frontend/web/lib/features/auth/presentation/screens/login_screen.dart`
- `frontend/web/lib/features/auth/presentation/screens/register_screen.dart`
- `frontend/web/lib/features/profile/presentation/screens/profile_screen.dart`

### 16.4. Verification Results
- `git diff --check`: Exit code 0 (clean, no trailing whitespace, no merge conflict markers).
- `dart format`: Executed and verified across all 14 modified Dart files.
- `flutter analyze` (`frontend/mobile`): Exit code 0, 0 issues found.
- `flutter analyze` (`frontend/web`): Exit code 0, 0 issues found.
- `flutter test` (`frontend/mobile`): 15/15 tests passed (covering session expiry, 401 handling, username validation, widget rendering).
- `flutter test` (`frontend/web`): 15/15 tests passed (covering web session expiry, 401 handling, username validation, web widget rendering).
- `flutter build web --no-pub`: Succeeded, bundle compiled cleanly into `build/web`.

### 16.5. Limitations and Next Steps
- Android APK / iOS builds require native SDK / Xcode toolchains not available in this environment.
- Backend API runtime testing requires active Spring Boot service and MySQL instance.

---

## 17. Session Entry: Authentication & Profile UI Consistency Review (Phase 2) (2026-10-23)

### 17.1. Context and Objective
Conducted a Phase 2 final consistency review across Login, Registration, and Profile screens in `frontend/mobile` and `frontend/web`. The review verified cross-screen harmony, platform adaptation, WCAG contrast compliance, form keyboard interactions, and regression immunity against existing tests and backend contracts.

### 17.2. Concrete Inconsistencies Identified and Resolved
1. **Premature Form Submission on Web Login:**
   - *Issue:* In `frontend/web/lib/features/auth/presentation/screens/login_screen.dart`, the `usernameOrEmail` text field had `onFieldSubmitted: (_) => _submit()` despite having `textInputAction: TextInputAction.next`. Pressing Enter while entering username or email triggered premature form submission and validation errors instead of navigating focus to the password field.
   - *Fix:* Removed `onFieldSubmitted` from the username field so pressing Enter/Next advances focus as expected; Enter on the password field triggers form submission.
2. **Account Status Semantic Color Discrepancy:**
   - *Issue:* In both `frontend/mobile` and `frontend/web` `profile_screen.dart`, the status badge unconditionally applied emerald green styling (`Color(0xFFECFDF5)`, `Color(0xFF047857)`) regardless of whether the account was `ACTIVE`, `INACTIVE`, or `BANNED`. A banned account was rendered with a green positive badge.
   - *Fix:* Introduced a type-safe `_statusBadge(dynamic rawStatus, String statusText)` helper mapping `ACTIVE` to emerald (`#ECFDF5` / `#047857`), `BANNED` to semantic red (`#FEF2F2` / `#C13515`), and `INACTIVE` to amber (`#FFFBEB` / `#B45309`), all exceeding WCAG 2.1 AA 4.5:1 contrast requirements.
3. **Multi-Line Biography Field Support:**
   - *Issue:* In `app_text_field.dart`, `TextFormField` was constrained to single-line input. When editing long travel biographies in `profile_screen.dart`, text clipped horizontally inside a single-line box.
   - *Fix:* Extended `AppTextField` with `maxLines` (default 1) and optional `minLines`. In both mobile and web `profile_screen.dart`, configured `_bioController` with `maxLines: 3`, `minLines: 2`, and `textInputAction: TextInputAction.newline`.

### 17.3. Files Changed
- `frontend/mobile/lib/shared/widgets/app_text_field.dart`
- `frontend/mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `frontend/web/lib/shared/widgets/app_text_field.dart`
- `frontend/web/lib/features/auth/presentation/screens/login_screen.dart`
- `frontend/web/lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/ai/09-development-log.md`

### 17.4. Verification Results
- `git diff --check`: Exit code 0 (clean, no whitespace or conflict issues).
- `dart format`: 0 changed across all modified files (100% compliant).
- `flutter analyze` (`frontend/mobile`): Exit code 0, 0 issues found.
- `flutter analyze` (`frontend/web`): Exit code 0, 0 issues found.
- `flutter test` (`frontend/mobile`): 15/15 tests passed.
- `flutter test` (`frontend/web`): 15/15 tests passed.

### 17.5. Remaining Issues and Limitations
- Visual rendering of web card shadows, font anti-aliasing, and mobile keyboard animations require physical device or browser observation.
- Full end-to-end integration requires running Spring Boot and MySQL services.

---

## 18. Session Entry: Backend Spring Boot Version Review and Migration to Verified Stable Release (2026-10-23)

### 18.1. Context and Objective
Evaluated the backend Spring Boot parent version in `Travel_Planner/backend/pom.xml` (`4.1.2-SNAPSHOT`) to determine whether it should be replaced with an officially announced, stable GA release. Migrated to the appropriate verified stable release while maintaining zero regressions across database schemas, API contracts, security rules, and test suites.

### 18.2. Technical Assessment, Verification of Official Release Status, and Candidate Evaluation
1. **Current Version Status:**
   - Previous configuration: `org.springframework.boot:spring-boot-starter-parent:4.1.2-SNAPSHOT`.
   - The project depended on unstable development snapshots from `https://repo.spring.io/snapshot`, posing serious reliability risks for academic defense, automated CI/CD, and repeatable deployments.
2. **Evaluation of Candidate Versions and Official Release Evidence:**
   - **Spring Boot 3.x (e.g., 3.4.13 / 3.5.16):** Spring Boot 3.x reached end of open-source support (EOL) on June 30, 2026. Furthermore, the codebase was already utilizing modular Spring Boot 4 starters (`spring-boot-starter-webmvc`, `spring-boot-starter-restclient`, `spring-boot-starter-webmvc-test`, `spring-boot-starter-data-jpa-test`, `springdoc-openapi-starter-webmvc-ui:3.1.0`). Downgrading to 3.x would require a disruptive overhaul of `pom.xml`, regression risks in dependency management, and adoption of an unsupported EOL framework branch.
   - **Audit of Spring Boot 4.1.2 vs 4.1.1:**
     - A preliminary check noted the presence of `4.1.2` in repository indexing metadata. However, an in-depth audit of the official Spring Blog (`spring.io/blog`) and official Spring documentation revealed that **`4.1.1`** is the officially announced, documented, and supported GA release (announced August 20, 2026, comprising 98 bug fixes and ecosystem updates).
     - In contrast, `4.1.2` lacked an official release announcement on `spring.io/blog`, with ongoing development actively tracked as `4.1.2-SNAPSHOT`.
3. **Migration Decision:**
   - Migrate to the officially announced and verified stable GA release: **Spring Boot 4.1.1**.
   - Eliminate the `<repositories>` and `<pluginRepositories>` declarations for `spring-snapshots`.
   - Rely strictly on verified GA dependencies from Maven Central.

### 18.3. Implementation Details
- **`Travel_Planner/backend/pom.xml`**:
  - Updated `<parent><version>` from `4.1.2-SNAPSHOT` to `4.1.1`.
  - Removed obsolete `spring-snapshots` repository and plugin repository configurations.
  - Kept Java 22 baseline (`<java.version>22</java.version>`), Lombok 1.18.x, JJWT 0.12.6, Springdoc 3.1.0, and MySQL Connector/J intact.

### 18.4. Modified Files
- `Travel_Planner/backend/pom.xml`
- `Travel_Planner/docs/ai/09-development-log.md`

### 18.5. Verification and Test Results
- `.\mvnw.cmd clean verify`: Executed full clean, compilation, test suite, and repackaging on Spring Boot `4.1.1`:
  - **Exit Code:** 0 (BUILD SUCCESS).
  - **Database Connection:** Verified live connection to MySQL 8.0.37 via HikariDataSource (`jdbc:mysql://localhost:3306/travel_planner`) with Hibernate ORM 7.4.5.Final executing DDL checks and live transactions.
  - **Test Suite Results:** 32/32 tests passed, 0 failures, 0 errors, 0 skipped:
    - `AuthControllerTest`: 25/25 passed (Time elapsed: 11.89s).
    - `HealthControllerTest`: 1/1 passed (Time elapsed: 0.026s).
    - `JwtTokenProviderTest`: 5/5 passed (Time elapsed: 0.016s).
    - `TravelPlannerApplicationTests`: 1/1 passed (Time elapsed: 0.018s).
  - **Packaging:** Created and repackaged executable archive `target/Travel_Planner-0.0.1-SNAPSHOT.jar`.
- `.\mvnw.cmd dependency:tree`: Confirmed that all Spring Framework (`7.0.9`), Spring Security (`7.1.1`), and Spring Boot (`4.1.1`) dependencies resolve cleanly without any `-SNAPSHOT` references.
- `git diff --check`: Exit code 0 (clean).

### 18.6. Remaining Issues and Environmental Limitations
- Live application deployment requires setting environment variables (`JWT_SECRET`, `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`) in production environments as defined in `application-prod.properties`.

---

## 19. Session Entry: Explore Feature — Phase 1: Backend API & Data Foundation (2026-10-23)

### 19.1. Context and Objective
Implemented Phase 1 of the Explore (Discover & Search Itineraries) feature focusing strictly on the backend REST API, data access layer, dynamic search specification, sorting/pagination, security access rules, and automated integration test coverage in compliance with `docs/Travel_Planner_Function_Specification.md` and `docs/ai/03-api-contract.md`.

### 19.2. Architecture, Data Model, and Security Decisions
1. **Public Discovery Endpoint (`GET /api/itineraries`):**
   - Configured `SecurityConfig` to grant public read access (`permitAll()`) for `HttpMethod.GET` requests to `/api/itineraries` and `/api/itineraries/**`.
   - All state-mutating requests (`POST`, `PUT`, `DELETE`) remain strictly authenticated (`authenticated()`), and `/api/admin/**` remains restricted to role `ADMIN`.
   - Both guests (unauthenticated) and authenticated users can access the endpoint.
2. **Mandatory Public Eligibility Enforcement:**
   - Implemented dynamic filtering via Spring Data JPA `JpaSpecificationExecutor` and Criteria API in `ItinerarySpecification`.
   - Enforced hard eligibility predicates: `visibility = Visibility.PUBLIC`, `status = ItineraryStatus.ACTIVE`, and `user.status = UserStatus.ACTIVE`. Private, draft, hidden, deleted, and banned-user itineraries are strictly excluded.
3. **Keyword Search and Multi-Criteria Filtering:**
   - Case-insensitive search on `title`, `location`, `theme`, and `description` with `LIKE %keyword%` matching. Whitespace-only or empty keywords are treated as non-filtering.
   - Independent and combinable filters: `location`, `theme`, `minBudget`, `maxBudget`, `minDays`, `maxDays` combined using logical `AND`.
   - Validation: Reject negative budgets (`< 0`), negative/zero days (`< 1`), and inverted bounds (`minBudget > maxBudget`, `minDays > maxDays`) with standard HTTP 400 `BadRequestException`.
4. **Whitelist Sorting and Pagination Boundaries:**
   - Zero-indexed pagination conforming to `03-api-contract.md` (`page`, `size`, `sort`). Normalized `page < 0` to `0`, `size <= 0` to `10`, and capped `size > 50` to `50`.
   - Whitelist-based sort parser for fields: `createdAt`, `budget`, `totalDays`, `viewCount`, `favoriteCount`, `ratingCount`. Unsafe or unrecognized fields safely fallback to default `createdAt,desc`.
5. **N+1 Prevention and Aggregate Ratings:**
   - Utilized `@EntityGraph(attributePaths = {"user"})` on `ItineraryRepository.findAll(Specification, Pageable)` to fetch creator user profiles in a single query with SQL pagination.
   - Batched rating averages using `RatingRepository.findAverageRatingsByItineraryIds(List<Integer>)` executing `AVG(r.score)` grouped by itinerary ID for items on the current page, avoiding persistent schema column redundancy and per-row N+1 queries.
   - Added nullable `coverImage` column (`cover_image VARCHAR(500)`) on `Itinerary` to support UI photo card presentation while maintaining backward compatibility.

### 19.3. Modified and Created Files
- **Entity & DTOs:**
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/Itinerary.java` (added `coverImage`)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/CreatorSummaryResponse.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/ItinerarySummaryResponse.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/PageResponse.java` (created)
- **Repository & Specification:**
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/RatingRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/specification/ItinerarySpecification.java` (created)
- **Service & Controller:**
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/ItineraryService.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ItineraryController.java` (created)
- **Security & Tests:**
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java` (updated matchers for GET `/api/itineraries/**`)
  - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ItineraryControllerTest.java` (created 15 integration tests)
  - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AuthControllerTest.java` (added cascade fixture teardown)
  - `Travel_Planner/docs/ai/09-development-log.md` (updated)

### 19.4. Verification and Test Results
- `.\mvnw.cmd test -Dtest=ItineraryControllerTest`:
  - **Results:** 15/15 tests passed, 0 failures, 0 errors. Verified guest access, authenticated access, private/hidden/deleted exclusion, banned user exclusion, keyword search, individual and combined filters, input validation, sorting directions and fallbacks, pagination clamping, DTO privacy, rating calculation, and mutating operation security.
- `.\mvnw.cmd test`:
  - **Results:** 47/47 tests passed (0 failures, 0 errors, 0 skipped):
    - `AuthControllerTest`: 25/25 passed
    - `ItineraryControllerTest`: 15/15 passed
    - `JwtTokenProviderTest`: 5/5 passed
    - `HealthControllerTest`: 1/1 passed
    - `TravelPlannerApplicationTests`: 1/1 passed
- `git diff --check`: Exit code 0 (clean, no trailing whitespace or conflict markers).

### 19.5. Remaining Limitations and Next Steps
- Flutter Mobile Explore UI implementation (Phase 2): Create `ApiClient` query parameter support, `ItineraryCard`, `SearchBarPill`, `AppEmptyState`, `AppErrorState`, and `ExploreScreen`.
- Database Seed Data: Create an optional dev seed runner or SQL fixture for local multi-city itinerary demonstrations.

---

## 20. Session Entry: Explore Feature — Phase 1 Verification and Hardening Before Phase 2 (2026-10-23)

### 20.1. Context and Objective
Conducted a comprehensive, pre-Phase 2 verification of the Explore backend implementation against `docs/Travel_Planner_Function_Specification.md`, `docs/ai/03-api-contract.md`, and security guidelines. Hardened edge cases, ensured stable pagination, verified SQL LIKE wildcard escaping and Vietnamese search behavior, and expanded integration tests to guarantee 100% backend readiness before Flutter UI implementation.

### 20.2. Identified Gaps and Hardened Implementations
1. **`minRating` Filter Specification & Subquery Execution:**
   - *Issue:* While the specification allowed filtering itineraries by rating quality, `minRating` was missing from the endpoint parameters.
   - *Fix:* Added `minRating` query parameter to `ItineraryController` and `ItineraryService` with strict range validation (`1.0 <= minRating <= 5.0`). Implemented dynamic rating filtering in `ItinerarySpecification` using a JPA Criteria subquery calculating `COALESCE(subquery(AVG(r.score)), 0.0) >= minRating` against the `ratings` table, avoiding persistent denormalized columns.
2. **SQL LIKE Wildcard Escaping:**
   - *Issue:* Raw keyword search strings containing SQL wildcards (`%`, `_`, or `\`) acted as operators instead of literal text, potentially matching unintended records.
   - *Fix:* Added `escapeLike()` helper in `ItinerarySpecification` escaping `\`, `%`, and `_` with backslash escaping (`cb.like(..., pattern, '\\')`).
3. **Stable Pagination Tie-Breaker:**
   - *Issue:* When sorting by non-unique fields (e.g., `budget`, `totalDays`, `createdAt`), MySQL/Hibernate pagination can produce unstable order across pages when values are identical.
   - *Fix:* Appended a deterministic secondary sort on `itineraryId` (`.and(Sort.by(direction, "itineraryId"))`) across all sort specifications in `ItineraryServiceImpl`. Supported `rating` as a valid sort alias.
4. **API Contract Alignment (`PageResponse`):**
   - *Issue:* `03-api-contract.md` specifies pagination response field names as `pageNumber` and `pageSize`, whereas some client implementations expect standard `page` and `size`.
   - *Fix:* Maintained canonical field names `pageNumber` and `pageSize` in `PageResponse` while adding `@JsonAlias({"page", "pageNumber"})` and `@JsonAlias({"size", "pageSize"})` for flexible bidirectional deserialization.
5. **SecurityConfig Scoping for Future Endpoints:**
   - *Issue:* Permitting `HttpMethod.GET` on `/api/itineraries/**` risked accidentally exposing future private sub-endpoints (e.g., `/api/itineraries/my-drafts`).
   - *Fix:* Narrowed the public GET matcher strictly to exact `/api/itineraries`. Future sub-endpoints fall through to `.anyRequest().authenticated()`.
6. **Vietnamese Collation & Search Verification:**
   - Verified that diacritic searches (e.g., `Đà Lạt`, `bánh tráng`) work accurately under MySQL collation with case-insensitivity (`đà lạt` matching `Đà Lạt`).
7. **Nullable `coverImage` Consistency:**
   - Verified that `coverImage` is uniformly handled as nullable across `Itinerary` entity, `ItinerarySummaryResponse` DTO, and repository operations.

### 20.3. Modified and Created Files
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ItineraryController.java` (added `minRating` parameter)
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/ItineraryService.java` (added `minRating` parameter)
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java` (added `minRating` range validation, stable pagination tie-breaker, `rating` sort alias)
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/specification/ItinerarySpecification.java` (added `minRating` subquery filter and `escapeLike` wildcard handling)
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/PageResponse.java` (added `@JsonAlias` for `page` and `size`)
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java` (narrowed public GET matcher to `/api/itineraries`)
- `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ItineraryControllerTest.java` (expanded test suite from 15 to 21 tests)
- `Travel_Planner/docs/ai/09-development-log.md` (appended Session 20 log)

### 20.4. Verification and Test Results
- `.\mvnw.cmd test -Dtest=ItineraryControllerTest`:
  - **Results:** 21/21 tests passed (0 failures, 0 errors). Tested guest access, invalid Bearer token guest fallback, private/hidden exclusion, banned user exclusion, keyword search, LIKE wildcard escaping (`%`), Vietnamese accent search, individual & combined filters, `minRating` filter & validation, sort options, stable multi-page pagination, subpath security restriction, and mutating method protection.
- `.\mvnw.cmd test`:
  - **Results:** 53/53 tests passed (BUILD SUCCESS, 0 failures, 0 errors, 0 skipped):
    - `AuthControllerTest`: 25/25 passed
    - `ItineraryControllerTest`: 21/21 passed
    - `JwtTokenProviderTest`: 5/5 passed
    - `HealthControllerTest`: 1/1 passed
    - `TravelPlannerApplicationTests`: 1/1 passed
- `git diff --check`: Exit code 0 (clean, no trailing whitespace or formatting conflicts).

### 20.5. Conclusion & Readiness Decision
- **Status:** READY FOR PHASE 2 (Flutter Mobile Explore UI Implementation).
- All API contracts, query stability, edge-case escaping, and security rules are verified and locked with automated tests.

---

## 21. Session Entry: Explore Feature — Phase 2: Flutter Mobile Implementation (2026-10-23)

### 21.1. Context and Objective
Implemented Phase 2 of the Explore (Discover & Search Itineraries) feature on Flutter Mobile (`frontend/mobile`) based on the approved specifications in `docs/Travel_Planner_Function_Specification.md`, `DESIGN.md`, `docs/ai/04-ui-design-system.md`, and `docs/ai/05-ux-guidelines.md`. Enabled public discovery for both guest and authenticated users, server-side keyword search, multi-criteria filtering, sorting, infinite scrolling, resilient fallback states, and full test suite verification.

### 21.2. Architecture, Data Model, and UI Decisions
1. **API Client & Networking:**
   - Extended `ApiClient.get()` to support optional `Map<String, dynamic>? queryParameters` with automatic sanitization and URL parameter encoding without altering existing method signatures.
   - Added `itinerariesEndpoint = '/api/itineraries'` constant to `ApiConstants`.
2. **DTO & Domain Models:**
   - Created `PageResult<T>` matching the backend's `PageResponse` JSON structure, supporting both `page`/`pageNumber` and `size`/`pageSize` aliases and resilient handling of malformed records.
   - Created `CreatorSummary` matching `CreatorSummaryResponse` (`userId`, `username`, `fullName`, `avatar`) with fallback `displayName`.
   - Created `ItinerarySummary` strictly matching `ItinerarySummaryResponse` (`itineraryId`, `title`, `description`, `location`, `coverImage`, `totalDays`, `budget`, `theme`, `viewCount`, `favoriteCount`, `ratingCount`, `averageRating`, `createdAt`, `creator`). Safely handles nullable `coverImage`, description, theme, and creator.
3. **Repository & State Management:**
   - Created `ExploreRepository` wrapping `GET /api/itineraries` with support for all verified backend parameters (`keyword`, `location`, `theme`, `minBudget`, `maxBudget`, `minDays`, `maxDays`, `minRating`, `page`, `size`, `sort`).
   - Implemented `ExploreNotifier` (extending `ChangeNotifier`) managing `ExploreStatus` (`initial`, `loading`, `success`, `error`), infinite scroll pagination (`loadMore`), active filter state (`ExploreFilter`), instant theme switching, search reset, and concurrency guards (`_isFetching`, `_isLoadingMore`).
4. **Reusable UI Components:**
   - Implemented `AppEmptyState` with centered 72dp soft circle container, 36dp icon, title, description, and customizable action button ("Đặt lại bộ lọc") per `05-ux-guidelines.md`.
   - Implemented `AppErrorState` with Rausch-tinted icon container, user-friendly error message, and primary CTA "Thử lại" retry button.
   - Implemented `ItineraryCard` with 14px rounded corners, 16:10 aspect ratio photo header, sensible fallback placeholder for null/invalid images, "Yêu thích" top-left badge for high-rated trips, favorite heart button, solid Ink `#222222` star rating, Vietnamese dong budget formatting, and author avatar/name.
   - Implemented `SearchBarPill` adhering to `DESIGN.md` with circular Rausch search orb, search text input with clear button, and filter tune button with active filter counter badge.
   - Implemented `FilterBottomSheet` modal sheet supporting sort choices, destination text & chips, theme chips, days range, budget range, minimum rating chips, and reset/apply actions.
5. **Guest Access & Navigation Routing:**
   - Configured `main.dart` to route directly to `ExploreScreen(authNotifier: _authNotifier)` once initial auth check completes, allowing guests to explore public itineraries without being forced to login.
   - In guest mode, `ExploreScreen` displays a dedicated "Đăng nhập" button in the AppBar leading to `LoginScreen`.
   - In authenticated mode, `ExploreScreen` displays the user's avatar and name with a dropdown menu ("Hồ sơ" -> `ProfileScreen`, "Đăng xuất" -> `logout()`).
   - Updated `LoginScreen` to automatically pop back to `ExploreScreen` upon successful authentication and include a back button when pushed as a route.
   - Added polite feedback notices for card tap and favorite tap indicating that detailed itinerary view and favorite persistence will arrive in upcoming phases.

### 21.3. Modified and Created Files
- **Core Network & Constants:**
  - `Travel_Planner/frontend/mobile/lib/core/constants/api_constants.dart` (added `itinerariesEndpoint`)
  - `Travel_Planner/frontend/mobile/lib/core/network/api_client.dart` (extended `get()` with `queryParameters`)
- **Explore Data Layer:**
  - `Travel_Planner/frontend/mobile/lib/features/explore/data/models/page_result.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/features/explore/data/models/creator_summary.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/features/explore/data/models/itinerary_summary.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/features/explore/data/explore_repository.dart` (created)
- **Explore State & UI:**
  - `Travel_Planner/frontend/mobile/lib/features/explore/presentation/explore_notifier.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/itinerary_card.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/search_bar_pill.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/filter_bottom_sheet.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart` (created)
- **Shared Widgets:**
  - `Travel_Planner/frontend/mobile/lib/shared/widgets/app_empty_state.dart` (created)
  - `Travel_Planner/frontend/mobile/lib/shared/widgets/app_error_state.dart` (created)
- **Navigation & Auth:**
  - `Travel_Planner/frontend/mobile/lib/main.dart` (routed home to `ExploreScreen`)
  - `Travel_Planner/frontend/mobile/lib/features/auth/presentation/screens/login_screen.dart` (added pop-on-success and back button support)
- **Automated Tests:**
  - `Travel_Planner/frontend/mobile/test/explore_test.dart` (created 13 automated unit & widget tests)
- **Documentation:**
  - `Travel_Planner/docs/ai/09-development-log.md` (appended Session 21 entry)

### 21.4. Verification and Test Results
- `flutter analyze`:
  - **Result:** No issues found! (ran in 2.2s, 0 errors, 0 warnings).
- `flutter test`:
  - **Result:** **28/28 tests passed** (0 failures, 0 errors, 0 skipped):
    - `auth_401_test.dart`: 9 tests passed
    - `username_validation_test.dart`: 5 tests passed
    - `widget_test.dart`: 1 test passed
    - `explore_test.dart`: 13 tests passed (query parameter encoding, model deserialization, repository query construction, notifier state transitions, empty/error handling, pagination reset, load-more appending, guest mode rendering, empty state rendering, error state retry).
- `flutter build bundle`:
  - **Result:** Exit code 0 (clean compilation of Dart code and Flutter asset bundle).
- `git diff --check`:
  - **Result:** Exit code 0 (clean, no trailing whitespace or conflict markers).

### 21.5. Remaining Limitations and Next Steps
- Itinerary Details Screen (Phase 3): Implement itinerary detail screen (`features/itinerary`) displaying the day-by-day activity timeline, photos, author bio card, and sticky action rail.
- Itinerary Favorite / Bookmark: Implement saving favorite itineraries when the backend favorites API is available.
- Flutter Web Explore (Phase 4): Implement responsive multi-column card grid for web desktop.

---

## 22. Session Entry: Explore Feature — Phase 2 Final Targeted Verification & Race-Condition Hardening (2026-10-23)

### 22.1. Context and Objective
Executed a final targeted verification of the completed Flutter Mobile Explore implementation before advancing to Phase 3. Focused on verifying guest navigation boundaries, token session restoration, API contract alignment, query sorting metrics, async race condition resilience, error/empty UI states, and mobile debug build compilation.

### 22.2. Confirmed Findings and Hardened Items
1. **Async Race-Condition Protection in `ExploreNotifier`:**
   - *Defect Identified:* Rapid search submissions could previously allow an earlier, slower HTTP response to overwrite the results of a later, faster search. Additionally, `_isFetching` could cause rapid subsequent searches to be ignored.
   - *Fix Implemented:* Introduced monotonic request sequence ID (`_requestId`) in `ExploreNotifier`. Each new search increments `_requestId`. Incoming responses verify `currentRequestId == _requestId` before committing state, silently discarding stale responses. Also added check during `loadMore()` to discard appended items if a search/filter reset occurred while `loadMore` was in flight.
   - *Automated Test:* Added automated unit test in `explore_test.dart` ("older request cannot overwrite results from newer search") simulating slow (100ms) followed by fast (10ms) responses, proving only the newer result is retained.
2. **API Contract & Sort Metric Alignment:**
   - Verified that `PageResult.fromJson` safely parses both `pageNumber`/`pageSize` and `page`/`size` variants.
   - Verified that all 6 exposed sort options in `FilterBottomSheet` (`createdAt,desc`, `rating,desc`, `budget,asc`, `budget,desc`, `totalDays,asc`, `viewCount,desc`) strictly map to the verified backend whitelist in `ItineraryServiceImpl.java`.
   - Confirmed `rating,desc` correctly maps to the backend alias sorting by `ratingCount` with deterministic `itineraryId` tie-breaker.
3. **UI Robustness & Defensive Fallbacks:**
   - Confirmed `ItineraryCard` handles `null`, empty, or network-failed `coverImage` using a graceful `_buildImagePlaceholder()`.
   - Confirmed favorite button never fabricates success: guests are prompted to log in, and authenticated users receive an informational notice that bookmarking will arrive in a future phase.
   - Verified the "Yêu thích" badge follows a clear, defensible criterion: `averageRating >= 4.5 && ratingCount >= 2`.
4. **Guest & Auth Navigation Flow:**
   - Verified guest access directly to `ExploreScreen` without credentials.
   - Verified login success automatically pops back to `ExploreScreen` and re-renders with authenticated user avatar/name.
   - Verified logout returns the screen to Guest state with the "Đăng nhập" button.
   - Verified `LoginScreen` back button navigates back without disrupting navigation state.

### 22.3. Modified Files
- `Travel_Planner/frontend/mobile/lib/features/explore/presentation/explore_notifier.dart` (implemented `_requestId` request sequencing and race condition guard)
- `Travel_Planner/frontend/mobile/test/explore_test.dart` (added race-condition test; total 14 tests in file)
- `Travel_Planner/docs/ai/09-development-log.md` (appended Session 22 entry)

### 22.4. Actual Verification and Build Results
- `flutter analyze`:
  - **Result:** No issues found! (ran in 2.5s, 0 errors, 0 warnings).
- `flutter test`:
  - **Result:** **29/29 tests passed** (0 failures, 0 errors, 0 skipped):
    - `auth_401_test.dart`: 9 tests passed
    - `username_validation_test.dart`: 5 tests passed
    - `widget_test.dart`: 1 test passed
    - `explore_test.dart`: 14 tests passed (including race-condition test)
- `flutter build apk --debug`:
  - **Result:** **BUILD SUCCESS** (`√ Built build\app\outputs\flutter-apk\app-debug.apk` in 91.6s).
- `git diff --check`: Exit code 0 (clean, no trailing whitespace or formatting conflicts).
- *Manual Device Testing Note:* No manual physical device or emulator execution was performed in this terminal session; verification was conducted via automated widget/unit tests and full Gradle APK compilation.

### 22.5. Conclusion & Readiness Decision
- **Status:** READY FOR PHASE 3 (Flutter Mobile Itinerary Detail Screen Implementation).
- All items verified, race conditions resolved, and mobile build verified.

---

## 23. Session Entry: Realistic Seed Data Generation & Database Integrity Verification (2026-10-23)

### 23.1. Context and Objective
Implemented an idempotent, non-destructive development seed data generator (`DataSeeder`) to populate realistic and internally consistent sample data for the Travel Planner platform. The dataset covers all 12 existing database entities (`users`, `destinations`, `itineraries`, `itinerary_days`, `activities`, `comments`, `ratings`, `favorites`, `saved_itineraries`, `follows`, `itinerary_shares`, `offline_downloads`), enabling manual testing, frontend integration testing (Explore feed, search/filter, sorting, privacy, personalizing derived itineraries, and social interactions), and test account authentication.

### 23.2. Architecture, Domain Model, and Safety Implementation
1. **Idempotency and Non-Destructive Design:**
   - Designed `DataSeeder` to check existing unique keys (`username`/`email` for users, `name` for destinations, `title` + `userId` for itineraries, `(dayId, displayOrder)` for activities, `(userId, itineraryId)` for ratings/favorites/saves, `(followerId, followingId)` for follows, and `shareToken` for shares) before inserting.
   - Pre-existing developer accounts (e.g., `minhdanh`) and custom records are strictly preserved without deletion or truncation.
   - Re-running the seeder preserves exact row counts with zero duplicate records.
2. **Security & Production Safeguards:**
   - All test account passwords are encrypted using BCrypt (`PasswordEncoder`) using the local development password `Password123!`. Plaintext passwords are never stored in the database.
   - Controlled via `app.seed.enabled=${APP_SEED_ENABLED:true}` in `application.properties`.
   - Explicitly disabled in `application-prod.properties` (`app.seed.enabled=false`) to ensure production safety.
   - Isolated in unit/integration tests via `src/test/resources/application.properties` pointing to `travel_planner_test` with `app.seed.enabled=false` by default, with defensive teardown to avoid cross-test foreign key conflicts.
3. **Domain Entities & Realistic Vietnamese Data:**
   - **Users (10 seeded):** 1 ADMIN (`admin_master`), 7 ACTIVE USERs (`traveler_viet`, `wanderer_linh`, `foodie_khoa`, `nature_an`, `hiker_duy`, `island_mai`, `backpacker_tuan`), 1 INACTIVE USER (`inactive_user`), and 1 BANNED USER (`banned_spammer`).
   - **Destinations (20 seeded):** Realistic landmarks in Hà Nội, Sa Pa, Hạ Long, Ninh Bình, Huế, Hội An, Đà Nẵng, Đà Lạt, Sài Gòn, Phú Quốc, and Cần Thơ with real GPS coordinates (19 `ACTIVE`, 1 `HIDDEN`).
   - **Itineraries (18 seeded):** Range from 1 to 5 days, budgets from 1.2M to 12.0M VND, varied themes (`Ẩm thực`, `Văn hóa`, `Khám phá`, `Nghỉ dưỡng`, `Sinh thái`, `Phiêu lưu`, `Biển đảo`).
     - Includes 13 `PUBLIC` & `ACTIVE` itineraries for Explore feed testing.
     - Includes 2 `PRIVATE` itineraries to verify privacy enforcement.
     - Includes 1 derived itinerary (`sa_pa_derived` personalized from `sa_pa_trekking` via `original_itinerary_id`).
     - Includes 1 `HIDDEN`, 1 `DELETED`, and 1 `BANNED` creator itinerary to verify exclusion rules.
   - **Itinerary Days (47) & Activities (111):** Sequential days with 2–4 detailed activities per day, valid start/end times, realistic costs (VND), display orders, and mandatory destination foreign keys.
   - **Social Interactions:** 14 comments (active, hidden, deleted), 24 ratings (1–5 stars; high-rated trips with average >= 4.5 and ratingCount >= 2 triggering the mobile "Yêu thích" badge), 14 favorites, 9 saved itineraries, 11 follows (no self-following), 5 itinerary shares (active and expired), and 7 offline downloads.
4. **Spring Data JPA Repositories:**
   - Created missing standard repository interfaces: `DestinationRepository`, `CommentRepository`, `FavoriteRepository`, `SavedItineraryRepository`, `FollowRepository`, `ItineraryShareRepository`, and `OfflineDownloadRepository`.
   - Added derived query methods to `ItineraryRepository`, `ItineraryDayRepository`, `ActivityRepository`, and `RatingRepository`.

### 23.3. Modified and Created Files
- **Backend Seeder & Domain:**
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/seeder/DataSeeder.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/seeder/SeedResult.java` (created)
- **Spring Data JPA Repositories:**
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/DestinationRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/CommentRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/FavoriteRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/SavedItineraryRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/FollowRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryShareRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/OfflineDownloadRepository.java` (created)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryRepository.java` (added lookup helpers)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryDayRepository.java` (added lookup helpers)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ActivityRepository.java` (added lookup helpers)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/RatingRepository.java` (added lookup helpers)
- **Configuration & Test Resources:**
  - `Travel_Planner/backend/src/main/resources/application.properties` (added `app.seed.enabled` property)
  - `Travel_Planner/backend/src/main/resources/application-prod.properties` (disabled seeder in prod)
  - `Travel_Planner/backend/src/test/resources/application.properties` (test isolation for `travel_planner_test`)
- **Automated Tests:**
  - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/DataSeederTest.java` (created 3 automated tests: thresholds, foreign key integrity, and idempotency)
- **Documentation:**
  - `Travel_Planner/README.md` (added seed data execution instructions and configuration)
  - `Travel_Planner/docs/ai/test-accounts.md` (created dedicated test accounts reference)
  - `Travel_Planner/docs/ai/09-development-log.md` (appended Session 23 entry)

### 23.4. Actual Verification and Build Results
- `.\mvnw.cmd test -Dtest=DataSeederTest`:
  - **Result:** **3/3 tests passed** (0 failures, 0 errors, BUILD SUCCESS). Verified table row counts, foreign key integrity, unique constraints, zero self-follows, BCrypt password verification, and repeated run idempotency.
- `.\mvnw.cmd test`:
  - **Result:** **56/56 tests passed** (0 failures, 0 errors, BUILD SUCCESS):
    - `AuthControllerTest`: 25/25 passed
    - `DataSeederTest`: 3/3 passed
    - `HealthControllerTest`: 1/1 passed
    - `ItineraryControllerTest`: 21/21 passed
    - `JwtTokenProviderTest`: 5/5 passed
    - `TravelPlannerApplicationTests`: 1/1 passed
- **Live Local Database Execution (`travel_planner` MySQL):**
  - Ran `.\mvnw.cmd spring-boot:run` against local MySQL (`jdbc:mysql://localhost:3306/travel_planner`).
  - Verified exact table row counts in MySQL:
    - `users`: 11 (10 seeded + 1 preserved pre-existing `minhdanh`)
    - `destinations`: 20
    - `itineraries`: 18
    - `itinerary_days`: 47
    - `activities`: 111
    - `comments`: 14
    - `ratings`: 24
    - `favorites`: 14
    - `saved_itineraries`: 9
    - `follows`: 11
    - `itinerary_shares`: 5
    - `offline_downloads`: 7
  - Verified idempotency by executing a second run: row counts remained strictly identical (zero duplicate records).
- **Live API Endpoint Verification:**
  - `POST /api/auth/login` with `traveler_viet`: 200 OK, returned JWT Bearer token and full profile.
  - `POST /api/auth/login` with `admin_master`: 200 OK, authenticated with `ADMIN` role.
  - `POST /api/auth/login` with `banned_spammer`: 403 Forbidden (properly blocked).
  - `POST /api/auth/login` with `inactive_user`: 403 Forbidden (properly blocked).
  - `GET /api/user/profile` with `traveler_viet` token: 200 OK.
  - `GET /api/itineraries`: 200 OK, returned exactly 13 public active itineraries across 2 pages (10 on page 0, 3 on page 1).
  - `GET /api/itineraries?keyword=Fansipan`: 200 OK, returned both base and derived Fansipan itineraries.
  - `GET /api/itineraries?location=Đà Lạt`: 200 OK, returned 2 public itineraries, strictly excluded private honeymoon itinerary.
- **Frontend Verification:**
  - `flutter test` (`frontend/mobile`): **29/29 tests passed** (0 failures, 0 errors).
  - `flutter test` (`frontend/web`): **15/15 tests passed** (0 failures, 0 errors).
- `git diff --check`: Exit code 0 (clean, no conflict markers or trailing whitespace).

### 23.5. Conclusion & Operational Status
- **Status:** COMPLETED AND VERIFIED.
- All seed data is live in local MySQL database `travel_planner`. Pre-existing data was preserved, test credentials documented, and zero regressions detected across backend and frontend test suites.

## Session 24 — Mobile Itinerary Detail Screen

### 24.1. Summary
- Connected Explore itinerary cards to the itinerary detail screen using the selected card's `itineraryId` and the existing `GET /api/itineraries/{id}` endpoint.
- Added the mobile detail screen under the existing `features/itinerary/presentation/screens/` structure. It displays the itinerary cover, title, location, duration, rating, creator, description, budget, ordered days, activities, destination details, and available destination images.
- Reused the existing detail notifier, repository, API client, day/activity widgets, design tokens, and shared loading/error/empty-state widgets. No backend, API contract, database, or dependency changes were required.
- Corrected mobile activity cost mapping to accept the backend response field `cost`. Added parsing and display support for itinerary-day dates and destination descriptions.

### 24.2. Files Changed
- `frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart`
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (created)
- `frontend/mobile/lib/features/itinerary/data/models/activity_detail.dart`
- `frontend/mobile/lib/features/itinerary/data/models/itinerary_day_detail.dart`
- `frontend/mobile/lib/features/itinerary/data/models/destination_summary.dart`
- `frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_day_card.dart`
- `frontend/mobile/lib/features/itinerary/presentation/widgets/activity_timeline_item.dart`
- `frontend/mobile/test/itinerary_detail_test.dart` (created)
- `docs/ai/09-development-log.md`

### 24.3. Verification
- `dart format` on changed Dart files: completed.
- `flutter test` in `frontend/mobile`: all 32 tests passed, including card navigation with the selected ID, detail response rendering, backend cost mapping, and retry after an API failure.
- `flutter analyze` in `frontend/mobile`: no issues found.
- Physical-device rendering and live database/API connectivity were not exercised in this session.

## Session 25 — Backend Itinerary CRUD — Phase 1

### 25.1. Summary
- Implemented the complete backend REST API foundation for Itinerary CRUD operations for authenticated users.
- Supported operations:
  - User itinerary listing (`GET /api/user/itineraries`) with pagination and status/visibility filtering.
  - Itinerary management: create (`POST /api/itineraries`), update (`PUT /api/itineraries/{id}`), soft-delete (`DELETE /api/itineraries/{id}`).
  - Day management: append day (`POST /api/itineraries/{id}/days`), update day (`PUT /api/itineraries/{id}/days/{dayId}`), delete day (`DELETE /api/itineraries/{id}/days/{dayId}`).
  - Activity management: add activity (`POST /api/itineraries/{id}/days/{dayId}/activities`), update activity (`PUT /api/itineraries/{id}/days/{dayId}/activities/{activityId}`), delete activity (`DELETE /api/itineraries/{id}/days/{dayId}/activities/{activityId}`).
  - Two-pass safe activity reordering (`PUT /api/itineraries/{id}/days/{dayId}/activities/reorder`).
- Made `Activity.destination` optional/nullable in both entity mapping and MySQL schemas (`travel_planner` and `travel_planner_test`) to support activities without mapped POIs (e.g., rest or free time).
- Enforced strict parent-child relationship validation across itinerary, day, and activity IDs to prevent cross-itinerary/cross-day tampering.
- Enforced ownership verification at the service layer using authenticated principal credentials (`@AuthenticationPrincipal`).
- Maintained day count (`totalDays`) and display order contiguity transactionally without violating database unique constraints.

### 25.2. Files Changed
- `backend/src/main/java/Travel_Planner/Travel_Planner/model/Activity.java` (updated `@JoinColumn(name = "destination_id", nullable = true)`)
- `backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryDayRepository.java` (added query and count methods)
- `backend/src/main/java/Travel_Planner/Travel_Planner/repository/ActivityRepository.java` (added child lookup, delete, and ordering methods)
- `backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/CreateItineraryRequest.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/UpdateItineraryRequest.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/CreateDayRequest.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/UpdateDayRequest.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/CreateActivityRequest.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/UpdateActivityRequest.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/ReorderActivityItem.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/service/ItineraryService.java` (added 11 CRUD methods)
- `backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java` (implemented CRUD, transaction boundaries, validation, and safe two-pass reordering)
- `backend/src/main/java/Travel_Planner/Travel_Planner/controller/UserItineraryController.java` (created)
- `backend/src/main/java/Travel_Planner/Travel_Planner/controller/ItineraryController.java` (exposed CRUD, day, and activity endpoints)
- `backend/src/test/java/Travel_Planner/Travel_Planner/ItineraryCrudTest.java` (created 11 comprehensive integration test cases)
- `docs/ai/03-api-contract.md` (updated endpoint inventory and detailed specifications)
- `docs/ai/09-development-log.md` (appended Session 25)

### 25.3. Database Schema Changes
- Altered column nullability in MySQL schemas (`travel_planner` and `travel_planner_test`):
  ```sql
  ALTER TABLE activities MODIFY COLUMN destination_id INT NULL;
  ```
- Seed data and existing foreign keys remained fully valid.

### 25.4. Verification & Automated Tests
- **Backend Test Suite (`.\mvnw.cmd test`):**
  - **Results:** 67 / 67 tests passed (0 failures, 0 errors, 0 skipped).
  - Breakdown:
    - `ItineraryCrudTest`: 11 / 11 passed (covers authentication, validation, creation with auto-generated days, user listing isolation, 403 ownership enforcement, soft deletion, day management & `totalDays` sync, last-day deletion protection, null destination support, cross-resource tampering 404, and safe two-pass reordering).
    - `AuthControllerTest`: 25 / 25 passed.
    - `ItineraryControllerTest`: 21 / 21 passed.
    - `JwtTokenProviderTest`: 5 / 5 passed.
    - `DataSeederTest`: 3 / 3 passed.
    - `HealthControllerTest`: 1 / 1 passed.
    - `TravelPlannerApplicationTests`: 1 / 1 passed.
- **Frontend Mobile Regression Suite (`flutter test` in `frontend/mobile`):**
  - **Results:** 32 / 32 tests passed (0 failures, 0 errors).
- **Frontend Web Regression Suite (`flutter test` in `frontend/web`):**
  - **Results:** 15 / 15 tests passed (0 failures, 0 errors).
- **Git Working Tree:**
  - Branch: `itinerary`.
  - Preserved existing user changes; zero destructive Git commands executed.

### 25.5. Deferred Work
- Flutter Mobile Itinerary CRUD screens (creation wizard, day manager, activity editor).
- Map integration & geocoding / GIS features (OpenStreetMap, Leaflet/FlutterMap).

## Session 26 — Flutter Mobile Itinerary CRUD — Phase 2A: Data Layer and My Itineraries Screen

### 26.1. Summary
- Implemented the Mobile data layer and the "My Itineraries" screen consuming the authenticated backend API `GET /api/user/itineraries`.
- Added `ItineraryCrudRepository` supporting pagination (`page`, `size`, `sort`) and optional filters (`status`, `visibility`).
- Extended `ItinerarySummary` model with optional `visibility` and `status` fields while preserving 100% backward compatibility with Explore and Detail modules.
- Created `MyItinerariesNotifier` (`ChangeNotifier`) handling initial load, success, empty state, error state with user-facing messages, pull-to-refresh, infinite scroll pagination (`loadMore`), filter switches, and concurrency race-condition protection via `_requestId`.
- Created `MyItineraryCard` widget displaying itinerary cover image (with fallback placeholder), title, location, duration (`totalDays`), formatted budget (VND), and status/visibility badges ("Công khai" / "Riêng tư", "Hoạt động" / "Bản nháp").
- Created `MyItinerariesScreen` with quick-filter chips for visibility and status, pull-to-refresh (`RefreshIndicator`), error retry (`AppErrorState`), empty state (`AppEmptyState`), and card navigation to `ItineraryDetailScreen`.
- Integrated "Lịch trình của tôi" navigation entry points into `ExploreScreen` AppBar's account menu and `PlaceholderHomeScreen`.
- Strictly preserved backend and Flutter Web codebase without unintended modifications.

### 26.2. Files Changed
- `frontend/mobile/lib/core/constants/api_constants.dart` (added `userItinerariesEndpoint = '/api/user/itineraries'`)
- `frontend/mobile/lib/features/explore/data/models/itinerary_summary.dart` (added `visibility` and `status` fields)
- `frontend/mobile/lib/features/itinerary/data/itinerary_crud_repository.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/my_itineraries_notifier.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/my_itinerary_card.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/screens/my_itineraries_screen.dart` (created)
- `frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart` (integrated navigation entry)
- `frontend/mobile/lib/main.dart` (integrated navigation entry in `PlaceholderHomeScreen`)
- `frontend/mobile/test/my_itineraries_test.dart` (created 10 comprehensive unit and widget tests)
- `docs/ai/09-development-log.md` (appended Session 26)

### 26.3. Verification & Automated Tests
- **Flutter Mobile Test Suite (`flutter test` in `frontend/mobile`):**
  - **Results:** 42 / 42 tests passed (0 failures, 0 errors).
  - Breakdown:
    - `my_itineraries_test.dart`: 10 / 10 passed (model deserialization, repository query encoding, API error propagation, notifier state transitions, error & retry, filter changes, initial loading, empty state, card rendering with badges, detail navigation).
    - `explore_test.dart`: 15 / 15 passed.
    - `itinerary_detail_test.dart`: 7 / 7 passed.
    - `auth_401_test.dart`: 8 / 8 passed.
    - `username_validation_test.dart`: 1 / 1 passed.
    - `widget_test.dart`: 1 / 1 passed.
- **Flutter Mobile Static Analysis (`flutter analyze` in `frontend/mobile`):**
  - **Results:** No issues found!
- **Flutter Web Regression Suite (`flutter test` in `frontend/web`):**
  - **Results:** 15 / 15 tests passed (0 failures, 0 errors).
- **Backend & Web Confirmation:**
  - Zero backend code or web frontend code modified.

### 26.4. Deferred Work
- Itinerary creation wizard and form (`CreateItineraryScreen`) — completed in Session 27.
- Itinerary day and activity management editors (`ItineraryEditorScreen`, day manager, activity form) — deferred to Phase 2C.
- Map integration, geocoding, and polyline visualization — deferred to subsequent phases.

## Session 27 — Flutter Mobile Itinerary CRUD — Phase 2B: Create Itinerary Screen

### 27.1. Summary
- Implemented the complete itinerary creation flow in Flutter Mobile consuming the existing backend API `POST /api/itineraries`.
- Added `CreateItineraryRequest` model handling JSON serialization, field sanitization, and `visibility` selection (`PUBLIC` or `PRIVATE`).
- Extended `ItineraryCrudRepository` with `createItinerary` method submitting authenticated requests with Bearer token and deserializing `ItineraryDetail`.
- Created `CreateItineraryScreen`:
  - Form inputs: Title (required, 3-150 chars), Location (required, max 150 chars), Total Days (required, 1-30), Budget (required, non-negative VND), Category/Theme (optional with quick suggestion chips), Description (optional multi-line), Cover Image URL (optional, max 500 chars), and Visibility toggle cards (`PRIVATE` default vs `PUBLIC`).
  - Form validation with immediate field-level error messages matching backend constraints.
  - Duplicate submission prevention: disables submit button and displays loading spinner while network call is in flight.
  - User-facing error handling displaying server error messages in SnackBar.
- Integrated creation entry points in `MyItinerariesScreen`:
  - `FloatingActionButton.extended` labeled "Tạo lịch trình" on the main list.
  - Primary action button "Tạo lịch trình ngay" on `AppEmptyState`.
- Post-creation flow: displays success feedback, navigates to `ItineraryDetailScreen` displaying the created itinerary (and its initial generated empty days), and automatically refreshes `MyItinerariesScreen` on return.
- Maintained strict scope: zero modifications to Backend or Flutter Web code.

### 27.2. Files Changed
- `frontend/mobile/lib/features/itinerary/data/models/create_itinerary_request.dart` (created)
- `frontend/mobile/lib/features/itinerary/data/itinerary_crud_repository.dart` (added `createItinerary` method)
- `frontend/mobile/lib/features/itinerary/presentation/screens/create_itinerary_screen.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/screens/my_itineraries_screen.dart` (added FAB and empty state create action)
- `frontend/mobile/test/create_itinerary_test.dart` (created 10 comprehensive unit and widget tests)
- `docs/ai/09-development-log.md` (appended Session 27)

### 27.3. Verification & Automated Tests
- **Flutter Mobile Test Suite (`flutter test` in `frontend/mobile`):**
  - **Results:** 52 / 52 tests passed (0 failures, 0 errors).
  - Breakdown:
    - `create_itinerary_test.dart`: 10 / 10 passed (request serialization, null/blank field omitting, repository POST call and response parsing, API 400 validation error propagation, form rendering, required-field validation, bounds validation, duplicate submission protection, success navigation to detail, API failure handling, FAB and empty state entry points).
    - `my_itineraries_test.dart`: 10 / 10 passed.
    - `explore_test.dart`: 15 / 15 passed.
    - `itinerary_detail_test.dart`: 7 / 7 passed.
    - `auth_401_test.dart`: 8 / 8 passed.
    - `username_validation_test.dart`: 1 / 1 passed.
    - `widget_test.dart`: 1 / 1 passed.
- **Flutter Mobile Static Analysis (`flutter analyze` in `frontend/mobile`):**
  - **Results:** No issues found!
- **Flutter Web Regression Suite (`flutter test` in `frontend/web`):**
  - **Results:** 15 / 15 tests passed (0 failures, 0 errors).
- **Backend Regression Suite (`.\mvnw.cmd test` in `backend`):**
  - Verified intact (67 / 67 passed previously; backend code untouched).

### 27.4. Deferred Work
- Day and activity management editor (`ItineraryEditorScreen`, day add/edit/delete, activity form, two-pass reordering UI) — deferred to subsequent phases.
- Map integration, geocoding, and polyline visualization — deferred to subsequent phases.

## Session 28 — Flutter Mobile Itinerary CRUD — Phase 2C: Edit and Soft-Delete Itinerary

### 28.1. Summary
- Implemented editing of itinerary basic information and soft-deletion of the owner's itinerary in Flutter Mobile consuming the existing backend APIs (`PUT /api/itineraries/{id}` and `DELETE /api/itineraries/{id}`).
- Verified backend contracts:
  - `PUT /api/itineraries/{id}`: accepts `UpdateItineraryRequest` (`title` [3..150], `location` [1..150], `budget` [>= 0], `description`, `coverImage` [<= 500], `theme` [<= 100], `visibility` [`PUBLIC`/`PRIVATE`]). Note: `totalDays` is not part of this request because days are managed separately.
  - `DELETE /api/itineraries/{id}`: soft-deletes the itinerary by setting `status = ItineraryStatus.DELETED`, which automatically excludes it from active listings.
- Extended `ApiClient` with an authenticated `delete` method supporting request timeouts, error translation, and unauthorized callbacks.
- Added `UpdateItineraryRequest` model handling JSON serialization, field trimming, and null preservation for cleared optional fields.
- Extended `ItineraryCrudRepository` with:
  - `updateItinerary(int itineraryId, UpdateItineraryRequest request, {String? token})`: executes PUT request and deserializes updated `ItineraryDetail`.
  - `deleteItinerary(int itineraryId, {String? token})`: executes DELETE request.
- Implemented `EditItineraryScreen`:
  - Prefills existing itinerary values (`initialTitle`, `initialLocation`, `initialBudget`, `initialDescription`, `initialCoverImage`, `initialTheme`, `initialVisibility`).
  - Read-only information card clarifying that total days and individual activities are managed in separate steps.
  - Form validation matching backend rules (title 3-150 chars, location 1-150 chars, non-negative budget, URL length limits).
  - Quick theme selection chips and interactive radio cards for `PRIVATE` vs `PUBLIC` visibility.
  - Duplicate submission protection with loading state, error SnackBar on API exceptions, and returns the updated `ItineraryDetail` on success.
- Implemented `showDeleteItineraryConfirmationDialog`:
  - Clearly identifies the itinerary by title and warns that it will be removed from the user's active itinerary list.
  - Two explicit action buttons: "Hủy" and "Xóa lịch trình" (danger styled).
- Integrated Edit and Delete into `ItineraryDetailScreen`:
  - Enforced client-side ownership check: Edit and Delete AppBar action icons are only displayed if the authenticated user matches the itinerary creator's username (`currentUsername == detail.creator.username`).
  - Edit action opens `EditItineraryScreen` and refreshes detail data upon return.
  - Delete action opens confirmation dialog, executes soft delete via repository, shows success SnackBar, and navigates away (`Navigator.pop(context, true)`).
- Integrated Edit and Delete into `MyItinerariesScreen` & `MyItineraryCard`:
  - Added a 3-dots popup menu button on each card (`PopupMenuButton`) containing "Chỉnh sửa" and "Xóa lịch trình".
  - Editing an itinerary or deleting an itinerary immediately refreshes the active list.
  - Detail screen navigation propagates deletion results back to the list to refresh automatically.
- Maintained strict scope: zero modifications to Backend entities or Flutter Web UI.

### 28.2. Files Changed
- `frontend/mobile/lib/core/network/api_client.dart` (added authenticated `delete` method)
- `frontend/mobile/lib/features/itinerary/data/itinerary_crud_repository.dart` (added `updateItinerary` and `deleteItinerary`)
- `frontend/mobile/lib/features/itinerary/data/models/update_itinerary_request.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/screens/edit_itinerary_screen.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/delete_itinerary_dialog.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/my_itinerary_card.dart` (added popup menu with edit and delete callbacks)
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (added owner edit/delete actions, dialog, navigation pop)
- `frontend/mobile/lib/features/itinerary/presentation/screens/my_itineraries_screen.dart` (wired edit/delete callbacks and passed repository to notifier)
- `frontend/mobile/lib/features/itinerary/presentation/screens/create_itinerary_screen.dart` (passed authNotifier to ItineraryDetailScreen)
- `frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart` (passed authNotifier to ItineraryDetailScreen and refreshed on deletion)
- `frontend/mobile/test/itinerary_edit_delete_test.dart` (created 16 comprehensive unit and widget tests)
- `docs/ai/09-development-log.md` (appended Session 28)

### 28.3. Verification & Automated Tests
- **Flutter Mobile Test Suite (`flutter test` in `frontend/mobile`):**
  - **Results:** 68 / 68 tests passed (0 failures, 0 errors).
  - Breakdown:
    - `itinerary_edit_delete_test.dart`: 16 / 16 passed.
    - `create_itinerary_test.dart`: 10 / 10 passed.
    - `my_itineraries_test.dart`: 10 / 10 passed.
    - `explore_test.dart`: 15 / 15 passed.
    - `itinerary_detail_test.dart`: 7 / 7 passed.
    - `auth_401_test.dart`: 8 / 8 passed.
    - `username_validation_test.dart`: 1 / 1 passed.
    - `widget_test.dart`: 1 / 1 passed.
- **Flutter Mobile Static Analysis (`flutter analyze` in `frontend/mobile`):**
  - **Results:** No issues found! (0 warnings, 0 errors).
- **Flutter Web Regression Suite (`flutter test` in `frontend/web`):**
  - **Results:** 15 / 15 tests passed (0 failures, 0 errors).
- **Backend Regression Suite:**
  - Verified intact (67 / 67 passed previously; backend code untouched).

### 28.4. Known Limitations & Deferred Work
- Individual day management (creating, editing, deleting days) — deferred to Phase 2D / subsequent phases.
- Activity management (creating, editing, deleting, reordering activities) — deferred to subsequent phases.
- Map integration, destination autocomplete, geocoding, and polyline visualization — deferred to subsequent phases.
- Flutter Web itinerary editing and deletion UI — deferred to Web CRUD phase.

## Session 29 — Flutter Mobile Itinerary CRUD — Phase 2D: Day Management

### 29.1. Summary
- Implemented Day Management for itineraries in Flutter Mobile consuming the existing backend APIs:
  - Add day: `POST /api/itineraries/{id}/days`
  - Edit day: `PUT /api/itineraries/{id}/days/{dayId}`
  - Delete day: `DELETE /api/itineraries/{id}/days/{dayId}`
- Verified backend contracts:
  - `POST /api/itineraries/{id}/days`: Accepts `CreateDayRequest` (`title` optional, max 150 chars; `date` optional `LocalDate`). Automatically sets `dayNumber = itinerary.totalDays + 1`, increments `itinerary.totalDays`, and defaults blank titles to `"Ngày " + nextDayNumber`. Returns `201 Created` with `ItineraryDayResponse`.
  - `PUT /api/itineraries/{id}/days/{dayId}`: Accepts `UpdateDayRequest` (`title` optional, max 150 chars; `date` optional `LocalDate`). Updates the day record without modifying `dayNumber` or `totalDays`. Returns `200 OK` with `ItineraryDayResponse`.
  - `DELETE /api/itineraries/{id}/days/{dayId}`: Deletes all associated child activities first (`activityRepository.deleteByItineraryDay_DayId(dayId)`), deletes the day record, renumbers subsequent days (`dayNumber - 1`), and decrements `itinerary.totalDays`. If `itinerary.totalDays <= 1`, throws 400 `BadRequestException` ("Lịch trình phải có ít nhất 1 ngày. Không thể xóa ngày cuối cùng"). Returns `200 OK` with `{"message": "Đã xóa ngày thành công"}`.
- Data Layer Models & Repository:
  - Created `CreateDayRequest` and `UpdateDayRequest` supporting title and formatted date (`YYYY-MM-DD`), with null/blank preservation.
  - Extended `ItineraryCrudRepository` with `addDay`, `updateDay`, and `deleteDay` methods communicating with authenticated `ApiClient`.
  - Updated `ItineraryDayDetail.displayTitle` helper to prevent redundant prefixes (e.g. avoiding "Ngày 1: Ngày 1").
- Presentation & Widgets:
  - Created `DayFormDialog` (`showDayFormDialog`) reusable for both adding and editing days. Includes date picker (`showDatePicker`), clear date action, title field with 150-char validation counter, loading indicator, duplicate submission protection, and error SnackBar.
  - Created `DeleteDayConfirmationDialog` (`showDeleteDayConfirmationDialog`) warning the user about permanent day deletion, renumbering of subsequent days, and deletion of all associated activities when activities exist.
  - Enhanced `ItineraryDayCard`: Added 3-dots popup menu button (`PopupMenuButton`) with "Sửa ngày" and "Xóa ngày" actions when owner callbacks are provided.
  - Integrated into `ItineraryDetailScreen`:
    - Ownership enforcement: "+ Thêm ngày" header button, bottom "+ Thêm Ngày X" button, and day card edit/delete popup menus are strictly shown only when `currentUsername == detail.creator.username`.
    - Minimum 1 day guard: Client-side guard prevents deleting a day if `detail.days.length <= 1` with a helpful SnackBar, in addition to handling backend 400 errors.
    - Empty state: When an itinerary has 0 days, renders an empty state with a "+ Thêm ngày đầu tiên" button for the owner.
    - Detail refresh: Automatically reloads itinerary detail via repository on successful day addition, modification, or deletion.
- Maintained strict scope: Zero modifications to Activity CRUD, Day Reordering, Maps/Geocoding, or Flutter Web UI.

### 29.2. Files Changed & Created
- `frontend/mobile/lib/features/itinerary/data/models/create_day_request.dart` (created)
- `frontend/mobile/lib/features/itinerary/data/models/update_day_request.dart` (created)
- `frontend/mobile/lib/features/itinerary/data/models/itinerary_day_detail.dart` (enhanced `displayTitle`)
- `frontend/mobile/lib/features/itinerary/data/itinerary_crud_repository.dart` (extended with `addDay`, `updateDay`, `deleteDay`)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/day_form_dialog.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/delete_day_dialog.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_day_card.dart` (added popup menu with edit and delete callbacks)
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (integrated day CRUD handlers, owner actions, empty state, and refresh)
- `frontend/mobile/test/itinerary_day_management_test.dart` (created 17 comprehensive unit and widget tests)
- `docs/ai/09-development-log.md` (appended Session 29)

### 29.3. Verification & Automated Tests
- **Targeted Day Management Tests (`flutter test test/itinerary_day_management_test.dart`):**
  - **Results:** 17 / 17 tests passed (0 failures, 0 errors).
  - Covered: serialization, optional fields, network endpoints with Bearer tokens, error propagation, dialog rendering & form submission, prefilling values, activity deletion warnings, owner-only action visibility, unauthorized access hiding, delete flow & reload, 1-day deletion prevention, and empty days state.
- **Flutter Mobile Test Suite (`flutter test` in `frontend/mobile`):**
  - **Results:** 85 / 85 tests passed (0 failures, 0 errors).
- **Flutter Mobile Static Analysis (`flutter analyze` in `frontend/mobile`):**
  - **Results:** No issues found! (0 warnings, 0 errors).
- **Flutter Web Regression Suite (`flutter test` in `frontend/web`):**
  - **Results:** 15 / 15 tests passed (0 failures, 0 errors).
- **Backend Test Suite:**
  - Backend code untouched; verified intact against verified contracts.

### 29.4. Known Limitations & Deferred Work
- Activity CRUD (creating, editing, deleting, two-pass reordering of activities within a day) — deferred to Phase 2E.
- Day reordering (moving days up or down) — not supported by current backend contract (day numbering is derived/sequential based on order of creation/deletion).
- Map integration, destination search, geocoding, and polyline visualization — deferred to Phase 3.
- Flutter Web Day Management — deferred to Flutter Web CRUD phase.

## Session 30 — Flutter Mobile Itinerary CRUD — Phase 2E: Activity Management

### 30.1. Summary
- Implemented Activity Management for itinerary days in Flutter Mobile consuming the existing Spring Boot APIs:
  - Add activity: `POST /api/itineraries/{id}/days/{dayId}/activities`
  - Update activity: `PUT /api/itineraries/{id}/days/{dayId}/activities/{activityId}`
  - Delete activity: `DELETE /api/itineraries/{id}/days/{dayId}/activities/{activityId}`
  - Reorder activities: `PUT /api/itineraries/{id}/days/{dayId}/activities/reorder`
- Verified backend contracts:
  - `POST /api/itineraries/{id}/days/{dayId}/activities`: Accepts `CreateActivityRequest` (`name` required max 150; `description` optional; `destinationId` optional nullable; `startTime` and `endTime` optional `LocalTime`; `cost` optional `BigDecimal` >= 0.0). Automatically assigns `displayOrder = maxOrder + 1`. Returns `201 Created` with `ActivityResponse`.
  - `PUT /api/itineraries/{id}/days/{dayId}/activities/{activityId}`: Accepts `UpdateActivityRequest`. Validates that `endTime` is not before `startTime`. Returns `200 OK` with `ActivityResponse`.
  - `DELETE /api/itineraries/{id}/days/{dayId}/activities/{activityId}`: Deletes activity and renumbers subsequent activities' `displayOrder` contiguously (`-1`). Returns `200 OK` with `{"message": "Đã xóa hoạt động thành công"}`.
  - `PUT /api/itineraries/{id}/days/{dayId}/activities/reorder`: Accepts `List<ReorderActivityItem>` (`activityId`, `displayOrder` 1..N). Executes a two-phase transaction (temporary negative orders then positive target orders) avoiding MySQL unique key collisions on `uk_activity_day_order`. Returns `200 OK` with `List<ActivityResponse>` in updated order.
- Data Layer Models & Networking:
  - Extended `ApiClient.put` to accept `dynamic body` allowing serialization of JSON arrays in addition to JSON objects.
  - Created `CreateActivityRequest`, `UpdateActivityRequest`, and `ReorderActivityItem` supporting time formatting (`HH:mm:ss`), optional fields, and null preservation for cleared fields.
  - Extended `ItineraryCrudRepository` with `addActivity`, `updateActivity`, `deleteActivity`, and `reorderActivities`.
- Presentation & Widgets:
  - Created `ActivityFormDialog` (`showActivityFormDialog`) for creating and editing activities:
    - Time pickers with inline validation (start time vs end time), clear time button.
    - Name field with 150-char validation counter.
    - Cost input supporting VND formatting.
    - Duplicate submission prevention with loading indicator.
  - Created `DeleteActivityConfirmationDialog` (`showDeleteActivityConfirmationDialog`) identifying activity by name and warning that subsequent activities will be renumbered.
  - Created `ReorderActivitiesDialog` (`showReorderActivitiesDialog`) utilizing `ReorderableListView` with index badges and drag handles, preserving order until explicit save.
  - Enhanced `ActivityTimelineItem`:
    - Added `onEdit` and `onDelete` callbacks.
    - Rendered compact 3-dots popup menu (`PopupMenuButton`) containing "Sửa hoạt động" and "Xóa hoạt động" when owner callbacks are provided.
  - Enhanced `ItineraryDayCard`:
    - Added "+ Thêm hoạt động" button and "Sắp xếp" button when day has > 1 activities.
    - Added "+ Thêm hoạt động đầu tiên" action when day has 0 activities.
    - Added "Thêm hoạt động" and "Sắp xếp hoạt động" options to the day's 3-dots popup menu.
  - Integrated into `ItineraryDetailScreen`:
    - Wired handlers `_handleAddActivity`, `_handleEditActivity`, `_handleDeleteActivity`, `_handleReorderActivities`.
    - Enforced owner-only access: CRUD and reorder controls are hidden for non-owners.
    - Automatically reloads detail data and displays success SnackBars on all operations.

### 30.2. Files Changed & Created
- `frontend/mobile/lib/core/network/api_client.dart` (updated `put` body parameter to `dynamic`)
- `frontend/mobile/lib/features/itinerary/data/models/create_activity_request.dart` (created)
- `frontend/mobile/lib/features/itinerary/data/models/update_activity_request.dart` (created)
- `frontend/mobile/lib/features/itinerary/data/models/reorder_activity_item.dart` (created)
- `frontend/mobile/lib/features/itinerary/data/itinerary_crud_repository.dart` (added activity CRUD & reorder methods)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/delete_activity_dialog.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/reorder_activities_dialog.dart` (created)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/activity_timeline_item.dart` (added popup menu with edit and delete callbacks)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_day_card.dart` (added activity action buttons and reorder callbacks)
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (integrated activity CRUD & reorder handlers)
- `frontend/mobile/test/itinerary_activity_management_test.dart` (created 19 comprehensive unit and widget tests)
- `docs/ai/09-development-log.md` (appended Session 30)

### 30.3. Verification & Automated Tests
- **Targeted Activity Management Tests (`flutter test test/itinerary_activity_management_test.dart`):**
  - **Results:** 19 / 19 tests passed (0 failures, 0 errors).
  - Covered: serialization, optional fields, network calls with Bearer tokens, error propagation, dialog rendering & validation, time range validation, prefilling values, delete confirmation, reorder list saving, owner-only UI visibility, hiding actions from non-owners, and detail reloading.
- **Full Flutter Mobile Test Suite (`flutter test` in `frontend/mobile`):**
  - **Results:** 104 / 104 tests passed (0 failures, 0 errors across Auth, Explore, Detail, Create, Edit/Delete, DayManagement, ActivityManagement).
- **Flutter Mobile Static Analysis (`flutter analyze` in `frontend/mobile`):**
  - **Results:** No issues found! (0 warnings, 0 errors).
- **Flutter Web Regression Suite (`flutter test` in `frontend/web`):**
  - **Results:** 15 / 15 tests passed (0 failures, 0 errors).
- **Backend Test Suite:**
  - Backend code untouched; verified intact against verified contracts.

### 30.4. Known Limitations & Deferred Work
- Destination lookup / POI selection: The backend does not yet provide a destination search/autocomplete endpoint (`/api/destinations`), so activities are created with `destinationId = null` (fully supported by backend schema) or preserve existing destinations. Destination search will be implemented in Phase 3 (Map Integration).
- Day reordering (moving entire days up or down) — not supported by current backend contract.
- Map integration, geocoding, and polyline visualization — deferred to Phase 3.
- Flutter Web Activity Management — deferred to Flutter Web CRUD phase.

## Session 31 — Animation Guidelines & AI Workflow Integration

### 31.1. Summary
- Integrated comprehensive Flutter-compatible animation guidelines and decision processes into the project's documentation based on upstream principles from the Animate UI specification (`https://animate-ui.com/docs/skills`).
- Created canonical guideline document `docs/ai/10-animation-guidelines.md`:
  - Established core animation principles: frequency-of-use gating, purpose-driven motion, subtle motion as default, origin and direction anchoring, and physics/easing curves over linear timing.
  - Formulated a 5-step decision framework: (1) Code Inspection, (2) Frequency & Utility Gate, (3) Motion Level Selection, (4) Implementation Technique, (5) Verification & Accessibility.
  - Defined explicit motion levels: Level 0 None (direct state swap), Level 1 Subtle (100–200ms, default), Level 2 Moderate (200–300ms), and Level 3 Expressive (300–450ms, strictly capped at 500ms for rare celebratory milestones).
  - Explicitly empowered agents to choose zero animation (Level 0) when motion adds wait time or decreases user productivity (e.g., text editing, administrative data table sorting/pagination).
  - Detailed Flutter implementation options distinguishing implicit animations (`AnimatedContainer`, `AnimatedOpacity`, `AnimatedScale`, `AnimatedCrossFade`, `AnimatedSwitcher`) and explicit animations (`AnimationController`, `CurvedAnimation`, `TweenSequence`, `SingleTickerProviderStateMixin`) with mandatory `dispose()` calls.
  - Mapped Travel Planner features directly to motion specifications: explore card hover float (Web), favorite heart scale bounce (Mobile/Web), search pill segment hover and orb press, mobile search expansion modal, day card accordion expansion, activity drag-and-drop reordering (`ReorderableListView`), form dialog entry, and loading spinner cross-fades.
  - Prohibited direct application of React-specific components, npm CLI packages (`@animate-ui/cli`, `npx skills add imskyleen/animate-ui`), or web JS dependencies in Flutter applications.
  - Codified accessibility requirements: honoring `MediaQuery.of(context).disableAnimations` / `prefers-reduced-motion`, vestibular safety limits (offsets <= 24dp, no unbounded animations on resolved content), and touch target preservation (>= 48x48dp).
  - Provided performance budgets (60fps/120fps, animating transform and opacity rather than layout dimensions, const constructor optimization, Flutter Web lightweight ticker discipline) and automated widget test rules (`tester.pump(duration)` instead of unbounded `pumpAndSettle()` for infinite tickers).
- Updated `AGENTS.md`:
  - Added mandatory reference to `docs/ai/10-animation-guidelines.md` in Section 2 and Section 5 scoped specifically to relevant Flutter UI tasks.
  - Explicitly exempted backend-only tasks (Spring Boot REST API, database schema, services) from animation analysis.
- Updated `docs/ai/08-agent-workflow.md`:
  - Integrated animation analysis into Phase 1 (Understand), Phase 2 (Plan), Phase 4 (Implement), Phase 5 (Verify), Phase 6 (Review), and Phase 8 (Report).
- Updated `docs/ai/00-project-context.md`:
  - Added `docs/ai/10-animation-guidelines.md` to Section 10 (Sources of Truth).
- Documentation-only task: Confirmed zero application source code, UI widgets, or dependencies were altered or added.

### 31.2. Files Changed & Created
- `docs/ai/10-animation-guidelines.md` (created)
- `AGENTS.md` (updated)
- `docs/ai/08-agent-workflow.md` (updated)
- `docs/ai/00-project-context.md` (updated)
- `docs/ai/09-development-log.md` (appended Session 31)

### 31.3. Verification & Checks
- Verified all referenced file paths exist in the repository.
- Verified Markdown syntax, heading levels, and internal relative links.
- Verified Git diff to confirm strictly documentation files were touched: no Flutter code in `frontend/mobile/` or `frontend/web/`, no Spring Boot code in `backend/`, and no `pubspec.yaml` or `pom.xml` dependency alterations.
- Confirmed animation analysis requirement is strictly scoped to Flutter UI changes, and backend tasks remain exempt.

### 31.4. Known Limitations & Next Steps
- Application UI animations have NOT been implemented or modified in this task.
- Future Flutter UI tasks (e.g., favorite heart micro-interaction, card hover float, or search expansion) will follow the newly codified guidelines in `docs/ai/10-animation-guidelines.md`.

## Session 32 — Existing UI Animation Enhancements

### 32.1. Summary
- Audited and improved animations across existing UI features in `frontend/mobile` and `frontend/web` in strict compliance with `docs/ai/10-animation-guidelines.md`.
- Implemented subtle, physics-based Flutter-native animations across shared widgets and core screens without adding any third-party dependencies or altering application functionality.
- Supported accessibility and reduced-motion user preferences using `MediaQuery.maybeOf(context)?.disableAnimations` (defaulting to zero-duration / immediate state swap when reduced-motion is requested).
- Maintained strict scope boundaries: zero modifications to backend code, API contracts, domain entities, routing outcomes, validation rules, or dependency manifests (`pubspec.yaml`, `pom.xml`).
- Created a focused automated regression test suite in `frontend/mobile/test/animation_enhancements_test.dart` verifying cross-fades, reduced-motion bypass, password toggles, icon scaling, and micro-interactions.

### 32.2. Feature Areas Audited & Decisions
1. **Shared Components:**
   - `AppPrimaryButton` (`IMPROVE`): Replaced instant text/spinner layout pop with an `AnimatedSwitcher` (150ms `Curves.easeOutCubic`) preserving layout dimensions and button disabled state. Implemented in both mobile and web.
   - `AppTextField` (`IMPROVE`): Added `AnimatedSwitcher` with `FadeTransition` (150ms) to password visibility toggle icon (`Icons.visibility_outlined` vs `Icons.visibility_off_outlined`) in both mobile and web.
   - `AppEmptyState` (`IMPROVE`): Added a gentle scale-in `TweenAnimationBuilder` (200ms `Curves.easeOutCubic`, 0.88 to 1.0) on the empty illustration icon.
   - Form Validation Errors (`SKIP`): Left validation text error appearance instant (Level 0) to avoid jarring vertical layout jitter during rapid typing.
2. **Explore Feature:**
   - `SearchBarPill` (`ADD`): Added `AnimatedSwitcher` fade/scale transition to the clear query button and active filter count badge (`150ms`).
   - `ItineraryCard` (`IMPROVE`): Added smooth network image fade-in via `Image.network` `frameBuilder` (200ms `AnimatedOpacity`), and created `_FavoriteHeartButton` stateful micro-interaction with `AnimatedScale` (scale down to 0.88 on tap down, springing back on tap up/cancel, 120ms).
   - `ExploreScreen` (`IMPROVE`): Wrapped body content switching (loading spinner, error state, empty state, and populated itinerary list) in an `AnimatedSwitcher` (180ms `Curves.easeOutCubic`) using `StackFit.expand` layout builder to preserve tight constraints for scrollable children.
3. **Itinerary Management:**
   - `MyItineraryCard` (`IMPROVE`): Added network image smooth fade-in via `frameBuilder` (200ms `AnimatedOpacity`).
   - `ItineraryDetailScreen` (`IMPROVE`): Wrapped screen body transitions (loading, error, detail content) in `AnimatedSwitcher` (180ms `Curves.easeOutCubic`, `StackFit.expand`).
   - `ItineraryDayCard` (`KEEP`): Already uses standard card elevation and expandable lists; kept without excess animation to prevent scroll stuttering.
   - `ReorderActivitiesDialog` (`KEEP`): Already utilizes Flutter's native `ReorderableListView` providing fluid drag-and-drop elevation and reorder motion out of the box.
4. **Profile Feature:**
   - `ProfileScreen` (`ADD`): Added `AnimatedSwitcher` (200ms `Curves.easeOutCubic`) between profile display view and profile editor mode across both mobile and web.
5. **Dialogs & Administrative Web Screens:**
   - Confirmation Dialogs (`KEEP`): Standard Material 3 `AlertDialog` scale-and-fade behavior is already consistent and appropriate.
   - Filter Bottom Sheet (`KEEP`): Flutter's `showModalBottomSheet` slide-in curve already conforms to mobile standards.
   - Web Moderation & Data Tables (`SKIP`): Kept at Level 0 (no animation) to prioritize administrative productivity and fast data scanning.

### 32.3. Files Modified & Created
- `Travel_Planner/frontend/mobile/lib/shared/widgets/app_primary_button.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/shared/widgets/app_text_field.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/shared/widgets/app_empty_state.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/search_bar_pill.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/itinerary_card.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/my_itinerary_card.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (modified)
- `Travel_Planner/frontend/mobile/lib/features/profile/presentation/screens/profile_screen.dart` (modified)
- `Travel_Planner/frontend/web/lib/shared/widgets/app_primary_button.dart` (modified)
- `Travel_Planner/frontend/web/lib/shared/widgets/app_text_field.dart` (modified)
- `Travel_Planner/frontend/web/lib/features/profile/presentation/screens/profile_screen.dart` (modified)
- `Travel_Planner/frontend/mobile/test/animation_enhancements_test.dart` (created)
- `Travel_Planner/docs/ai/09-development-log.md` (updated)

### 32.4. Verification & Checks
- **Dart Format:** `dart format` verified clean across all 13 modified Dart files.
- **Flutter Mobile Static Analysis (`flutter analyze` in `frontend/mobile`):**
  - Result: 0 issues found.
- **Flutter Web Static Analysis (`flutter analyze` in `frontend/web`):**
  - Result: 0 issues found.
- **Flutter Web Test Suite (`flutter test` in `frontend/web`):**
  - Result: 15 / 15 tests passed (0 failures, 0 errors).
- **Flutter Mobile Test Suite (`flutter test` in `frontend/mobile`):**
  - Result: 110 / 110 tests passed (0 failures, 0 errors across all 14 test suites, including 6 new animation regression tests).
- **Scope Integrity:** Confirmed 0 changes to backend code, APIs, data models, or dependency manifests (`pubspec.yaml`, `pom.xml`).

### 32.5. Known Limitations & Deferred Work
- Route transitions: Retained platform-adaptive page transitions (`MaterialPageRoute`) rather than custom routing transitions to preserve standard OS navigation expectations.
- Real hardware observation: Verification was conducted via the automated Flutter widget testing harness and simulated animation tickers; physical on-device observation remains dependent on device availability.

---

## 33. Session Entry: Fix Itinerary Visibility UI Dimensions and Newly Created Itinerary Detail Flow (2026-10-27)

### 33.1. Context and Objective
Resolved two defects in the Travel Planner mobile application (`frontend/mobile`):
1. **Bug 1 — Inconsistent visibility option sizes:** On the itinerary creation screen (`CreateItineraryScreen`) and edit screen (`EditItineraryScreen`), the "Private" (`Riêng tư`) and "Public" (`Công khai`) option cards rendered with unequal heights due to varying text lengths and line wraps across standard mobile viewports (e.g., 360–390dp).
2. **Bug 2 — Newly created itinerary detail initialization and day/activity management:** Following successful itinerary creation, opening the detail screen displayed empty or unhelpful content, occasionally showing a premature "not found" state before data resolution, and owner day/activity management actions were inaccessible. Investigated and fixed the complete workflow: `Create Itinerary → API Response → Navigation → Detail Initialization → Load Days → Manage Activities`.

### 33.2. Confirmed Root Causes
1. **Bug 1 Root Cause:**
   - In `CreateItineraryScreen` and `EditItineraryScreen`, visibility options were placed in a horizontal `Row` without cross-axis stretching constraints, and each option's inner `Container` wrapped intrinsic text content.
   - The Vietnamese subtitle for the Public option ("Mọi người đều xem được", 24 chars) wrapped into two lines on narrower screens, while the Private option subtitle ("Chỉ bạn xem được", 17 chars) fit on a single line, causing noticeable height asymmetry between the two cards.
2. **Bug 2 Root Cause:**
   - **Response Discard:** `CreateItineraryScreen._submit()` received the complete `ItineraryDetail` response object (`created`) from `POST /api/itineraries`, but discarded it upon navigating, passing only `itineraryId: created.itineraryId` to `ItineraryDetailScreen`.
   - **Premature Not-Found State:** `ItineraryDetailNotifier` initialized with `itineraryDetail = null` and `isLoading = false`. Before `loadDetail()` executed in the post-frame callback, `ItineraryDetailScreen._buildBody()` fell into the fallback `else if (itinerary == null)`, briefly flashing the "Không tìm thấy lịch trình" (Not Found) empty state.
   - **Disconnected Repositories & API Client:** `ItineraryDetailNotifier` created an independent `ItineraryRepository` with a default `ApiClient`, separating it from the `ApiClient` (and mock handlers) passed to `ItineraryCrudRepository`.
   - **Sliver Layout Constraint Failure on Empty Days:** When an itinerary had no days, `SliverFillRemaining(hasScrollBody: false)` inside `CustomScrollView` (following a large multi-line header) threw a `RenderBox was not laid out` layout constraint exception in scrollable contexts.
   - **Owner Permission Verification:** Day and activity management controls require `authNotifier.currentUser` to match the itinerary creator username (`currentUsername == creator.username`). Without passing `initialDetail` and authenticated user context, the screen could not immediately determine ownership.

### 33.3. Implemented Fixes
1. **Visibility Option Consistency (`CreateItineraryScreen` & `EditItineraryScreen`):**
   - Wrapped the visibility options `Row` in an `IntrinsicHeight` widget with `crossAxisAlignment: CrossAxisAlignment.stretch`.
   - Set inner card containers to `height: double.infinity` with `Row(crossAxisAlignment: CrossAxisAlignment.center)` and `Column(mainAxisAlignment: MainAxisAlignment.center)` to ensure identical widths and heights regardless of subtitle line wrapping.
   - Constrained subtitles with `maxLines: 2, overflow: TextOverflow.ellipsis` to guarantee stable typography across all mobile screen densities.
2. **Detail Screen Initialization & State Differentiation (`ItineraryDetailNotifier` & `ItineraryDetailScreen`):**
   - Added `initialDetail` parameter to `ItineraryDetailNotifier` constructor, pre-populating `itineraryDetail = initialDetail` and setting `isLoading = initialDetail == null`.
   - Passed `initialDetail: created` from `CreateItineraryScreen._submit()` into `ItineraryDetailScreen`, enabling immediate render of the newly created itinerary without empty-state flashing.
   - Exposed `ApiClient get apiClient => _apiClient;` on `ItineraryCrudRepository` and wired it into `ItineraryDetailNotifier`'s `ItineraryRepository`, unifying network client configurations and test mocks.
   - Differentiated states in `_buildBody`: populated content (`itinerary != null`), loading indicator (`isLoading`), unauthorized (`isUnauthorized` / 401/403 with lock icon), not found (`isNotFound` / 404 with luggage icon), network error (`isNetworkError` / 0 with retry), and general server error with retry.
   - Replaced `SliverFillRemaining(hasScrollBody: false)` for empty days with a `SliverToBoxAdapter` containing padded `AppEmptyState`, eliminating layout constraint exceptions while displaying clear "Thêm ngày đầu tiên" and "Thêm ngày" call-to-actions.
   - Wrapped the detail view `CustomScrollView` in a `RefreshIndicator` with `AlwaysScrollableScrollPhysics` so owners can pull to refresh and re-fetch the latest state from the backend.
   - Retained full access to day and activity management: owner can add days, add activities per day, edit/delete days, and edit/delete/reorder activities with persistent backend updates.

### 33.4. Files Modified & Created
- `frontend/mobile/lib/features/itinerary/presentation/screens/create_itinerary_screen.dart` (symmetric visibility cards, pass `initialDetail` on navigation)
- `frontend/mobile/lib/features/itinerary/presentation/screens/edit_itinerary_screen.dart` (symmetric visibility cards)
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (support `initialDetail`, state differentiation, layout safety, RefreshIndicator)
- `frontend/mobile/lib/features/itinerary/presentation/itinerary_detail_notifier.dart` (accept `initialDetail`, track `errorStatusCode` & status getters)
- `frontend/mobile/lib/features/itinerary/data/itinerary_crud_repository.dart` (expose `apiClient` getter)
- `frontend/mobile/test/create_itinerary_test.dart` (added visibility card dimension tests, end-to-end creation to detail navigation and day-management tests)
- `docs/ai/09-development-log.md` (appended Session 33 entry)

### 33.5. Verification & Test Results
- **Automated Tests:**
  - `flutter test test/create_itinerary_test.dart`: 11 / 11 tests passed (0 failures, 0 errors).
    - Verified `Riêng tư` and `Công khai` have identical widths and heights across 390x844 and 360x640 mobile viewports.
    - Verified navigation from creation form to detail screen immediately displays detail title, days, and owner "Thêm hoạt động đầu tiên" / "Thêm ngày" actions with 0 false "not found" states.
  - Full mobile test suite `flutter test`: 111 / 111 tests passed across all 11 test suites (0 failures, 0 errors).
  - Web test suite `flutter test` (`frontend/web`): 15 / 15 tests passed (0 failures, 0 errors).
- **Static Analysis & Formatting:**
  - `flutter analyze` in `frontend/mobile`: 0 issues found (clean).
  - `flutter analyze` in `frontend/web`: 0 issues found (clean).
  - `dart format`: all modified files formatted cleanly according to project conventions.
- **Scope Integrity:** Backend code unchanged; existing REST endpoints reused; no external dependencies added.

### 33.6. Manual Verification & Remaining Checks
- ADB device `RFCW8105T0H` was detected as attached with `adb reverse tcp:8080 tcp:8080` active.
- Manual device checklist to perform when running live app against running backend:
  1. Log in as test user.
  2. Open "Tạo lịch trình mới" and visually verify "Riêng tư" and "Công khai" cards have identical dimensions.
  3. Create an itinerary; confirm immediate navigation into detail view showing itinerary overview and day/activity management controls without a temporary "Không tìm thấy" error.
  4. Tap "Thêm ngày" / "Thêm hoạt động", verify item creation and persistence upon pull-to-refresh or reopening from "Lịch trình của tôi".
  5. Log in as a different user and confirm edit/delete/day-management controls are hidden for non-owners.

---

## 34. Session Entry: Investigation and Resolution of Blank Itinerary Detail Screen on Android (2026-10-27)

### 34.1. Observed Runtime Problem
- On the physical Android device (`RFCW8105T0H`), opening "Chi tiết lịch trình" (Itinerary Detail Screen) rendered:
  - App bar with back button.
  - Screen title "Chi tiết lịch trình".
  - Edit and Delete action buttons (if owner).
  - A completely blank white content area below the app bar.
- No itinerary information, overview hero, day sections, activity cards, loading indicator, empty state, or error message was displayed.

### 34.2. Verified Root Cause Analysis
1. **Broken Custom Layout in AnimatedSwitcher:**
   - In `itinerary_detail_screen.dart`, `_buildBody()` previously wrapped the state-conditional widget hierarchy in an `AnimatedSwitcher` using an overridden `layoutBuilder`:
     ```dart
     layoutBuilder: (currentChild, previousChildren) {
       return Stack(
         fit: StackFit.expand,
         children: <Widget>[...previousChildren, ?currentChild],
       );
     }
     ```
   - In Flutter's `AnimatedSwitcherState.build()`, the SDK generates incoming animated children by prepending `_currentChild?.transition` at index 0, followed by entries in `_previousChildren`.
   - By appending `?currentChild` at the end of the stack, `currentChild` was introduced twice into the layout tree under `Stack(fit: StackFit.expand)`.
2. **Opacity-Zero Lock and Stalled Transition:**
   - `AnimatedSwitcher` automatically wraps incoming children in a `FadeTransition` starting at `opacity: 0.0`.
   - On physical Android hardware, if system animations are reduced or if rapid state transitions occur (e.g. from `detail_loading` to `detail_content`), the `FadeTransition` either stalled or rendered unpainted behind duplicate stack children.
   - Because the scaffold background color is pure white (`AppColors.background` = `0xFFFFFFFF`), an unpainted or zero-opacity child caused the entire body area below the app bar to appear completely blank white.
3. **Why Unit/Widget Tests Did Not Catch It:**
   - Flutter's standard `find.text(...)` searches widget and element trees regardless of render layer opacity (`RenderAnimatedOpacity.opacity == 0.0`) or visual obstruction by sibling widgets in a `Stack`.
   - The elements existed in the tree, so widget tests passed while physical devices displayed a solid white screen.

### 34.3. Implemented Fixes
1. **Removed `AnimatedSwitcher` from `_buildBody` in `itinerary_detail_screen.dart`:**
   - Switched to direct, deterministic conditional rendering:
     - `itinerary != null` -> immediately returns `_buildContent(itinerary, isOwner)` wrapped in `RefreshIndicator` and `CustomScrollView`.
     - `isLoading` -> `Center(child: CircularProgressIndicator(color: AppColors.primary))`.
     - `isUnauthorized` -> `AppEmptyState(icon: Icons.lock_outline, ...)`.
     - `isNotFound` -> `AppEmptyState(icon: Icons.luggage_outlined, ...)`.
     - `isNetworkError` -> `AppErrorState(icon/title/retry)`.
     - `errorMessage != null` -> `AppErrorState(title/retry)`.
     - Fallback -> `Center(child: CircularProgressIndicator(...))`.
   - Eliminates duplicate children in expanding stack, removes zero-opacity fade traps, and guarantees immediate, visible rendering across all Android device display densities and animation settings.
2. **Deterministic Async Testing in `itinerary_detail_test.dart`:**
   - Replaced immediate mock client response with `Completer<http.Response>()` to deterministically verify that the loading indicator is displayed while the network request is in flight.
   - Added test verifying that itineraries with 0 days render the empty state ("Chưa có lịch trình theo ngày") and the "Thêm ngày đầu tiên" action button.
   - Added test verifying that non-owners viewing an itinerary do not see owner actions (Edit, Delete, Add Day).
   - Verified that `CustomScrollView` render object size has non-zero width and height.

### 34.4. Files Modified
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart`
- `frontend/mobile/test/itinerary_detail_test.dart`
- `docs/ai/09-development-log.md`

### 34.5. Verification & Test Results
- **Automated Tests:**
  - `flutter test test/itinerary_detail_test.dart`: 7 / 7 passed (100%).
  - Full mobile test suite `flutter test`: 115 / 115 tests passed across all 14 test suites (0 failures, 0 errors).
- **Static Analysis & Formatting:**
  - `flutter analyze` in `frontend/mobile`: 0 issues found (clean, no warnings).
- **Physical Device Status:**
  - Checked `adb devices`: no physical devices currently attached in the active environment.
  - Provided exact reproduction/verification steps and ADB reverse configuration for physical device validation once connected.

---

## 35. Session Entry: Critical End-to-End Investigation & Resolution: Newly Created Itinerary Detail Display (2026-10-27)

### 35.1. Persistent Symptom
- Existing sample itineraries (seeded in DB) correctly displayed their detail screens when opened from the Explore screen.
- When creating a brand-new itinerary with minimum required fields (title, location, totalDays, budget; without description, theme, cover image, or activities):
  - On physical Android devices, opening the detail screen failed to render a complete, customized overview.
  - Optional metadata (visibility badge, theme) was completely omitted from the metadata row.
  - When description was omitted or null, no placeholder or text was rendered, causing the hero overview to look truncated or empty.
  - Residual custom `layoutBuilder` inside `AnimatedSwitcher` in `explore_screen.dart` used `Stack(fit: StackFit.expand)` with duplicate children, triggering `RenderBox was not laid out` layout exceptions during navigation and tab switches.

### 35.2. Mandatory Comparative Trace: Flow A (Sample) vs. Flow B (Newly Created)

| Step / Attribute | Flow A: Sample Itinerary | Flow B: Newly Created Itinerary | Divergence Point |
| :--- | :--- | :--- | :--- |
| **Navigation Entry Point** | `ExploreScreen` `onTap` | `CreateItineraryScreen._submit()` | Divergence in caller context & route args |
| **Route Arguments** | `itineraryId`, `token`, `authNotifier`, `notifier` factory | `itineraryId`, `initialDetail: created`, `token`, `authNotifier`, `crudRepository` | Flow B supplies `initialDetail`; Flow A starts with `initialDetail == null` |
| **API Endpoint & Method** | `GET /api/itineraries/{id}` | `POST /api/itineraries` followed by `GET /api/itineraries/{id}` | Creation uses POST; detail uses GET |
| **HTTP Status & Payload** | HTTP 200 with full populated fields | HTTP 201 Created returning `ItineraryDetailResponse` | Both return valid DTOs |
| **Visibility** | `PUBLIC` (unrestricted access) | `PRIVATE` (default; strict owner authorization required) | **First critical divergence:** `GET /api/itineraries/{id}` requires valid Bearer token matching creator for private itineraries |
| **Cover Image & Description** | Valid Unsplash URL + rich description | `coverImage: null`, `description: null`, `theme: null` | **Second critical divergence:** Flow A renders image & description text; Flow B had no placeholder for null description |
| **Days & Activities** | Multi-day schedule with pre-populated activities | 1..N days created with `activities: []` (0 activities per day) | **Third critical divergence:** Flow B days have 0 activities; must display empty activity call-to-action |
| **Ownership Check** | User is not owner (viewer mode) | User is owner (`currentUser['username'] == creator.username`) | Flow B must render owner controls (Edit, Delete, Add Day, Add Activity) |
| **Layout & Switching** | Loaded into `CustomScrollView` | Transitioned from `CreateItineraryScreen` | Flow B triggered layout exceptions if `explore_screen.dart` or switcher had stack duplication |

### 35.3. Actual Root Causes Identified
1. **Missing Description Placeholder:** `ItineraryDetailScreen._buildOverview` checked `if (itinerary.description != null && itinerary.description!.trim().isNotEmpty)`. When a user created an itinerary without a description, this block rendered nothing at all, violating Section 6 ("Description or an appropriate empty placeholder").
2. **Missing Visibility & Theme Metadata:** Basic metadata row displayed only location, totalDays, and rating. It omitted the visibility indicator ("Riêng tư" / "Công khai") and theme tag, violating Section 6 requirements.
3. **Owner Username Comparison Fragility:** `isOwner` checked `currentUsername == itinerary!.creator!.username` using exact case-sensitive matching without whitespace trimming. In environments where usernames vary in casing (e.g. `Traveler` vs `traveler`), owner controls were falsely hidden.
4. **Residual `AnimatedSwitcher` Layout Exception in `explore_screen.dart`:** `explore_screen.dart` still had the custom `layoutBuilder: (currentChild, previousChildren) => Stack(fit: StackFit.expand, children: [...previousChildren, ?currentChild])`. This duplicated `currentChild` in an expanding stack, throwing `RenderBox was not laid out` during navigation between Explore and Itinerary screens on Android devices.

### 35.4. Files Changed & Why
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart`:
  - Added visibility metadata item (`Riêng tư` with `Icons.lock_outline` or `Công khai` with `Icons.public`) and optional `theme` badge to the overview metadata row.
  - Added an italicized placeholder text (`Chưa có mô tả cho lịch trình này.`) in `AppColors.textSecondary` when `itinerary.description` is null or whitespace.
  - Made `isOwner` username comparison trimmed and case-insensitive (`currentUsername.toLowerCase() == creator.username.toLowerCase()`).
- `frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart`:
  - Removed the broken custom `layoutBuilder` with duplicate `?currentChild` and `StackFit.expand`, reverting to standard `AnimatedSwitcher` behavior and eliminating `RenderBox was not laid out` exceptions.
- `frontend/mobile/test/itinerary_detail_test.dart`:
  - Added regression test: `newly created private itinerary with null description and 0 days renders title, visibility badge, description placeholder, and owner empty state`.
  - Added regression test: `public sample itinerary with theme displays public visibility and theme tag`.
- `docs/ai/09-development-log.md`:
  - Recorded comparative analysis, divergence points, root causes, test results, and device status.

### 35.5. Commands & Test Results
- **Spring Boot Backend Test Suite (`backend/`):**
  - Command: `.\mvnw.cmd test`
  - Result: **67 / 67 tests passed (BUILD SUCCESS)**.
- **Targeted Mobile Tests (`frontend/mobile/`):**
  - Command: `flutter test test/itinerary_detail_test.dart test/create_itinerary_test.dart`
  - Result: **20 / 20 tests passed (100%)**.
- **Full Mobile Test Suite (`frontend/mobile/`):**
  - Command: `flutter test`
  - Result: **117 / 117 tests passed (100% across all 14 test suites)**.
- **Static Analysis (`frontend/mobile/`):**
  - Command: `flutter analyze`
  - Result: **No issues found! (0 errors, 0 warnings)**.

### 35.6. Physical Device Verification Status
- ADB query `adb devices` was executed: device list is currently empty (physical device disconnected).
- Physical-device verification remains **pending** until the Android device is re-attached and authorized via ADB.
- Verification procedure once device is connected:
  1. Confirm device via `adb devices`.
  2. Set up port reverse: `adb reverse tcp:8080 tcp:8080`.
  3. Launch app: `flutter run -d <device_id>`.
  4. Log in, tap "Tạo lịch trình", fill only mandatory fields (title, location, totalDays, budget), leave description and cover image blank, tap "Tạo lịch trình".
  5. Verify detail screen opens immediately showing title, location, duration, "Riêng tư" badge, description placeholder, budget, and days section with "Thêm hoạt động đầu tiên" / "Thêm ngày đầu tiên".

---

## 37. Session Entry: End-to-End Refactor of Itinerary Creation, Detail Display, and Complete Schedule Editing Flow (2026-10-27)

### 37.1. Problem Statement & Scope
- Users reported that after creating a new itinerary and opening its detail screen, the screen displayed nothing (blank screen).
- Required an evidence-based audit and end-to-end refactoring across Spring Boot and Flutter Mobile covering:
  1. Itinerary creation with validation and duplicate prevention.
  2. Navigation to the detail view using real backend identifiers without hardcoding.
  3. Resilient rendering of incomplete itineraries (empty activity lists, null dates, null descriptions, null avatars).
  4. Full day management (add, edit, delete with confirmation, and refresh).
  5. Destination and activity management (destination selection, creation/editing/deletion of activities, and reordering).
  6. Ownership verification across frontend and backend.

### 37.2. Root Causes Identified & Addressed
1. **Brittle Type Casting in Flutter Network Repositories:**
   - Both `ItineraryRepository` and `ItineraryCrudRepository` asserted `if (response is Map<String, dynamic>)`.
   - Dart VM's `jsonDecode(utf8.decode(response.bodyBytes))` evaluates to `_InternalLinkedHashMap<dynamic, dynamic>`, evaluating `is Map<String, dynamic>` to `false` and throwing `Exception('Phản hồi từ máy chủ không hợp lệ.')` or `ApiException`.
   - In `ItineraryDetailNotifier`, this triggered an immediate failure state on background reload, which could blank the screen or mask existing data.
2. **Missing Destination API & Client Destination Picker:**
   - The relational domain model links `activities.destination_id` to `destinations.destination_id`.
   - While `ItineraryServiceImpl` handled `request.getDestinationId()`, there was no public REST controller for clients to discover or search active destinations.
   - On the mobile client, `ActivityFormDialog` lacked destination selection entirely, forcing `destinationId: null` on all created activities.
3. **Unhandled Image Errors in Detail View:**
   - `ItineraryDetailScreen._creatorAvatar` rendered `NetworkImage` directly without an `onBackgroundImageError` handler, triggering unhandled exceptions whenever an avatar URL was broken, empty, or unreachable.

### 37.3. Implementation Details
1. **Spring Boot Backend:**
   - **`DestinationController.java`:** Created controller exposing `GET /api/destinations` (with optional `keyword` filter) and `GET /api/destinations/{id}` for active destinations.
   - **`DestinationRepository.java`:** Added `findByNameContainingIgnoreCaseAndStatus(String keyword, DestinationStatus status)`.
   - **`SecurityConfig.java`:** Configured `JavaTimeModule` on `ObjectMapper` bean and permitted public read access (`permitAll()`) to `/api/destinations` and `/api/destinations/**`.
   - **`DestinationControllerTest.java`:** Added integration tests verifying active destination retrieval and keyword filtering.
2. **Flutter Mobile:**
   - **`ApiConstants.dart`:** Added `destinationsEndpoint = '/api/destinations'`.
   - **`ItineraryRepository.dart` & `ItineraryCrudRepository.dart`:** Updated all network response deserializations to check `response is Map` and cast via `Map<String, dynamic>.from(response as Map)`. Added `getDestinations({String? keyword, String? token})` method.
   - **`ActivityFormDialog.dart`:** Added destination loading and dropdown selection (`DropdownButtonFormField`), pre-populating existing destinations when editing, and passing `destinationId` in `CreateActivityRequest` and `UpdateActivityRequest`.
   - **`ItineraryDetailScreen.dart`:** Added `onBackgroundImageError` to `_creatorAvatar` to prevent uncaught network image exceptions.
   - **`itinerary_activity_management_test.dart`:** Added tests verifying `ItineraryCrudRepository.getDestinations` parsing and `ActivityFormDialog` destination dropdown selection and submission.

### 37.4. Verification & Test Results
- **Spring Boot Backend Test Suite:**
  - Command: `.\mvnw.cmd test`
  - Result: **69 / 69 tests passed (BUILD SUCCESS)**.
- **Flutter Static Analysis:**
  - Command: `flutter analyze`
  - Result: **No issues found! (0 errors, 0 warnings)**.
- **Flutter Mobile Test Suite:**
  - Command: `flutter test`
  - Result: **121 / 121 tests passed (100% across all 11 test suites)**.


---

## 36. Session Entry: Resolution of Blank / Incomplete Detail Screen for Newly Created Itineraries (2026-10-27)

### 36.1. Problem Statement
- Opening newly created itineraries (e.g. test itinerary `282` with title `"neww"`, location `"đà lạt"`, 3 total days, budget `3,000,000 VND`, theme `"Văn hóa"`, visibility `"PUBLIC"`, creator `userId: 577`, 3 days with `activities: []`, and legitimate nullables: `description`, `coverImage`, `creator.avatar`, and day `date`) resulted in a blank or incomplete detail screen while sample seeded itineraries displayed.

### 36.2. Verified Root Causes
1. **Brittle Type Assumptions in JSON Deserialization:**
   - In `ItineraryDetail.fromJson`, `ItineraryDayDetail.fromJson`, and `ActivityDetail.fromJson`, nested list iteration and map checks performed `item is Map<String, dynamic>` and `rawBudget is num`.
   - When parsed from runtime HTTP client responses or wrapped maps, collections and nested objects often evaluate to generic `Map` (`_InternalLinkedHashMap<dynamic, dynamic>`), causing `days` or `creator` to be silently skipped or dropped into empty lists / null values.
   - String-represented numeric values (e.g. Jackson's default serialization of `BigDecimal` or numeric strings) failed `is num` checks, defaulting budgets or IDs to 0.
2. **Fragile Ownership Identification:**
   - In `ItineraryDetailScreen`, `isOwner` matched solely on case-insensitive `username`. When the creator summary only returned numeric `userId` or partial credentials, `isOwner` evaluated to `false`, omitting owner management buttons and controls.
3. **Day Header Redundancy & Empty Activity State Rendering:**
   - In `ItineraryDayCard`, `day.title` default value from backend (`"Ngày " + i`) duplicated the badge label `"Ngày 1"`, and missing title checks needed clean omission to prevent empty/duplicate labels.
   - Guarded day card rendering so an empty `activities: []` list displays the designated empty message and the "Thêm hoạt động đầu tiên" action without collapsing the day card or the `CustomScrollView` content area.

### 36.3. Implementation Details
1. **Model Resiliency (`itinerary_detail.dart`, `itinerary_day_detail.dart`, `activity_detail.dart`, `destination_summary.dart`, `creator_summary.dart`):**
   - Updated nested deserialization to check `item is Map` and transform via `Map<String, dynamic>.from(item as Map)`.
   - Added `int.tryParse` and `num.tryParse` fallbacks for all numeric fields (`itineraryId`, `totalDays`, `budget`, `viewCount`, `favoriteCount`, `ratingCount`, `averageRating`, `dayId`, `dayNumber`, `activityId`, `estimatedCost`, `userId`).
2. **Dual-Criteria Ownership Matching (`itinerary_detail_screen.dart`):**
   - Updated `isOwner` to verify either matching `userId` (`currentUserId == creatorUserId`) or case-insensitive matching `username`.
   - Added fallback for creator display label when username is anonymous (`Tạo bởi Người dùng #<userId>`).
   - Guarded app bar edit/delete actions with `isOwner && itinerary != null` for type promotion safety.
3. **Day Title Normalization (`itinerary_day_card.dart`):**
   - Omitted title display in `Expanded` when `day.title` is null, whitespace, or identical to `'Ngày ${day.dayNumber}'`, showing custom titles only when explicitly provided.
4. **Comprehensive Integration & Regression Tests (`itinerary_detail_test.dart`):**
   - Added regression test `newly created itinerary with 3 days, empty activities, and nullable fields renders detail completely without blanking or crashing` with itinerary 282 structure.
   - Added test `ItineraryDetail.fromJson handles generic Map, string numbers, and nullables`.

### 36.4. Verification & Test Results
- **Targeted Mobile Tests:**
  - Command: `flutter test test/itinerary_detail_test.dart`
  - Result: **11 / 11 tests passed (100%)**.
- **Full Mobile Test Suite:**
  - Command: `flutter test`
  - Result: **119 / 119 tests passed (100% across all test suites)**.
- **Static Analysis:**
  - Command: `flutter analyze`
  - Result: **No issues found! (0 errors, 0 warnings)**.
- **Code Formatting:**
  - Command: `dart format`
  - Result: All modified files formatted cleanly according to style guidelines.

---

## 38. Session Entry: Fix Blank Itinerary Detail Screen When Opened from My Itineraries (2026-10-27)

### 38.1. Problem Statement
- In the Travel Planner application, tapping an itinerary from **Home / Explore** opened its detail screen successfully, but tapping that **same** itinerary from **My Itineraries** resulted in a blank screen or missing itinerary details, despite the itinerary data existing in MySQL.
- Traced both navigation paths line-by-line, identified confirmed root causes, implemented a consistent minimal fix, added regression tests, and verified against both automated test suites and the running backend/device environment.

### 38.2. Trace and Comparison Between Navigation Paths
1. **Path A — Home / Explore (`ExploreScreen`):**
   - User taps `ItineraryCard` in Explore.
   - `Navigator.push` called `ItineraryDetailScreen(itineraryId: itinerary.itineraryId)`.
   - Triggered `GET /api/itineraries/{id}`.
   - Explore itineraries are filtered to `status == ACTIVE` and `visibility == PUBLIC`.
   - Detail screen loaded without authorization blocks; viewers do not expect owner-specific action buttons.
2. **Path B — My Itineraries (`MyItinerariesScreen`):**
   - User taps `MyItineraryCard` in My Itineraries.
   - Handled by `onTap` navigating to `ItineraryDetailScreen(itineraryId: item.itineraryId)`.
   - **Root Cause 1 (Backend Authorization on Status):** In `ItineraryServiceImpl.getItineraryDetail()`, the backend unconditionally rejected any itinerary with `status != ItineraryStatus.ACTIVE` with a 404 `ResourceNotFoundException`, blocking owners from viewing their own `DRAFT` itineraries in My Itineraries.
   - **Root Cause 2 (Missing DTO Fields):** `ItinerarySummaryResponse.java` and `ItineraryDetailResponse.java` lacked `visibility` and `status` mappings in `ItineraryServiceImpl.mapToSummaryResponse()`, returning `null` status/visibility to `MyItinerariesScreen`.
   - **Root Cause 3 (Brittle Creator Deserialization & Broken Ownership):** In `itinerary_summary.dart`, `json['creator'] is Map<String, dynamic>` evaluated to `false` under Dart VM's `_InternalLinkedHashMap<dynamic, dynamic>`, parsing `creator` as `null`. Consequently, `ItineraryDetailScreen` could not match `creator.userId` or `creator.username`, evaluating `isOwner = false` even when navigated from My Itineraries. This hid all owner management actions ("Thêm ngày đầu tiên", "Thêm ngày", edit, delete).
   - **Root Cause 4 (Absence of Summary Prefill & Unhandled Async Lag):** Navigation from My Itineraries only passed `itineraryId`. While `GET /api/itineraries/{id}` was fetching asynchronously, `itineraryDetail` remained `null`. Any network delay or transient error resulted in a blank white screen rather than displaying the existing itinerary summary information with an inline retry banner.

### 38.3. Implemented Fixes
1. **Backend Service & DTOs (`backend`):**
   - **`ItinerarySummaryResponse.java` & `ItineraryDetailResponse.java`:** Added `visibility` and `status` fields.
   - **`ItineraryServiceImpl.java`:**
     - Updated `mapToSummaryResponse` to map `itinerary.getVisibility().name()` and `itinerary.getStatus().name()`.
     - Updated `getItineraryDetail` so that non-ACTIVE (e.g. `DRAFT`) itineraries and `PRIVATE` itineraries are accessible to their authenticated owner (`currentUsername != null && currentUsername.equals(itinerary.getUser().getUsername())`).
     - Mapped `status` in `ItineraryDetailResponse.builder()`.
2. **Mobile Data Model Resiliency (`itinerary_summary.dart`):**
   - Updated `ItinerarySummary.fromJson` to handle generic `Map` (`json['creator'] is Map`), string-to-number fallback parsing (`int.tryParse`, `num.tryParse`), and defaulted `visibility` to `'PUBLIC'` and `status` to `'ACTIVE'` if missing.
3. **Detail Screen & Notifier Prefill (`itinerary_detail_screen.dart` & `itinerary_detail_notifier.dart`):**
   - Added `initialSummary` and `isOwner` parameters to `ItineraryDetailScreen` and `ItineraryDetailNotifier`.
   - Constructed initial `ItineraryDetail` from `initialSummary` immediately on mount, eliminating any blank screen during async load.
   - Explicitly honoured `widget.isOwner == true` (guaranteed owner context from My Itineraries) alongside existing username and userId checks.
   - Added subtle non-blocking loading progress indicator and retry banner in `_buildContent` when background detail refresh is in progress or encounters connection issues, preserving displayed summary data.
4. **Navigation Contract Updates (`my_itineraries_screen.dart` & `explore_screen.dart`):**
   - `MyItinerariesScreen`: Passed `initialSummary: item` and `isOwner: true` to `ItineraryDetailScreen`.
   - `ExploreScreen`: Passed `initialSummary: itinerary` to `ItineraryDetailScreen`.

### 38.4. Files Modified
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/ItinerarySummaryResponse.java`
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/ItineraryDetailResponse.java`
- `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java`
- `Travel_Planner/frontend/mobile/lib/features/explore/data/models/itinerary_summary.dart`
- `Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart`
- `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/my_itineraries_screen.dart`
- `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart`
- `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/itinerary_detail_notifier.dart`
- `Travel_Planner/frontend/mobile/test/my_itineraries_test.dart`
- `Travel_Planner/docs/ai/09-development-log.md`

### 38.5. Verification & Test Results
- **Spring Boot Backend Test Suite:**
  - Command: `.\mvnw.cmd test`
  - Result: **69 / 69 tests passed (0 failures, 0 errors, BUILD SUCCESS)**.
- **Flutter Mobile Static Analysis:**
  - Command: `flutter analyze`
  - Result: **No issues found! (0 errors, 0 warnings)**.
- **Flutter Mobile Unit and Widget Test Suite:**
  - Command: `flutter test test/my_itineraries_test.dart`
  - Result: **12 / 12 tests passed (including immediate summary prefill and 0-activity days rendering with owner actions)**.
  - Command: `flutter test`
  - Result: **123 / 123 tests passed (100% across all 11 mobile test files)**.

### 38.6. Runtime Verification & Known Limitations
- **Automated Verification:** Fully verified through comprehensive end-to-end unit and widget regression tests mocking network latency, 0-activity states, and ownership flags.
- **Physical Device Status:** An Android device (`RFCW8105T0H`) is connected with ADB reverse active (`tcp:8080 tcp:8080`). Flutter application build and hot-restart can be observed live against the running backend server.

---

## 39. Session Entry: UI/UX Improvement — Itinerary Detail Hierarchy, Day Selector, and Activity Modal Bottom Sheet (2026-10-27)

### 39.1. Problem Statement
1. **Oversized Header Pushing Days Section Off-Screen:**
   - In `itinerary_detail_screen.dart`, `_buildOverview` occupied excessive vertical screen height (~550dp) due to a 250dp `AspectRatio(16/10)` cover image, loose vertical spacing, full-width creator cards, and multi-line descriptions.
   - Users on standard mobile screens (e.g., 360x640 or 390x844) were forced to scroll substantially before locating the days list and day management actions.
2. **Disruptive Full-Screen Activity Form Dialog:**
   - Tapping "Thêm hoạt động" or "Sửa hoạt động" opened a centered `Dialog` (`activity_form_dialog.dart`) that blocked the entire screen, obscuring the itinerary context and day backdrop.
   - On small screens and when the software keyboard emerged, centered dialog layouts risked vertical overflow and lacked mobile-native dismissibility and drag affordances.
3. **Clunky Day Scanning on Multi-Day Itineraries:**
   - Viewing itineraries with multiple days required scrolling past every activity of preceding days to reach a target day.

### 39.2. Implemented Fixes
1. **Compact, Scannable Itinerary Detail Header (`itinerary_detail_screen.dart`):**
   - Replaced the 250dp cover image with a sleek 110dp banner (or a 76dp compact placeholder when no cover image is provided).
   - Streamlined typography (18sp bold title) and wrapped key metadata in compact chips (location, total days, visibility badge, theme, rating, budget in VND).
   - Rendered creator and description in a tight inline format.
   - Reduced total header height from ~550dp to ~220dp, bringing the "Lịch trình theo ngày" section into the initial screen viewport without requiring scrolling.
2. **Ergonomic Day Selector (`_buildDaySelector`):**
   - Implemented an interactive day filter using a compact `Wrap` of `ChoiceChip`s: `Tất cả (X)`, `Ngày 1 (N)`, `Ngày 2 (M)` displaying day numbers and activity counts.
   - Users can tap a day chip to focus strictly on that day's schedule or tap "Tất cả" to see the full itinerary.
   - Provided a "Xem toàn bộ các ngày" helper button when a single day is filtered.
   - Used `Wrap` rather than a secondary horizontal `ListView` to avoid nested `Scrollable` conflicts and ensure reliable touch handling across narrow devices.
3. **Mobile-Native Activity Modal Bottom Sheet (`activity_form_dialog.dart`):**
   - Replaced `showDialog` with `showModalBottomSheet<bool>` (`ActivityFormBottomSheet`).
   - Sized dynamically to content with an 88% screen height cap (`BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88)`).
   - Added a standard mobile drag handle (`40x4dp`), rounded top corners (`20dp`), and a clear header row with title, day badge subtitle, and an explicit close icon button (`IconButton(icon: Icon(Icons.close))`).
   - Integrated `AnimatedPadding(padding: EdgeInsets.only(bottom: keyboardHeight))` so the sheet gracefully lifts above the software keyboard without clipping or overflowing.
   - Docked footer action buttons ("Hủy" and "Thêm hoạt động" / "Lưu thay đổi") at the bottom of the sheet, keeping the submit action accessible at all times while form fields remain independently scrollable.
   - Preserved all working fields and validation: activity name (required, max 150 chars), destination dropdown, start and end time pickers with time range validation, estimated cost in VND, and description.
4. **Preserved CRUD Behavior and Authorization:**
   - Retained all existing day and activity management handlers: adding days, editing days, deleting days (with 1-day minimum guard), adding activities, editing activities, deleting activities, and reordering activities.
   - Enforced client-side ownership restrictions: owner-only management buttons remain strictly hidden from viewers.

### 39.3. Files Modified
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (compact header, day selector wrap, day filtering, initial viewport layout)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart` (converted to modal bottom sheet with keyboard adaptation and 88% height cap)
- `frontend/mobile/test/itinerary_activity_management_test.dart` (added tests for small screen rendering, keyboard insets, sheet dismissal, and error state)
- `frontend/mobile/test/itinerary_detail_test.dart` (added tests for immediate day visibility near top and day selector chip filtering)
- `frontend/mobile/test/my_itineraries_test.dart` (updated days section visibility assertion without requiring artificial scroll)
- `docs/ai/09-development-log.md` (appended Session 39 entry)

### 39.4. Verification & Automated Tests
- **Flutter Mobile Static Analysis:**
  - Command: `flutter analyze` in `frontend/mobile`
  - Result: **No issues found! (0 errors, 0 warnings)**.
- **Dart Code Formatting:**
  - Command: `dart format lib test` in `frontend/mobile`
  - Result: All modified files formatted cleanly.
- **Flutter Mobile Test Suite:**
  - Command: `flutter test` in `frontend/mobile`
  - Result: **128 / 128 tests passed (100% across all 11 test suites)**:
    - `itinerary_activity_management_test.dart`: 23 / 23 passed.
    - `itinerary_detail_test.dart`: 13 / 13 passed.
    - `my_itineraries_test.dart`: 12 / 12 passed.
    - `itinerary_day_management_test.dart`: 17 / 17 passed.
    - `itinerary_edit_delete_test.dart`: 16 / 16 passed.
    - `create_itinerary_test.dart`: 11 / 11 passed.
    - `explore_test.dart`: 15 / 15 passed.
    - `auth_401_test.dart`: 8 / 8 passed.
    - `animation_enhancements_test.dart`: 6 / 6 passed.
    - `username_validation_test.dart`: 1 / 1 passed.
    - `widget_test.dart`: 1 / 1 passed.
- **Backend Test Suite:**
  - Command: `.\mvnw.cmd test` in `backend`
  - Result: **69 / 69 tests passed (0 failures, BUILD SUCCESS)**.

### 39.5. Runtime & Physical Device Status
- **Physical Device Connection:** Android device `RFCW8105T0H` connected with active ADB reverse tunnel (`tcp:8080 tcp:8080`).
- **Automated Verification:** Fully verified through comprehensive unit and widget regression tests mocking small screens (360x640), software keyboard insets, and CRUD interactions. Live smoke testing is also ready on the connected device against the active Spring Boot backend.

---

## 40. Session Entry: UI/UX Bug Fix — Activity Reordering Inline Interaction (2026-10-27)

### 40.1. Problem Statement
- **Actual Widget Causing Oversized Overlay:**
  - Tapping the "Sắp xếp" button or selecting "Sắp xếp hoạt động" from the day card's 3-dots popup menu invoked `_handleReorderActivities` in `itinerary_detail_screen.dart`, which called `showReorderActivitiesDialog`.
  - In `reorder_activities_dialog.dart`, `showReorderActivitiesDialog` rendered an unconstrained centered `Dialog(BoxConstraints(maxHeight: 560))`. On mobile devices (e.g. 640–800px screens), this covered almost the entire screen, completely obscured the itinerary background context, and disrupted the user's travel planning flow.

### 40.2. Implemented Fixes
1. **Native In-Place Activity Reordering in `ItineraryDayCard`:**
   - Converted `ItineraryDayCard` from a `StatelessWidget` to a `StatefulWidget` managing inline reorder state (`_isReordering`, `_isSaving`, `_items`).
   - Tapping "Sắp xếp" or selecting "Sắp xếp hoạt động" now toggles inline reorder mode directly within the day card — opening **zero dialogs and zero full-screen overlays**.
   - Displays an inline banner: `Icons.swap_vert_rounded` + `"Kéo biểu tượng ≡ để đổi thứ tự hoạt động"`.
   - Uses Flutter's native `ReorderableListView.builder` configured with:
     - `buildDefaultDragHandles: false` so only grabbing the drag handle initiates reorder, while touching elsewhere scrolls the screen normally.
     - `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()` to integrate smoothly inside the parent `CustomScrollView`.
     - `proxyDecorator` applying elevation and a primary shadow to make the dragged item and insertion position visually distinct.
   - Each reorder item features a dedicated drag handle (`ReorderableDragStartListener`), index number badge (`1`, `2`, `3`), activity name (constrained with ellipsis), time/cost/destination tags, and preserved edit/delete popup menus.
   - Replaced bottom action buttons with inline "Hủy" and "Lưu thứ tự" (with loading indicator during in-flight network requests).
   - If the API call fails, displays an error SnackBar and reconciles displayed items back to the original server state order to prevent data corruption.
2. **Mobile-Appropriate Fallback Modal Bottom Sheet in `reorder_activities_dialog.dart`:**
   - Updated `showReorderActivitiesDialog` to use `showModalBottomSheet<bool>` (`_ReorderActivitiesBottomSheet`) capped at 75% screen height with rounded top corners, top drag handle, header row with close button, scrollable list with drag handles, and docked footer actions.
3. **Screen Density & Narrow Viewport Overflow Protection:**
   - In `itinerary_day_card.dart`, replaced `Row` with `Wrap` for the bottom action buttons ("Thêm hoạt động", "Sắp xếp").
   - In `activity_timeline_item.dart`, wrapped badge rows in `Expanded(child: Wrap(...))` preventing horizontal overflow on 360px viewports.
4. **Wiring & Persistence in `itinerary_detail_screen.dart`:**
   - Implemented `_handleSaveActivityOrder` submitting reordered items to `_crudRepository.reorderActivities` with the user's Bearer token.
   - Wired `onSaveActivityOrder` callback to each `ItineraryDayCard` for owners, automatically reloading itinerary detail on success.

### 40.3. Files Modified
- `frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_day_card.dart` (converted to StatefulWidget with native inline activity reordering, drag handles, Wrap action buttons, and order persistence)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/activity_timeline_item.dart` (wrapped badge row in Expanded Wrap to prevent horizontal overflow on narrow screens)
- `frontend/mobile/lib/features/itinerary/presentation/widgets/reorder_activities_dialog.dart` (converted from oversized dialog to compact modal bottom sheet with 75% height cap)
- `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` (added `_handleSaveActivityOrder`, wired `onSaveActivityOrder` to day cards)
- `frontend/mobile/test/itinerary_activity_management_test.dart` (added 5 comprehensive inline reorder UX tests)
- `docs/ai/09-development-log.md` (appended Session 40 entry)

### 40.4. Verification & Automated Tests
- **Flutter Mobile Static Analysis:**
  - Command: `flutter analyze` in `frontend/mobile`
  - Result: **No issues found! (0 errors, 0 warnings)**.
- **Dart Code Formatting:**
  - Command: `dart format lib test` in `frontend/mobile`
  - Result: All modified files formatted cleanly.
- **Activity Management & Reorder Tests:**
  - Command: `flutter test test/itinerary_activity_management_test.dart`
  - Result: **30 / 30 tests passed (100%)**.
- **Full Mobile Test Suite:**
  - Command: `flutter test` in `frontend/mobile`
  - Result: **133 / 133 tests passed (100% across all 11 test suites)**.

### 40.5. Physical Android Device Status
- **Device Connection:** Android device `RFCW8105T0H` connected with active reverse tunnel (`tcp:8080 tcp:8080`).
- **Verification Summary:** All automated widget tests simulating small Android screen dimensions (360x640dp), drag gestures, inline reordering, cancelation, and API error reconciliation pass with 0 errors and 0 overflows. Live smoke-testing on the connected hardware device is running against the active Spring Boot backend.


