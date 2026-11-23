# Admin Auth Session Immediate Redirect Fix Report

**Date:** 2026-11-23  
**Status:** Resolved & Verified  
**Branch:** `feature/admin-moderation-integration`  

---

## 1. Executive Summary

When logging in to the Flutter Web Admin Portal with valid `ADMIN` credentials, the user briefly saw the Admin Portal interface for 1–2 seconds, but was then automatically redirected back to the `LoginScreen`. The session could not be maintained, and browser reloads cleared the session state.

This report documents the end-to-end diagnosis using Chrome DevTools Protocol (CDP) WebSocket inspection and backend network tracing, the root-cause identification in the global JWT revocation validation logic, the defensive hardening applied across backend security filters and user models, and the live browser test results confirming persistent session maintenance.

---

## 2. Root Cause Analysis

### 2.1 The Symptom Sequence
The incident exhibited the following sequence of events:
1. The user entered valid administrative credentials on `LoginScreen`.
2. `POST /api/auth/login` responded with HTTP 200 OK, returning an access token and user payload with `role: ADMIN`.
3. `AuthNotifier.login()` saved the token and user to browser `localStorage` and set `_status = AuthStatus.authenticated`.
4. `MyApp` transitioned from `LoginScreen` to `AdminShell`.
5. Upon mounting, `AdminShell` and `AdminDashboardScreen` initiated authenticated background requests:
   - `GET /api/admin/places?page=0&size=1`
   - `GET /api/admin/community/reports?status=PENDING&page=0&size=1`
   - `GET /api/admin/community/posts?page=0&size=5`
   - `GET /api/admin/media-assets?page=0&size=1`
6. Within 1–2 seconds, the web application reset its state and redirected back to `LoginScreen`.

### 2.2 Root Cause in Backend JWT Validation
Live diagnostic inspection of the JWT payload and database revealed:

1. **Pre-existing Database State:**
   - In MySQL table `travel_planner.users`, pre-existing rows (including User 578 `admin`) had column `token_version = 0`.
2. **Flawed Null-Check in Token Generation:**
   - In `JwtTokenProvider.java`:
     ```java
     .claim("tokenVersion", user.getTokenVersion() != null ? user.getTokenVersion() : 1);
     ```
   - Because `user.getTokenVersion()` returned `Integer.valueOf(0)`, the null check evaluated to `0 != null` (`true`).
   - Consequently, the issued token contained the claim `"tokenVersion": 0`.
3. **Strict Positive-Integer Assertion in Token Validation:**
   - When `JwtAuthenticationFilter` called `tokenProvider.validateToken(jwt)` on the incoming requests, `getTokenVersionFromToken(jwt)` was invoked:
     ```java
     long longVal = ((Number) versionObj).longValue();
     if (longVal <= 0) {
         throw new JwtException("Invalid tokenVersion claim value: " + longVal + ". Must be a positive integer.");
     }
     ```
   - Because `longVal == 0`, `getTokenVersionFromToken` threw a `JwtException`.
   - `validateToken()` caught this exception and returned `false`.
4. **401 Unauthorized & Client-side Cascade:**
   - With `validateToken()` returning `false`, `JwtAuthenticationFilter` skipped populating `SecurityContextHolder`.
   - Spring Security's `AuthenticationEntryPoint` rejected the request with `HTTP 401 Unauthorized`:
     ```json
     {
       "timestamp": "2026-11-22T18:51:56.315701500Z",
       "status": 401,
       "error": "Unauthorized",
       "message": "Yêu cầu xác thực: Token không hợp lệ hoặc đã hết hạn",
       "path": "/api/auth/me"
     }
     ```
   - In `frontend/web/lib/core/network/api_client.dart`:
     ```dart
     if (response.statusCode == 401) {
       _notifyUnauthorized();
     }
     ```
   - `_notifyUnauthorized()` triggered `ApiClient.globalOnUnauthorized` registered in `main.dart`:
     ```dart
     ApiClient.globalOnUnauthorized = () {
       _authNotifier.handleSessionExpired();
       _navigatorKey.currentState?.popUntil((route) => route.isFirst);
     };
     ```
   - `handleSessionExpired()` executed `logout()`, which executed `_storage.clear()` (deleting `localStorage`), cleared active state, and set `_status = AuthStatus.unauthenticated`.
   - `MyApp`'s `ListenableBuilder` immediately replaced `AdminShell` with `LoginScreen`.

---

## 3. Implementation & Hardening

### 3.1 Defensive Normalization in Backend Security (`> 0` guard)
To guarantee that tokens are always issued and validated with a strictly positive version regardless of legacy database anomalies:

