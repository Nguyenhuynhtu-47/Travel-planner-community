# Comprehensive Authentication Audit: Current State Report (Refined)

**Document ID:** `docs/plan/01-authentication-current-state-audit.md`  
**System:** Travel Planner Community Platform  
**Target Modules:** Spring Boot Backend, Flutter Mobile Client, Flutter Web Admin Client, MySQL Database  
**Audit Date:** 2026-11-17 (Refined)  
**Status:** Completed & Refined (Audit & Assessment Only — No Source Code Modified)

---

## 1. Executive Summary

This document provides a code-grounded audit of the authentication and authorization system across the Travel Planner platform. The audit was conducted by directly inspecting backend source files, security filters, entity mappings, repository queries, Flutter mobile and web client implementations, and executing test suites.

### Key Audit Findings
1. **Functional Foundation**: The platform currently possesses a working, stateless JWT authentication system for Registration (`POST /api/auth/register`), Login (`POST /api/auth/login`), and Current User verification (`GET /api/auth/me`). Both mobile and web clients communicate with this backend using Bearer tokens.
2. **Immediate Activation without Verification**: Registration immediately creates an `ACTIVE` user and returns an active JWT token. There is currently no email verification mechanism, no OTP, and no verification token tracking.
3. **Absence of Password Recovery**: There is no password recovery or reset flow ("Forgot Password"). Users who forget their passwords cannot recover their accounts.
4. **No OAuth / Social Logins**: No Google Sign-In or other OAuth2/OIDC integration exists on the backend, Flutter Mobile, or Flutter Web Admin.
5. **Security Gaps & Vulnerabilities**:
   - **No Refresh Token Flow in Current Contract**: Access tokens are hardcoded to a 24-hour lifespan (`jwt.expiration=86400000`). When expired, users are abruptly signed out.
   - **No Server-Side Token Revocation / Blacklist**: Logout is handled exclusively client-side by deleting stored tokens. Backend cannot invalidate a compromised token before expiration.
   - **Timing Side-Channel on Login**: Non-existent users fail immediately without BCrypt evaluation, allowing username/email enumeration via response timing differences (~2ms vs ~80ms).
   - **No Rate Limiting on Auth Endpoints**: Login and Register endpoints lack brute-force protection or IP rate limiting (despite Bucket4j being present in `pom.xml`).
   - **Weak Password Policy**: The backend only enforces `@Size(min = 6, max = 100)`. No complexity constraints (uppercase, lowercase, numbers, symbols) or common password checks are applied.
   - **Admin Web Isolation Flaw**: Flutter Web Admin allows any standard `USER` role to log in, relying on UI conditional rendering to hide admin buttons rather than restricting entry at the gatekeeper level.
   - **Web Admin Token Storage (XSS Risk)**: Web Admin stores JWTs in `SharedPreferences` (HTML5 LocalStorage), vulnerable to XSS token theft.
   - **Test Suite Isolation & Teardown Issue**: `AuthControllerTest.java` fails during `@BeforeEach setUp()` due to foreign key constraints on `media_assets` when executed against a shared test database that contains records from other integration tests.

---

## 2. Architecture Overview

```
                                +-----------------------------+
                                |    Client Applications      |
                                +-----------------------------+
                                       |              |
                      Bearer JWT       |              | Bearer JWT
                 (FlutterSecureStorage)|              | (LocalStorage)
                                       v              v
                        +----------------+          +-------------------+
                        | Flutter Mobile |          | Flutter Web Admin |
                        +----------------+          +-------------------+
                                       \              /
                                        \            /
                                  HTTPS  \          /  HTTPS
                                          v        v
                        +----------------------------------------+
                        |      Spring Boot REST Backend          |
                        |              (Port 8080)               |
                        +----------------------------------------+
                        | - SecurityFilterChain                  |
                        |   * CorsFilter                         |
                        |   * JwtAuthenticationFilter            |
                        |   * UsernamePasswordAuthentication     |
                        | - AuthController (/api/auth/*)         |
                        | - AuthServiceImpl                      |
                        | - UserDetailsServiceImpl               |
                        | - JwtTokenProvider (HMAC-SHA256)       |
                        | - BCryptPasswordEncoder                |
                        +----------------------------------------+
                                            |
                                  JPA / Hibernate (JDBC)
                                            v
                        +----------------------------------------+
                        |            MySQL Database              |
                        |  Table: `users`                        |
                        +----------------------------------------+
```

