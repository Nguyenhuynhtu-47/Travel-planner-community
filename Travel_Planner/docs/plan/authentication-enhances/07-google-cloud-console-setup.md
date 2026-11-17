# HƯỚNG DẪN CẤU HÌNH GOOGLE CLOUD CONSOLE CHO GOOGLE SIGN-IN

Tài liệu này cung cấp các bước chi tiết để cấu hình dự án trên **Google Cloud Console**, cấp phát OAuth Client IDs cho Flutter Mobile (Android) và Spring Boot Backend của Travel Planner.

---

## 1. TỔNG QUAN KIẾN TRÚC OAUTH 2.0 / GOOGLE SIGN-IN

```
+----------------+      1. Google Sign-In Prompt     +---------------------+
| Flutter Mobile | --------------------------------> | Google Play Services|
| (Client App)   | <-------------------------------- | (OAuth Provider)    |
+----------------+      2. Raw Google ID Token       +---------------------+
       |
       | 3. POST /api/auth/google
       |    { "idToken": "<JWT>" }
       v
+-----------------------+
|  Spring Boot Backend  |
| (Resource & Auth Svc) |
+-----------------------+
       | 4. Cryptographic Signature & Claims Verification (iss, exp, aud, sub, email)
       | 5. UserIdentity & Account Conflict Anti-Hijacking Check
       v
+-----------------------+
|   Travel Planner DB   | -> 6. Issues Travel Planner JWT
+-----------------------+
```

---

## 2. CÁC BƯỚC CẤU HÌNH TRÊN GOOGLE CLOUD CONSOLE

