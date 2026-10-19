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