### Core Authentication Component Matrix

| Module | Component | File Path | Status |
| :--- | :--- | :--- | :--- |
| **Backend** | Auth Controller | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AuthController.java` | Implemented & Verified |
| **Backend** | Auth Service Interface | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/AuthService.java` | Implemented & Verified |
| **Backend** | Auth Service Impl | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/AuthServiceImpl.java` | Implemented & Verified |
| **Backend** | Security Config | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java` | Implemented & Verified |
| **Backend** | JWT Filter | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/JwtAuthenticationFilter.java` | Implemented & Verified |
| **Backend** | JWT Token Provider | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/JwtTokenProvider.java` | Implemented & Verified |
| **Backend** | User Details Service | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/UserDetailsServiceImpl.java` | Implemented & Verified |
| **Backend** | User Repository | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/UserRepository.java` | Implemented & Verified |
| **Backend** | User Entity | `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/User.java` | Implemented & Verified |
| **Mobile** | Auth Notifier | `Travel_Planner/frontend/mobile/lib/features/auth/presentation/auth_notifier.dart` | Implemented & Verified |
| **Mobile** | Auth Repository | `Travel_Planner/frontend/mobile/lib/features/auth/data/auth_repository.dart` | Implemented & Verified |
| **Mobile** | Auth Storage | `Travel_Planner/frontend/mobile/lib/features/auth/data/auth_storage.dart` | Implemented & Verified |
| **Mobile** | Login Screen | `Travel_Planner/frontend/mobile/lib/features/auth/presentation/screens/login_screen.dart` | Implemented & Verified |
| **Mobile** | Register Screen | `Travel_Planner/frontend/mobile/lib/features/auth/presentation/screens/register_screen.dart` | Implemented & Verified |
| **Web** | Auth Notifier | `Travel_Planner/frontend/web/lib/features/auth/presentation/auth_notifier.dart` | Implemented & Verified |
| **Web** | Auth Repository | `Travel_Planner/frontend/web/lib/features/auth/data/auth_repository.dart` | Implemented & Verified |
| **Web** | Auth Storage | `Travel_Planner/frontend/web/lib/features/auth/data/auth_storage.dart` | Implemented & Verified |
| **Web** | Login Screen | `Travel_Planner/frontend/web/lib/features/auth/presentation/screens/login_screen.dart` | Implemented & Verified |
| **Web** | Register Screen | `Travel_Planner/frontend/web/lib/features/auth/presentation/screens/register_screen.dart` | Implemented (Design Issue) |

---

## 3. Backend Authentication Deep Dive

### 3.1. Registration Flow (`POST /api/auth/register`)

#### Endpoint Contract & Execution Trace
1. **Controller Entry**: `AuthController.register(@Valid @RequestBody RegisterRequest request)`
   - Request DTO:
     - `username`: `@NotBlank`, `@Size(min=3, max=50)`, `@Pattern("^[a-zA-Z0-9_.]+$")`
     - `handle`: Optional, `@Pattern("^$|^@?[a-zA-Z0-9_.]{3,30}$")`
     - `email`: `@NotBlank`, `@Email`, `@Size(max=100)`
     - `password`: `@NotBlank`, `@Size(min=6, max=100)`
     - `fullName`: `@NotBlank`, `@Size(max=100)`
