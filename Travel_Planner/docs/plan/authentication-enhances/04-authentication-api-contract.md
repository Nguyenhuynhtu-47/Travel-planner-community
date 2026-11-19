# Authentication API Contract Specification (Refined)

**Document ID:** `docs/plan/04-authentication-api-contract.md`  
**System:** Travel Planner Community Platform  
**Target:** Spring Boot REST Backend, Flutter Mobile Client, Flutter Web Admin Client  
**Date:** 2026-11-17 (Refined)  
**Status:** Canonical Interface Specification

---

## 1. Overview & Standard Protocol Rules

### 1.1. Common Headers
- `Content-Type: application/json; charset=UTF-8` (All POST/PUT requests).
- `Accept: application/json`.
- `Authorization: Bearer <jwt_access_token>` (Mandatory for authenticated endpoints).

### 1.2. Spring Security `permitAll()` vs Authenticated Endpoints

| Endpoint | Method | Security Setting |
| :--- | :--- | :--- |
| `/api/auth/register` | `POST` | `permitAll()` (Existing) |
| `/api/auth/login` | `POST` | `permitAll()` (Existing) |
| `/api/auth/me` | `GET` | **Authenticated** (Existing Bearer JWT) |
| `/api/auth/verify-email` | `POST` | `permitAll()` (**NEW**) |
| `/api/auth/resend-verification` | `POST` | `permitAll()` (**NEW**) |
| `/api/auth/forgot-password` | `POST` | `permitAll()` (**NEW**) |
| `/api/auth/reset-password` | `POST` | `permitAll()` (**NEW**) |
| `/api/auth/google` | `POST` | `permitAll()` (**NEW**) |
| `/api/auth/change-password` | `POST` | **Authenticated** (Bearer JWT) |
| `/api/auth/providers/google/link` | `POST` | **Authenticated** (Bearer JWT) |
| `/api/auth/providers/google/unlink` | `POST` | **Authenticated** (Bearer JWT) |

### 1.3. Standard Error Response Format
All error responses conform to the established `ErrorResponse` schema:
```json
{
  "timestamp": "2026-11-17T09:30:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Dữ liệu gửi lên không hợp lệ",
  "path": "/api/auth/register",
  "validationErrors": {
    "email": "Email không đúng định dạng",
    "password": "Mật khẩu phải có tối thiểu 8 ký tự, bao gồm chữ hoa, chữ thường và chữ số"
  }
}
```

---

## 2. API Endpoint Matrix