### Bước 2.1: Tạo mới hoặc Chọn Project
1. Truy cập [Google Cloud Console](https://console.cloud.google.com/).
2. Đăng nhập bằng tài khoản Google quản trị.
3. Nhấp vào menu chọn dự án ở thanh tiêu đề (Top Bar) -> Chọn **New Project**.
4. Đặt tên: `Travel-Planner-Auth` (hoặc tên dự án tùy chọn) -> Nhấp **Create**.

---

### Bước 2.2: Cấu hình Màn hình Chấp thuận OAuth (OAuth Consent Screen)
1. Ở thanh menu bên trái, vào **APIs & Services** -> **OAuth consent screen**.
2. Chọn loại người dùng (**User Type**):
   - Chọn **External** (cho phép bất kỳ tài khoản Google nào đăng nhập).
   - Nhấp **Create**.
3. Điền thông tin ứng dụng:
   - **App name**: `Travel Planner`
   - **User support email**: Email của bạn.
   - **Developer contact information**: Email của bạn.
   - Nhấp **Save and Continue**.
4. Cấu hình Scopes (Phạm vi truy cập):
   - Nhấp **Add or Remove Scopes**.
   - Tích chọn:
     - `.../auth/userinfo.email` (Xem địa chỉ email chính)
     - `.../auth/userinfo.profile` (Xem thông tin cá nhân cơ bản)
     - `openid` (Xác thực OpenID Connect)
   - Nhấp **Update** -> Nhấp **Save and Continue**.
5. Test Users (Người dùng thử nghiệm):
   - Khi ứng dụng đang ở chế độ *Testing*, chỉ các email được liệt kê ở đây mới đăng nhập được.
   - Nhấp **Add Users** -> Nhập email cá nhân/email dùng để test đăng nhập trên thiết bị thật.
   - Nhấp **Save and Continue** -> **Back to Dashboard**.

---

### Bước 2.3: Tạo Web Application Client ID (Server Client ID)
> **Lưu ý quan trọng**: Client ID loại **Web application** là bắt buộc để Backend Spring Boot xác minh tính hợp lệ của trường `aud` (Audience) và dùng làm `serverClientId` cho Flutter.

1. Vào **APIs & Services** -> **Credentials**.
2. Nhấp **Create Credentials** -> Chọn **OAuth client ID**.
3. Chọn **Application type**: **Web application**.
4. Đặt tên: `Travel Planner Backend & Server Client`.
5. Authorized JavaScript origins / redirect URIs:
   - Có thể để trống hoặc thêm `http://localhost:8080` nếu cần.
6. Nhấp **Create**.
7. Lưu lại giá trị:
   - **Client ID**: dạng `xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com`
   - Đây chính là `GOOGLE_SERVER_CLIENT_ID`.

---

### Bước 2.4: Tạo Android Client ID
1. Tiếp tục tại trang **Credentials**, nhấp **Create Credentials** -> Chọn **OAuth client ID**.
2. Chọn **Application type**: **Android**.
3. Đặt tên: `Travel Planner Android Mobile`.
4. **Package name**: Nhập chính xác package name trong `android/app/build.gradle.kts`:
   ```
   com.example.mobile
   ```
5. **SHA-1 certificate fingerprint**:
   - Lấy mã vân tay SHA-1 của debug keystore trên máy phát triển:
   
   **Cách 1: Chạy lệnh `keytool` (Khuyên dùng trên Windows):**
   ```powershell
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
   Tìm dòng `SHA1: XX:XX:XX:XX:...` và dán vào ô **SHA-1 certificate fingerprint**.

   **Cách 2: Chạy Gradle signingReport:**
   ```powershell
   cd Travel_Planner\frontend\mobile\android
   .\gradlew signingReport
   ```
   Tìm task `debug` và sao chép mã `SHA1`.

6. Nhấp **Create**.
7. Lưu lại giá trị **Android Client ID**.

---

## 3. CẤU HÌNH VÀO ỨNG DỤNG TRAVEL PLANNER

### 3.1. Cấu hình Backend Spring Boot
Backend sử dụng thư viện Google API Client để xác minh ID Token.
Các giá trị Client ID được cấu hình qua file `application.properties` hoặc biến môi trường:

**Cấu hình trong `backend/src/main/resources/application.properties`:**
```properties
# Google OAuth2 Client Configuration
app.google.client-ids=${GOOGLE_CLIENT_IDS:}
app.google.android-client-id=${GOOGLE_ANDROID_CLIENT_ID:}
app.google.server-client-id=${GOOGLE_SERVER_CLIENT_ID:}
```

**Thiết lập biến môi trường khi chạy:**
```powershell
$env:GOOGLE_SERVER_CLIENT_ID="<YOUR_WEB_CLIENT_ID>.apps.googleusercontent.com"
$env:GOOGLE_ANDROID_CLIENT_ID="<YOUR_ANDROID_CLIENT_ID>.apps.googleusercontent.com"
$env:GOOGLE_CLIENT_IDS="$env:GOOGLE_SERVER_CLIENT_ID,$env:GOOGLE_ANDROID_CLIENT_ID"
```

> **Ghi chú**: Trong môi trường Local Development, nếu chưa cấu hình `GOOGLE_CLIENT_IDS`, Backend sẽ ghi log cảnh báo và chấp nhận mọi ID Token hợp lệ do Google ký để không chặn luồng dev/mock. Tuy nhiên, trên Production, bắt buộc phải cấu hình `GOOGLE_CLIENT_IDS` để ngăn chặn token giả mạo từ các app khác.

---

### 3.2. Cấu hình Mobile Flutter
1. SDK `google_sign_in: ^6.2.2` tự động tìm kiếm Android OAuth Client ID khớp với Package Name (`com.example.mobile`) và SHA-1 của máy chạy.
2. Nếu muốn nhận `idToken` ổn định trên Android, truyền `serverClientId` (chính là Web Application Client ID tạo ở Bước 2.3) vào constructor của `GoogleSignIn`:
   ```dart
   GoogleSignIn(
     serverClientId: '<YOUR_WEB_CLIENT_ID>.apps.googleusercontent.com',
     scopes: const ['email', 'profile'],
   );
   ```

---

## 4. XỬ LÝ SỰ CỐ THƯỜNG GẶP (TROUBLESHOOTING)

| Mã lỗi / Hiện tượng | Nguyên nhân | Cách khắc phục |
| :--- | :--- | :--- |
| **`ApiException: 10` (DEVELOPER_ERROR)** | Sai SHA-1 Fingerprint hoặc sai Package Name trên Google Cloud Console. | Chạy lại `keytool` để lấy chính xác SHA-1 của file `debug.keystore` và kiểm tra `applicationId = "com.example.mobile"` trong `build.gradle.kts`. |
| **`ApiException: 12500` (SIGN_IN_FAILED)** | Chưa cấu hình OAuth Consent Screen hoặc tài khoản đăng nhập chưa nằm trong danh sách **Test Users**. | Thêm email người thử nghiệm vào mục **Test Users** trong OAuth Consent Screen. |
| **`idToken == null`** | Chưa cung cấp `serverClientId` (Web Client ID) khi khởi tạo `GoogleSignIn`. | Thêm `serverClientId` bằng Web Application Client ID tạo từ Cloud Console. |
| **HTTP 409 Conflict** | Email của tài khoản Google trùng với tài khoản đã đăng ký mật khẩu cục bộ. | Đây là tính năng bảo vệ chống chiếm đoạt tài khoản (Anti-Hijacking). Người dùng cần đăng nhập bằng mật khẩu và liên kết trong cài đặt. |