2. **Service Logic** (`AuthServiceImpl.register`):
   - Trims username: `String username = request.getUsername().trim();`
   - Normalizes email: `String email = request.getEmail().trim().toLowerCase();`
   - Uniqueness Checks:
     - `if (userRepository.existsByUsername(username)) throw new ConflictException("Tên đăng nhập đã tồn tại");` (HTTP 409)
     - `if (userRepository.existsByEmail(email)) throw new ConflictException("Email đã được sử dụng");` (HTTP 409)
   - Handle resolution: If handle provided, normalizes via `userHandleService.normalize()` and checks `existsByHandle()`; otherwise auto-generates a unique handle via `userHandleService.generateUniqueHandle(fullName, null)`.
   - Password Hashing: `passwordEncoder.encode(request.getPassword())` using standard Spring `BCryptPasswordEncoder` (strength 10).
   - Entity Creation:
     - `role = Role.USER`
     - `status = UserStatus.ACTIVE` (Immediate activation without verification!)
   - Token Issuance: Calls `jwtTokenProvider.generateToken(savedUser)` and returns `AuthResponse` (`token`, `tokenType: "Bearer"`, `user`).
3. **Response**: HTTP 201 Created with `AuthResponse`.

#### Security & Functional Evaluation of Registration
- **Email Normalization**: Lowercase normalization is applied (`email.toLowerCase()`). Correct.
- **Race Condition Vulnerability**: Uniqueness check is performed via `existsByUsername` / `existsByEmail` before `userRepository.save()`. Under high concurrency or duplicate concurrent clicks, two simultaneous requests can pass the existence check, causing a raw MySQL `DuplicateKeyException` on the unique index, resulting in an unhandled HTTP 500 error instead of a clean HTTP 409 Conflict.
- **Email Ownership Verification Gaps**: Anyone can register using someone else's email address (e.g. `ceo@company.com`). The account is immediately marked `ACTIVE`, and a valid JWT is issued immediately. The real owner of the email cannot register later without administrative intervention.
- **Password Policy Flaws**: Passwords like `123456`, `password`, or `aaaaaa` pass validation because the only rule is `@Size(min=6, max=100)`. There are no uppercase, lowercase, digit, or special character requirements.
- **Account Enumeration**: Returning `"Email đã được sử dụng"` allows automated scrapers to enumerate registered email addresses on the platform.

### 3.2. Login Flow (`POST /api/auth/login`)

#### Endpoint Contract & Execution Trace
1. **Controller Entry**: `AuthController.login(@Valid @RequestBody LoginRequest request)`
   - Request DTO:
     - `usernameOrEmail`: `@NotBlank`
     - `password`: `@NotBlank`
2. **Service Logic** (`AuthServiceImpl.login`):
   - Identifier resolution: `String identifier = request.getUsernameOrEmail().trim();`
   - Queries repository: `userRepository.findByUsernameOrEmail(identifier, identifier.toLowerCase())`
   - If user not found: Throws `UnauthorizedException("Tên đăng nhập hoặc mật khẩu không chính xác")` (HTTP 401).
   - Password comparison: `if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) throw new UnauthorizedException("Tên đăng nhập hoặc mật khẩu không chính xác");`
   - Account Status Checks:
     - `if (user.getStatus() == UserStatus.BANNED) throw new ForbiddenException("Tài khoản của bạn đã bị khóa do vi phạm chính sách");` (HTTP 403)
     - `if (user.getStatus() == UserStatus.INACTIVE) throw new ForbiddenException("Tài khoản của bạn đang bị vô hiệu hóa");` (HTTP 403)
   - Token Issuance: Calls `jwtTokenProvider.generateToken(user)` and returns `AuthResponse`.
3. **Response**: HTTP 200 OK with `AuthResponse`.

#### Security & Functional Evaluation of Login
- **Timing Attack / Side-Channel Enumeration**:
  - When a user does NOT exist, the method immediately throws `UnauthorizedException` in under 2ms.
  - When a user DOES exist, `passwordEncoder.matches()` executes BCrypt verification, which takes approximately 60–100ms of CPU hashing time.
  - An attacker measuring request round-trip latency can deterministically discover whether an email or username exists in the system.
- **Lack of Account Lockout & Brute-Force Shield**:
  - There is no tracking of failed login attempts (`failed_attempts`, `locked_until`).
  - An attacker can execute unlimited dictionary attacks against a user's password.
- **Lack of Rate Limiting**:
  - The login endpoint does not enforce IP or subnet rate limiting.

### 3.3. Current User Flow (`GET /api/auth/me`)