| Method | Endpoint | Phase | Status | Auth Required | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/register` | Phase 0/1 | **Existing** (Enhanced) | None (Public) | User account registration |
| `POST` | `/api/auth/login` | Phase 0 | **Existing** | None (Public) | Standard credentials login |
| `GET` | `/api/auth/me` | Phase 0 | **Existing** | Bearer JWT | Current authenticated user profile |
| `POST` | `/api/auth/verify-email` | Phase 1 | **Proposed New** | None (Public) | Verify email using 6-digit OTP or link token |
| `POST` | `/api/auth/resend-verification` | Phase 1 | **Proposed New** | None (Public) | Request a new verification OTP code |
| `POST` | `/api/auth/forgot-password` | Phase 2 | **Proposed New** | None (Public) | Request password reset instructions |
| `POST` | `/api/auth/reset-password` | Phase 2 | **Proposed New** | None (Public) | Reset password with token/code |
| `POST` | `/api/auth/change-password` | Phase 2 | **Proposed New** | Bearer JWT | Change password for logged-in user |
| `POST` | `/api/auth/google` | Phase 3 | **Proposed New** | None (Public) | Sign in / register via Google ID Token |
| `POST` | `/api/auth/providers/google/link` | Phase 3 | **Proposed New** | Bearer JWT | Link Google account to logged-in user |
| `POST` | `/api/auth/providers/google/unlink` | Phase 3 | **Proposed New** | Bearer JWT | Unlink Google account from user |
| `POST` | `/api/auth/refresh` | Phase 4 | **Optional Future** | None (Public) | Rotate refresh token (Phase 4 only) |
| `POST` | `/api/auth/logout` | Phase 4 | **Optional Future** | Bearer / Refresh | Server-side token revocation (Phase 4 only) |

---

## 3. Existing Endpoints

### 3.1. `POST /api/auth/register` (Existing — Behavior Enhanced for Verification)

- **Authentication**: None (Public `permitAll()`).
- **Request Body (`RegisterRequest`)**:
```json
{
  "username": "traveler99",
  "handle": "traveler_99",
  "email": "traveler99@example.com",
  "password": "SecurePassword123!",
  "fullName": "Nguyen Van A"
}
```
- **Field Validation Rules**:
  - `username`: `@NotBlank`, `@Size(min = 3, max = 50)`, `@Pattern("^[a-zA-Z0-9_.]+$")`.
  - `handle`: Optional, `@Pattern("^$|^@?[a-zA-Z0-9_.]{3,30}$")`.
  - `email`: `@NotBlank`, `@Email`, `@Size(max = 100)`.
  - `password`: `@NotBlank`, `@Size(min = 8, max = 100)`, `@Pattern("^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).*$")`.
  - `fullName`: `@NotBlank`, `@Size(max = 100)`.

- **Success Response (Phase 1 Email Verification Active)**:
  - **Status Code**: `201 Created`
```json
{
  "message": "Đăng ký thành công. Vui lòng kiểm tra email để nhận mã xác thực.",
  "email": "traveler99@example.com",
  "requiresVerification": true
}
```
*(Notice: No JWT is returned until email verification succeeds!)*

- **Error Responses**:
  - `400 Bad Request`: Validation failure on input fields (`validationErrors` map included).
  - `409 Conflict`: Username or email already registered (`"Tên đăng nhập đã tồn tại"` or `"Email đã được sử dụng"`).
  - `429 Too Many Requests`: Rate limit exceeded (> 3 registrations per IP per 10 minutes).

---

### 3.2. `POST /api/auth/login` (Existing)

- **Authentication**: None (Public `permitAll()`).
- **Request Body (`LoginRequest`)**:
```json
{
  "usernameOrEmail": "traveler99",
  "password": "SecurePassword123!"
}
```
- **Field Validation Rules**:
  - `usernameOrEmail`: `@NotBlank(message = "Tên đăng nhập hoặc email không được để trống")`.
  - `password`: `@NotBlank(message = "Mật khẩu không được để trống")`.

- **Success Response (Preserving Current Contract Compatibility)**:
  - **Status Code**: `200 OK`
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "user": {
    "userId": 142,
    "username": "traveler99",
    "handle": "traveler_99",
    "email": "traveler99@example.com",
    "fullName": "Nguyen Van A",
    "role": "USER",
    "status": "ACTIVE",
    "avatar": "https://res.cloudinary.com/.../avatar.jpg",
    "phone": "0901234567",
    "address": "TP. Ho Chi Minh",
    "bio": "Yeu thich du lich tu tuc",
    "createdAt": "2026-11-17T09:15:00"
  }
}
```
*(Note: Refresh token is NOT included in Phases 0–3 to preserve exact client compatibility).*

- **Error Responses**:
  - `400 Bad Request`: Missing identifier or password.
  - `401 Unauthorized`: Invalid credentials (`"Tên đăng nhập hoặc mật khẩu không chính xác"`).
  - `403 Forbidden`: Account banned (`"Tài khoản của bạn đã bị khóa do vi phạm chính sách"`), account inactive, or unverified (`"Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email xác thực."`).
  - `429 Too Many Requests`: Account temporarily locked (5 failed attempts = 15m lockout) or rate limit exceeded (> 5 requests/min).

---

### 3.3. `GET /api/auth/me` (Existing)

- **Authentication**: Bearer JWT required (`Authorization: Bearer <token>`).
- **Request Body**: None.
- **Success Response**:
  - **Status Code**: `200 OK`
```json
{
  "userId": 142,
  "username": "traveler99",
  "handle": "traveler_99",
  "email": "traveler99@example.com",
  "fullName": "Nguyen Van A",
  "role": "USER",
  "status": "ACTIVE",
  "avatar": "https://res.cloudinary.com/.../avatar.jpg",
  "phone": "0901234567",
  "address": "TP. Ho Chi Minh",
  "bio": "Yeu thich du lich tu tuc",
  "createdAt": "2026-11-17T09:15:00"
}
```

- **Error Responses**:
  - `401 Unauthorized`: Token missing, expired, tampered, or invalidated by `token_version` mismatch.
  - `403 Forbidden`: Account banned or deactivated since token was issued.