1. **`JwtTokenProvider.java`:**
   Normalized claim generation to guarantee version >= 1:
   ```java
   int version = (user.getTokenVersion() != null && user.getTokenVersion() > 0) ? user.getTokenVersion() : 1;
   builder.claim("tokenVersion", version);
   ```
2. **`UserDetailsServiceImpl.java`:**
   Normalized `CustomUserDetails` creation:
   ```java
   int effectiveTokenVersion = (user.getTokenVersion() != null && user.getTokenVersion() > 0)
           ? user.getTokenVersion()
           : 1;
   return new CustomUserDetails(..., effectiveTokenVersion, ...);
   ```
3. **`JwtAuthenticationFilter.java`:**
   Normalized database version comparison:
   ```java
   int currentDbVersion = (customUser.getTokenVersion() != null && customUser.getTokenVersion() > 0)
           ? customUser.getTokenVersion()
           : 1;
   ```
4. **`User.java` Entity & Lifecycle:**
   - In entity constructor: `this.tokenVersion = (tokenVersion != null && tokenVersion > 0) ? tokenVersion : 1;`
   - In `@PrePersist onCreate()`:
     ```java
     if (this.tokenVersion == null || this.tokenVersion < 1) {
         this.tokenVersion = 1;
     }
     ```
5. **Database Normalization:**
   Normalized legacy records: `UPDATE travel_planner.users SET token_version = 1 WHERE token_version <= 0;`.

### 3.2 UI Minor Adjustment
In `frontend/web/lib/features/moderation/presentation/screens/admin_moderation_screen.dart`:
- Adjusted embedded top tab strip height from `Size.fromHeight(48)` to `Size.fromHeight(56)` to eliminate a 1px vertical render overflow on tabs containing both icons and text labels.

---

## 4. Verification & Testing

### 4.1 End-to-End Test Matrix
All 11 scenarios required by the specification were validated:

| # | Test Case Description | Method | Result | Notes |
|---|----------------------|--------|--------|-------|
| 1 | Open Web Admin unauthenticated | Chrome CDP | **PASS** | Renders `LoginScreen` cleanly; zero storage tokens. |
| 2 | Authenticate with valid `ADMIN` credentials | Chrome CDP | **PASS** | Valid JWT issued, stored to `localStorage`. |
| 3 | Confirm navigation to `AdminShell` | Chrome CDP | **PASS** | Mounts `AdminShell` and `AdminDashboardScreen`. |
| 4 | Wait 30+ seconds for session stability | Chrome CDP | **PASS** | Observed 30s live; zero 401s; session remained 100% active. |
| 5 | Navigate between sidebar tabs | Chrome CDP | **PASS** | Switched to "Quản lý báo cáo", "Kiểm duyệt", loaded live metrics. |
| 6 | Browser refresh (`window.location.reload()`) | Chrome CDP | **PASS** | `checkAuthStatus()` successfully restored session from `localStorage`. |
| 7 | Direct URL navigation | Chrome CDP | **PASS** | Preserved authenticated state without prompt. |
| 8 | Direct screen access | Chrome CDP | **PASS** | Preserved active module and role. |
| 9 | Click Logout action | Chrome CDP | **PASS** | Cleared `localStorage` and executed server logout. |
| 10 | Post-logout unauthenticated access | Chrome CDP | **PASS** | Redirected to `LoginScreen`; unable to access admin routes. |
| 11 | Non-admin (`ROLE_USER`) authentication | Flutter Test | **PASS** | Rejected at both `AuthNotifier` and `AdminShell` RBAC guards. |

### 4.2 Automated Test Execution
- **Backend Security & Auth Suites:**
  - Command: `mvn test -Dtest="JwtTokenProviderTest,AuthControllerTest,AuthSecurityUnitTest,AdminSeedIdempotencyTest"`
  - Result: **68 tests run, 0 failures, 0 errors (BUILD SUCCESS)**
- **Flutter Web Unit & Widget Suites:**
  - Command: `flutter test`
  - Result: **67 tests run, 0 failures (100% PASS)**
- **Flutter Static Analysis:**
  - Command: `flutter analyze`
  - Result: **No issues found! (0 warnings, 0 errors, 0 lints)**
- **Flutter Web Production Build:**
  - Command: `flutter build web --dart-define=API_BASE_URL=http://localhost:8080`
  - Result: **BUILD SUCCESS (`√ Built build\web`)**

---

## 5. Compliance & Git Status

- No git commits or pushes executed.
- Branch remained on `feature/admin-moderation-integration`.
- No database tables dropped; admin accounts and passwords strictly preserved.
- No confidential credentials recorded in source code, logs, or reports.