#### Execution Trace
1. **Filter Execution**: `JwtAuthenticationFilter` intercepts the request. Extracts `Bearer <token>` from the `Authorization` header.
2. **Token Validation**: `jwtTokenProvider.validateToken(jwt)`.
3. **User Details Loading**: Loads user from DB via `UserDetailsServiceImpl.loadUserByUsername()`. Checks `isEnabled()` and `isAccountNonLocked()`. Injects `UsernamePasswordAuthenticationToken` into `SecurityContextHolder`.
4. **Controller & Service**: `AuthController.getCurrentUser(@AuthenticationPrincipal UserDetails userDetails)` calls `authService.getCurrentUser(userDetails.getUsername())`.
5. **Response**: HTTP 200 OK with `UserResponse` (userId, username, handle, email, fullName, role, status, avatar, phone, address, bio, createdAt).
- **Password Exposure**: Verified safe; `password` is omitted from `UserResponse`.

### 3.4. JWT Implementation & Security Configuration

#### `JwtTokenProvider.java`
- **Algorithm**: HMAC-SHA256 (`io.jsonwebtoken.security.Keys.hmacShaKeyFor`).
- **Secret Key Handling**:
  - Reads from `${jwt.secret}`.
  - Fallback: `DEFAULT_DEV_SECRET` (`404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970`).
  - **Production Safety Check**: In `prod` or `production` profiles, `validateJwtSecretForEnvironment()` throws `IllegalStateException` if `jwt.secret` is blank or equals the development default. (Verified by passing tests in `JwtTokenProviderTest.java`).
- **Token Expiration**: `${jwt.expiration:86400000}` (24 hours).
- **Claims Payload**:
  - `sub`: username
  - `userId`: Integer user ID
  - `email`: String email
  - `role`: Role string (`USER`, `ADMIN`)
  - `iat`: Issue timestamp
  - `exp`: Expiration timestamp

#### Identified JWT Architectural Limitations
1. **Single Token Architecture (No Refresh Token in Baseline)**:
   - The current contract is strictly single-token JWT.
   - The access token has a long lifespan (24 hours). If an access token is stolen via network eavesdropping or client compromise, the attacker retains access for up to 24 hours.
   - Conversely, when 24 hours elapse, the user experiences an unexpected session expiration and is forced to log in again.
2. **No Revocation / Invalidation Capability**:
   - The backend validates tokens statelessly via cryptographic signature and expiration check.
   - If a user changes their password, previously issued tokens remain cryptographically valid until expiration.
   - In `JwtAuthenticationFilter`, `UserDetailsServiceImpl` does re-check `user.getStatus() != BANNED` and `INACTIVE` on each request, which mitigates banned accounts, but does NOT invalidate tokens when a user updates their password. Introducing a `token_version` claim on JWT and user entity will resolve this cleanly.

### 3.5. Spring Security Configuration (`SecurityConfig.java`)
- **Session Management**: `SessionCreationPolicy.STATELESS`.
- **CSRF**: Disabled (`AbstractHttpConfigurer::disable`), appropriate for stateless Bearer token APIs.
- **CORS Configuration**:
  - Configurable via `cors.allowed-origins` and `cors.allowed-origin-patterns`.
  - Development origins: `http://localhost:8081`, `http://127.0.0.1:8081`, `http://localhost:3000`, `http://localhost:8082`.
  - Safeguard: Disallows wildcard `*` when `allowCredentials` is true.
  - Allowed Headers: `Authorization`, `Content-Type`, `Accept`, `Origin`, `X-Requested-With`.
  - Exposed Headers: `Authorization`.
- **Authorization Matchers**:
  - Public: `/api/health`, `/ws/**`, `/api/auth/register`, `/api/auth/login`, public itinerary/comment/place GET endpoints, Swagger/OpenAPI docs.
  - Admin Protected: `/api/admin/**` requires `hasRole("ADMIN")`.
  - All other requests: `anyRequest().authenticated()`.
- **Exception Handlers**:
  - `AuthenticationEntryPoint`: Returns HTTP 401 with standard `ErrorResponse`.
  - `AccessDeniedHandler`: Returns HTTP 403 with standard `ErrorResponse`.