---

## 4. Proposed New Endpoints

### 4.1. `POST /api/auth/verify-email` (Proposed New — Phase 1)

- **Authentication**: None (Public `permitAll()`).
- **Purpose**: Verifies traveler's email using the 6-digit OTP code (Mobile) or URL token (Web).
- **Request Body (`VerifyEmailRequest`)**:
```json
{
  "email": "traveler99@example.com",
  "code": "849201"
}
```
- **Validation Rules**:
  - `email`: `@NotBlank`, `@Email`.
  - `code`: `@NotBlank`, accepts 6-digit numeric OTP or URL-safe base64 token.

- **Success Response**:
  - **Status Code**: `200 OK`
  - **Payload**: Standard `AuthResponse` (`token`, `tokenType: "Bearer"`, `user`).

- **Error Responses**:
  - `400 Bad Request`: Code is invalid, expired, or has exceeded 5 failed attempts (`"Mã xác thực không chính xác hoặc đã hết hạn"`).
  - `409 Conflict`: Account already verified (`"Tài khoản này đã được xác thực trước đó"`).
  - `429 Too Many Requests`: Rate limit exceeded (> 10 attempts/min).

---

### 4.2. `POST /api/auth/resend-verification` (Proposed New — Phase 1)

- **Authentication**: None (Public `permitAll()`).
- **Purpose**: Generates and emails a new verification OTP code. Invalids any previous active OTPs.
- **Request Body (`ResendVerificationRequest`)**:
```json
{
  "email": "traveler99@example.com"
}
```
- **Validation Rules**:
  - `email`: `@NotBlank`, `@Email`.

- **Success Response (Anti-Enumeration Generic Response)**:
  - **Status Code**: `200 OK`
```json
{
  "message": "Nếu email tồn tại và chưa xác thực, mã xác thực mới đã được gửi.",
  "cooldownSeconds": 60
}
```
*(Always returns 200 OK. Never returns 404 or reveals whether the email exists).*

- **Error Responses**:
  - `400 Bad Request`: Malformed email syntax.
  - `429 Too Many Requests`: Resend requested within the 60-second cooldown window or exceeds 3 resends/hour.

---

### 4.3. `POST /api/auth/forgot-password` (Proposed New — Phase 2)

- **Authentication**: None (Public `permitAll()`).
- **Purpose**: Initiates password recovery. Dispatches reset link/code without revealing account existence.
- **Request Body (`ForgotPasswordRequest`)**:
```json
{
  "email": "traveler99@example.com"
}
```
- **Validation Rules**:
  - `email`: `@NotBlank`, `@Email`.

- **Success Response (Anti-Enumeration Generic Response)**:
  - **Status Code**: `200 OK`
```json
{
  "message": "Nếu địa chỉ email tồn tại trên hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi đến hộp thư của bạn."
}
```

- **Error Responses**:
  - `400 Bad Request`: Malformed email format.
  - `429 Too Many Requests`: Rate limit exceeded (> 3 requests per 15 minutes).

---

### 4.4. `POST /api/auth/reset-password` (Proposed New — Phase 2)

- **Authentication**: None (Public `permitAll()`).
- **Purpose**: Sets a new password using a valid reset token/code. Increments `token_version` to invalidate existing sessions.
- **Request Body (`ResetPasswordRequest`)**:
```json
{
  "email": "traveler99@example.com",
  "token": "a1b2c3d4e5f6...",
  "newPassword": "NewSecurePassword456!"
}
```
- **Validation Rules**:
  - `email`: `@NotBlank`, `@Email`.
  - `token`: `@NotBlank`.
  - `newPassword`: `@NotBlank`, `@Size(min = 8, max = 100)`, `@Pattern("^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).*$")`.

- **Success Response**:
  - **Status Code**: `200 OK`
```json
{
  "message": "Mật khẩu đã được đặt lại thành công. Vui lòng đăng nhập bằng mật khẩu mới."
}
```

- **Error Responses**:
  - `400 Bad Request`: Invalid or expired reset token (`"Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn"`), or password fails complexity criteria.
  - `429 Too Many Requests`: Exceeded 5 reset attempts per 15 minutes.

---

### 4.5. `POST /api/auth/change-password` (Proposed New — Phase 2)

- **Authentication**: Bearer JWT required.
- **Purpose**: Authenticated user changes their password. Increments `token_version` to logout other sessions.
- **Request Body (`ChangePasswordRequest`)**:
```json
{
  "currentPassword": "OldPassword123!",
  "newPassword": "NewPassword456!"
}
```
- **Validation Rules**:
  - `currentPassword`: `@NotBlank`.
  - `newPassword`: `@NotBlank`, `@Size(min = 8, max = 100)`. Must not equal `currentPassword`.

- **Success Response**:
  - **Status Code**: `200 OK`
```json
{
  "message": "Mật khẩu đã được thay đổi thành công. Các phiên đăng nhập trên thiết bị khác đã được đăng xuất."
}
```

- **Error Responses**:
  - `400 Bad Request`: New password does not meet complexity rules or matches current password.
  - `401 Unauthorized`: Current password incorrect or JWT invalid.

---

### 4.6. `POST /api/auth/google` (Proposed New — Phase 3)

- **Authentication**: None (Public `permitAll()`).
- **Purpose**: Authenticates user using Google OpenID Connect ID Token.
- **Request Body (`GoogleLoginRequest`)**:
```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjFhMmIzYy..."
}
```
- **Validation Rules**:
  - `idToken`: `@NotBlank(message = "Google ID Token không được để trống")`.

- **Success Response**:
  - **Status Code**: `200 OK`
  - **Payload**: Standard `AuthResponse` (`token`, `tokenType: "Bearer"`, `user`).

- **Error Responses**:
  - `400 Bad Request`: Missing ID token.
  - `401 Unauthorized`: ID token signature invalid, expired, wrong issuer, or unverified email in Google account (`"Google ID Token không hợp lệ hoặc đã hết hạn"`).
  - `403 Forbidden`: Corresponding account is BANNED or INACTIVE.
  - `429 Too Many Requests`: Rate limit exceeded (> 10 requests/min).

---

### 4.7. `POST /api/auth/providers/google/link` (Proposed New — Phase 3)

- **Authentication**: Bearer JWT required.
- **Purpose**: Links a Google identity to an existing authenticated user account.
- **Request Body (`GoogleLinkRequest`)**:
```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjFhMmIzYy..."
}
```
- **Success Response**:
  - **Status Code**: `200 OK`
```json
{
  "message": "Liên kết tài khoản Google thành công"
}
```
- **Error Responses**:
  - `400 Bad Request`: Invalid Google token.
  - `401 Unauthorized`: Missing or invalid JWT.
  - `409 Conflict`: Google account is already linked to another user (`"Tài khoản Google này đã được liên kết với một tài khoản khác"`).

---

### 4.8. `POST /api/auth/providers/google/unlink` (Proposed New — Phase 3)

- **Authentication**: Bearer JWT required.
- **Purpose**: Unlinks Google identity from the authenticated user.
- **Request Body**: None (or empty JSON `{}`).
- **Success Response**:
  - **Status Code**: `200 OK`
```json
{
  "message": "Hủy liên kết tài khoản Google thành công"
}
```
- **Error Responses**:
  - `400 Bad Request`: Unlinking rejected because Google is the sole login method and no local password is set (`"Bạn cần thiết lập mật khẩu trước khi hủy liên kết tài khoản Google để tránh mất quyền truy cập tài khoản"`).
  - `401 Unauthorized`: Missing or invalid JWT.

---

## 5. Optional Phase 4 Endpoints (Session Management & Refresh Rotation)

*Note: These endpoints are documented for architectural completeness under Phase 4 and are NOT active in Phases 0–3.*

### 5.1. `POST /api/auth/refresh` (Phase 4 Optional)
- **Request**: `{ "refreshToken": "d8e8fca2-8419-4bfe-98d9-299f05a96a32..." }`.
- **Response**: `200 OK` with `{ "token": "...", "refreshToken": "...", "tokenType": "Bearer" }`.
- **Errors**: `401 Unauthorized` if refresh token is expired, revoked, or reused (replay detection).

### 5.2. `POST /api/auth/logout` (Phase 4 Optional)
- **Request**: `{ "refreshToken": "..." }`.
- **Response**: `200 OK` with `{ "message": "Đăng xuất thành công" }`.
- **Errors**: `400 Bad Request`.