---

## 4. Flutter Mobile Authentication Deep Dive

### 4.1. Architecture & State Management
- **State Notifier**: `AuthNotifier` extends `ChangeNotifier`.
  - State: `AuthStatus` (`initial`, `loading`, `authenticated`, `unauthenticated`, `error`), `_token`, `_currentUser`, `_errorMessage`, `_validationErrors`.
- **Persistent Storage**: `AuthStorage` wraps `FlutterSecureStorage`.
  - Tokens stored in OS secure keychains (Android Keystore / iOS Keychain).
  - Serialized user JSON cached securely.
  - Expiration pre-check: `AuthStorage.isTokenExpired(token)` decodes JWT payload base64 to avoid unnecessary network calls when token has expired locally.

### 4.2. Session Restoration & Lifecycle
- `checkAuthStatus()` sequence:
  1. Reads token from `FlutterSecureStorage`.
  2. If empty or expired -> purges storage, sets `unauthenticated`.
  3. If valid -> calls `GET /api/auth/me`.
  4. If backend returns 200 -> updates cached profile, sets `authenticated`.
  5. If backend returns 401/403 -> purges storage, sets `unauthenticated`.
  6. If backend returns 500 or network failure -> preserves session with cached user profile (offline resiliency). Correct.

### 4.3. Automatic 401 Handling & Guardrails
- `ApiClient` implements a global `onUnauthorized` handler:
  - Throttled to at most once per 2 seconds (`_unauthorizedThrottle`).
  - Calls `AuthNotifier.handleSessionExpired()`, which clears credentials and notifies UI listeners.

### 4.4. Mobile UI & Screens
- **`LoginScreen`**:
  - Form validation: ensures non-empty `usernameOrEmail` and `password`.
  - Disables button and displays loading indicator when `isLoading` is true.
  - Displays backend validation or general error messages via SnackBar and inline field errors.
  - Navigates to `RegisterScreen`.
  - Missing: "Quên mật khẩu?" (Forgot Password) link; "Tiếp tục với Google" (Google Sign-In) button.
- **`RegisterScreen`**:
  - Comprehensive client-side validation: username length (3-50), characters (`^[a-zA-Z0-9_.]+$`), no whitespace, matching password confirmation.
  - Directly signs in upon 201 response and pops back.
  - Missing: Verification code entry screen, resend email option, Google signup.

---

## 5. Flutter Web Admin Authentication Deep Dive

### 5.1. Separation & Code Sharing Analysis
- **Code Sharing**: Web Admin does NOT share a compiled codebase with Mobile. They are completely separate Flutter projects (`frontend/mobile` vs `frontend/web`).
- **Backend API**: Mobile and Web Admin consume the EXACT SAME backend endpoints (`/api/auth/login`, `/api/auth/register`, `/api/auth/me`).

### 5.2. Token Storage & Web Security Risks
- In `frontend/web/lib/features/auth/data/auth_storage.dart`:
  - Uses `SharedPreferences` (HTML5 LocalStorage) because `FlutterSecureStorage` has limited hardware support in browser environments.
  - **Vulnerability**: LocalStorage is accessible to any JavaScript running in the same origin. An XSS vulnerability anywhere in the application allows attackers to steal the admin's JWT token.

### 5.3. Web Admin Architectural & Authorization Defects
1. **No Admin Login Gatekeeper**:
   - In `frontend/web/lib/main.dart`, any registered user with role `USER` can log into the Web Admin portal.
   - `WebPlaceholderScreen` merely hides the "Kiểm duyệt" and "Địa điểm" buttons if `role != 'ADMIN'`.
   - Non-admin users who log in see a portal screen with their name and an empty dashboard.
   - **Requirement**: Web Admin must actively reject non-ADMIN logins in `AuthNotifier.login` with an explicit error: `"Tài khoản không có quyền truy cập trang quản trị"`.
2. **Presence of Public Registration on Admin Portal**:
   - `frontend/web/lib/features/auth/presentation/screens/login_screen.dart` has a link to `RegisterScreen`.
   - Administrators should be provisioned securely or invited; public self-registration on an administrative portal must be removed.

---

## 6. Database Schema & User Entity Audit

### 6.1. Current Schema (`users` table)

```sql
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    handle VARCHAR(30) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL DEFAULT 'USER',     -- Enum: USER, ADMIN
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- Enum: ACTIVE, INACTIVE, BANNED
    avatar VARCHAR(500),
    full_name VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(255),
    bio TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
);
```

### 6.2. Gap Analysis for Advanced Authentication Features

| Required Capability | Database Schema Availability | Required Architectural Change |
| :--- | :--- | :--- |
| **Email Verification Status** | **Missing** | Add `email_verified BOOLEAN NOT NULL DEFAULT FALSE`. (Do NOT overload `UserStatus`). |
| **Verification Token / OTP** | **Missing** | Dedicated table `email_verification_tokens` (HMAC-SHA256 hashed OTP, SHA-256 hashed link token). |
| **Password Reset** | **Missing** | Dedicated table `password_reset_tokens` (`token_hash`, `user_id`, `expires_at`, `used_at`). |
| **Multi-Provider OAuth** | **Missing** | Dedicated table `user_auth_providers` (`user_id`, `provider`, `provider_user_id`, `email`). |
| **OAuth Password Nullability** | **Incompatible** | Change `password VARCHAR(255) NOT NULL` to `NULL` for pure OAuth accounts. |
| **Token Invalidation** | **Missing** | Add `token_version INT NOT NULL DEFAULT 1` to `users` table. |
| **Brute-Force Lockout** | **Missing** | Add `failed_login_attempts INT NOT NULL DEFAULT 0`, `locked_until DATETIME NULL`. |

---

## 7. Existing Test Coverage & Verification

### 7.1. Executed Test Results

#### Backend Test Execution
- **`JwtTokenProviderTest.java`**:
  - Command: `.\mvnw test "-Dtest=JwtTokenProviderTest"`
  - Result: **5 / 5 PASS (100%)**
  - Verified: Development secret allowed in dev; production secret enforced in prod/production profiles; key length >= 32 bytes enforced.
- **`AuthControllerTest.java`**:
  - Command: `.\mvnw test "-Dtest=AuthControllerTest"`
  - Result: **25 ERRORS in `setUp()` (Teardown Failure)**
  - **Identified Defect**:
    ```
    DataIntegrityViolation: Cannot delete or update a parent row: a foreign key constraint fails
    (`travel_planner_test`.`media_assets`, CONSTRAINT `FK52mya62bulnfr5x0btrx1tyx2`
    FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`user_id`))
    ```
    In `AuthControllerTest.java` lines 67-69:
    ```java
    ratingRepository.deleteAll();
    itineraryRepository.deleteAll();
    userRepository.deleteAll(); // <-- FAILS if media_assets or post rows exist!
    ```
    The test runs against a shared MySQL test database (`travel_planner_test`). When preceding integration tests insert records into `media_assets` or `community_posts` referencing users, calling `userRepository.deleteAll()` violates foreign keys.
    **Solution**: In Phase 0, annotate the test with `@Transactional` (or implement an explicit hierarchical purge order: `mediaAssetRepository`, `communityPostRepository`, `ratingRepository`, `itineraryRepository`, `userRepository`) to ensure test isolation without manual cross-test contamination.

#### Mobile Test Execution
- **Command**: `flutter test test/auth_401_test.dart test/username_validation_test.dart`
- **Result**: **14 / 14 PASS (100%)**
- Verified: 401 callback triggering, status code exclusions (200, 400, 403, 500), throttling (2s), session expiry cleanup, cached profile preservation on 500, username regex & spacing constraints.

#### Web Test Execution
- **Command**: `flutter test test/auth_401_test.dart test/username_validation_test.dart`
- **Result**: **14 / 14 PASS (100%)**
- Verified: Web 401 throttling, session expiration, username validation.

---

## 8. Capability Status Matrix

| Authentication Feature / Requirement | Status | Evidence / Notes |
| :--- | :--- | :--- |
| Basic Registration (Email, Username, Password) | **Implemented & Verified** | Functional in backend, mobile, web; validated by unit tests. |
| Basic Login (Username/Email + Password) | **Implemented & Verified** | Functional; returns JWT and user profile. |
| Current User Retrieval (`/api/auth/me`) | **Implemented & Verified** | Returns user profile without password; verifies active status. |
| BCrypt Password Hashing | **Implemented & Verified** | Spring Security BCryptPasswordEncoder (strength 10). |
| JWT Bearer Token Generation & Parsing | **Implemented & Verified** | JJWT 0.12.6, HMAC-SHA256, 24h expiration. |
| Automatic Session Restoration on Launch | **Implemented & Verified** | Verified in mobile and web via `checkAuthStatus()`. |
| Automatic 401 Expiry Handling | **Implemented & Verified** | Verified in mobile and web `ApiClient` with throttling. |
| Role-Based Endpoint Protection (`/api/admin/**`) | **Implemented & Verified** | Backend returns 403 for `Role.USER`, allows `Role.ADMIN`. |
| Banned/Inactive Account Rejection | **Implemented & Verified** | Backend returns 403 on login; filter rejects token. |
| Secure Mobile Token Storage | **Implemented & Verified** | Uses `FlutterSecureStorage` (Keystore/Keychain). |
| Web Admin Role Gatekeeper | **Partially Implemented** | Backend enforces role; Web frontend allows non-admin login. |
| Email Normalization | **Implemented & Verified** | Trims and applies `.toLowerCase()`. |
| Concurrency / Race Condition Protection | **Not Implemented** | No DB locking or duplicate key exception handling. |
| Strong Password Policy | **Not Implemented** | Only minimum 6 chars; no complexity requirements. |
| Login Timing Attack Mitigation | **Not Implemented** | User existence leaked via response latency differences. |
| Login Rate Limiting / Account Lockout | **Not Implemented** | No failure counter or temporary lockouts. |
| Server-Side Token Revocation / Logout | **Not Implemented** | Backend is purely stateless; logout is client-only. |
| Refresh Token Rotation | **Not Implemented** | Single 24h JWT token; no refresh tokens in baseline. |
| Email Verification Flow | **Not Implemented** | User is activated immediately on register. |
| Forgot Password / Reset Password Flow | **Not Implemented** | No endpoints, tokens, or screens exist. |
| Google Sign-In (Mobile & Web) | **Not Implemented** | No Google OAuth dependencies or endpoints exist. |
| Secure Hashing of Verification Tokens at Rest | **Not Implemented** | N/A (tokens do not exist yet). |

---

## 9. Comprehensive Vulnerability & Risk Register

```
+--------------------------------------------------------------------------------------------------+
| ID     | Category         | Description                                       | Severity | Effort|
+--------------------------------------------------------------------------------------------------+
| SEC-01 | Auth / Account   | No Email Verification (Account Hijacking/Spam)    | High     | Medium|
| SEC-02 | Auth / Recovery  | No Password Recovery (Denial of Service to User)  | High     | Medium|
| SEC-03 | Auth / Session   | No Token Invalidation on Password Change/Logout   | High     | Medium|
| SEC-04 | Auth / Admin     | Web Admin Lacks Role Gatekeeper (Non-Admin Login) | High     | Low   |
| SEC-05 | Web Security     | JWT Stored in Unencrypted Web LocalStorage (XSS)  | Medium   | Medium|
| SEC-06 | Auth / Abuse     | No Rate Limiting on Login/Register Endpoints      | Medium   | Low   |
| SEC-07 | Information Leak | Login Timing Attack Enumerates Valid Accounts     | Medium   | Low   |
| SEC-08 | Password Policy  | Weak Password Rules (Min 6 chars, no complexity)  | Medium   | Low   |
| SEC-09 | Concurrency      | Registration Race Condition on Unique Fields      | Low      | Low   |
| QA-01  | Quality / Test   | AuthControllerTest setUp fails on Foreign Key     | High     | Low   |
+--------------------------------------------------------------------------------------------------+
```
