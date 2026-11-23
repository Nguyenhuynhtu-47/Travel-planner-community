# BÁO CÁO ĐIỀU TRA VÀ KHẮC PHỤC LỖI HỒI QUY TRANG ĐĂNG NHẬP ADMIN WEB

**Dự án:** Travel Planner Community  
**Phân hệ:** Admin Web Portal (Flutter Web & Spring Boot Backend)  
**Tài liệu tham chiếu:** `docs/plan/16-admin-portal-ui-refactor-report.md`, `Travel_Planner_Function_Specification.md`, `AGENTS.md`  
**Ngày thực hiện:** 23/11/2026  
**Trạng thái Git:** Branch `feature/admin-moderation-integration` (Chưa commit, bảo toàn working tree)

---

## 1. TỔNG QUAN VẤN ĐỀ (EXECUTIVE SUMMARY)

Sau đợt refactor giao diện Admin Portal theo báo cáo `docs/plan/16-admin-portal-ui-refactor-report.md`, ghi nhận tình trạng khi người dùng truy cập hoặc thao tác đăng nhập bằng tài khoản quản trị `ADMIN`, giao diện Web phát sinh lỗi và không thể sử dụng bình thường.

Báo cáo này tài liệu hóa toàn bộ quá trình:
1. **Kiểm tra runtime trực tiếp:** Kết nối Chrome DevTools Protocol (CDP port 50587), theo dõi backend API (`http://localhost:8080`), database MySQL (`travel_planner.users`), DOM và console logs thực tế.
2. **Xác định nguyên nhân gốc rễ (Root Cause):** Khác biệt giữa giả định code và lỗi rendering thực tế trong Flutter rendering engine.
3. **Triển khai giải pháp dứt điểm:** Sửa lỗi layout constraint trong theme toàn cục, hoàn thiện dependency injection và các ràng buộc bảo mật RBAC.
4. **Kiểm thử tự động toàn diện:** Bổ sung test suite tích hợp `login_flow_integration_test.dart` (5 kịch bản hoàn chỉnh), kiểm tra 67/67 bài test và build production sạch.

---

## 2. QUÁ TRÌNH ĐIỀU TRA & TÁI HIỆN THỰC TẾ (RUNTIME DIAGNOSTICS)

Không dựa vào suy đoán mã nguồn, quy trình điều tra đã kết nối trực tiếp với các tiến trình đang chạy:

### 2.1. Kiểm tra Backend & Database
- **Backend Spring Boot:** Đang chạy tại PID 8212, lắng nghe tại `http://localhost:8080`.
  - Endpoint `GET /api/health` trả về `{"status":"UP","service":"travel-planner-backend"}` (HTTP 200 OK).
- **Cơ sở dữ liệu MySQL:**
  - Kiểm tra bảng `travel_planner.users`:
    - User ID 578: `username: admin`, `email: admin@gmail.com`, `role: ADMIN`, `status: ACTIVE`.
    - User ID 577: `username: minhdanh`, `email: md@gmail.com`, `role: USER`, `status: ACTIVE`.
  - Xác minh API `POST /api/auth/login`:
    - Đăng nhập `admin` / `<valid_password>`: Trả về HTTP 200 OK kèm Bearer JWT và đối tượng người dùng có `role: ADMIN`.
    - Đăng nhập `minhdanh` / `<valid_password>`: Trả về HTTP 200 OK kèm Bearer JWT có `role: USER`.
    - Đăng nhập sai mật khẩu: Trả về HTTP 401 Unauthorized (`"message": "Tên đăng nhập hoặc mật khẩu không chính xác"`).
  - Kết luận: **Backend và Database hoàn toàn khỏe mạnh, endpoint xác thực hoạt động đúng đặc tả.**

### 2.2. Kiểm tra Flutter Web qua Chrome DevTools Protocol (CDP)
- **Tiến trình:** Flutter Web dev server lắng nghe tại `http://localhost:63961`, Chrome chạy tại PID 4964 với `--remote-debugging-port=50587`.
- **Bắt ngoại lệ runtime:** Kết nối WebSocket CDP tới trang `Travel Planner Web Portal` và trích xuất lỗi console:
  ```
  ══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
  The following assertion was thrown during performLayout():
  BoxConstraints forces an infinite width.
  The offending constraints were:
    BoxConstraints(w=Infinity, 40.0<=h<=Infinity) / BoxConstraints(w=Infinity, 48.0<=h<=Infinity)
  ```
  Lỗi này kéo theo chuỗi crash liên hoàn tại:
  - `package:flutter/src/rendering/mouse_tracker.dart:199:12` (`hitTest` thất bại do `hasSize == false`).
  - `package:flutter/src/rendering/box.dart:2251:12`.
  - Toàn bộ cây widget bị dừng render, khiến màn hình bị treo / trắng trang.

---

## 3. NGUYÊN NHÂN GỐC RỄ (ROOT-CAUSE ANALYSIS)

### 3.1. Phân tích kỹ thuật sâu về `Size.fromHeight` trong Flutter
Trong file cấu hình theme `Travel_Planner/frontend/web/lib/core/theme/app_theme.dart`:
```dart
elevatedButtonTheme: ElevatedButtonThemeData(
  style: ButtonStyle(
    ...
    minimumSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(48)), // <--- OFFENDING CODE
  ),
),
outlinedButtonTheme: OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    ...
    minimumSize: const Size.fromHeight(48), // <--- OFFENDING CODE
  ),
),
```

**Cơ chế phát sinh lỗi:**
1. Trong Flutter SDK (`packages/flutter/lib/src/ui/geometry.dart`), constructor của `Size.fromHeight` được định nghĩa:
   ```dart
   const Size.fromHeight(double height) : super(double.infinity, height);
   ```
   Nghĩa là `Size.fromHeight(48)` thiết lập kích thước có **chiều rộng là vô hạn** (`width: double.infinity`) và chiều cao là `48.0`.
2. Khi đặt cấu hình này vào `elevatedButtonTheme` và `outlinedButtonTheme` toàn cục của ứng dụng, **mọi** nút `ElevatedButton` và `OutlinedButton` đều kế thừa thuộc tính `minimumSize = Size(double.infinity, 48.0)`.
3. Khi bất kỳ nút bấm nào được đặt bên trong một container không giới hạn chiều ngang (như bên trong `Row`, `Wrap`, `AppBar.actions`, v.v.), `Row` cung cấp cho child một khoảng đo `0.0 <= width <= double.infinity`.
4. Nút bấm cố gắng ép child bên trong nó phải rộng bằng `minimumSize.width` (`double.infinity`).
5. RenderBox của button tạo ra `BoxConstraints(w=Infinity, 48.0<=h<=Infinity)`.
6. Flutter rendering framework assert ngay lập tức:
   ```dart
   if (isAppliedConstraint) {
     if (minWidth.isInfinite) {
       throwError(ErrorSummary('BoxConstraints forces an infinite width.'));
     }
   }
   ```
7. Ngoại lệ layout ném ra làm vỡ cây render của trang.

### 3.2. Tại sao lỗi lại bộc lộ khi truy cập / đăng nhập Admin?
- Tại trang `LoginScreen`, nút `AppPrimaryButton` nằm bên trong `Column(crossAxisAlignment: CrossAxisAlignment.stretch)` của một `ConstrainedBox(maxWidth: 480)`. Tại đây `maxWidth` đã bị chặn ở 480px nên không kích hoạt assert.
- Tuy nhiên:
  - Khi người dùng đăng nhập tài khoản `ADMIN` thành công hoặc khi ứng dụng khởi động và khôi phục phiên đăng nhập hợp lệ từ LocalStorage, `main.dart` chuyển hướng sang `AdminShell`.
  - `AdminShell` mặc định mở tab `Dashboard` (`AdminDashboardScreen`).
  - Tại `AdminDashboardScreen` (dòng 202), header chào mừng chứa:
    ```dart
    Row(
      children: [
        Expanded(child: ...),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Làm mới'),
          onPressed: _loadDashboardData,
        ), // Nằm trong Row, kế thừa outlinedButtonTheme với Size.fromHeight(48)!
      ],
    )
    ```
  - Khi đó, `OutlinedButton.icon` ngay lập tức ném `BoxConstraints forces an infinite width`.
  - Vì Flutter Web chia sẻ ngữ cảnh và render ngay khi chuyển đổi trạng thái authentication, người dùng thấy trang bị lỗi ngay khi thực hiện đăng nhập hoặc khi mở trang mà token phiên cũ còn hiệu lực.

---

## 4. CÁC THAY ĐỔI ĐÃ THỰC HIỆN (CORRECTIVE ACTIONS)

### 4.1. Khắc phục cấu hình Theme toàn cục (`app_theme.dart`)
Thay thế toàn bộ `Size.fromHeight(48)` bằng kích thước nút chuẩn `Size(64, 48)`:
- `elevatedButtonTheme`: `minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 48))`
- `outlinedButtonTheme`: `minimumSize: const Size(64, 48)`

Kích thước này đảm bảo:
- Chiều cao tối thiểu vẫn đạt chuẩn 48px cho accessibility và trải nghiệm bấm phím.
- Chiều rộng tối thiểu là 64px (chuẩn Material), tự co giãn theo nội dung (icon + label) khi nằm trong `Row`, `Wrap`, hoặc `AppBar`.
- Khi cần nút full-width trong form (như tại Login/Register), widget tự động co giãn theo trục `CrossAxisAlignment.stretch` của `Column` hoặc qua `SizedBox(width: double.infinity)`.

### 4.2. Hoàn thiện Dependency Injection cho Testing (`admin_shell.dart` & `main.dart`)
- Bổ sung tham số tùy chọn `ApiClient? apiClient` vào `AdminShell` và `MyApp`.
- Giúp tách biệt hoàn toàn network client thực tế khi chạy ứng dụng và mock client khi chạy test suite, ngăn chặn triệt để lỗi rò rỉ network request trong môi trường kiểm thử tự động.

### 4.3. Xác minh bảo mật & Phân quyền RBAC (`auth_notifier.dart`)
- Xác nhận logic phân quyền tại `AuthNotifier.login()`:
  - Nếu tài khoản đăng nhập có `role != 'ADMIN'` (ví dụ `USER`), hệ thống chặn ngay lập tức, gán `_status = AuthStatus.error`, thông báo `"Tài khoản không có quyền truy cập trang quản trị"` và không lưu token vào storage.
  - Ngăn ngừa hoàn toàn việc người dùng thông thường truy cập trái phép vào các màn hình quản trị.

---

## 5. BỘ KIỂM THỬ TỰ ĐỘNG MỚI (`login_flow_integration_test.dart`)

Đã xây dựng test suite tích hợp hoàn chỉnh kiểm thử 5 kịch bản cốt lõi:

| # | Tên kịch bản | Mô tả kiểm thử | Kết quả |
|---|---|---|:---:|
| **1** | `Empty submission shows validation errors` | Bấm "Đăng nhập" khi chưa nhập dữ liệu -> Hiển thị lỗi form: *"Vui lòng nhập tên đăng nhập hoặc email"* và *"Vui lòng nhập mật khẩu"*. | **PASS** |
| **2** | `Invalid credentials show error SnackBar without crash` | Nhập sai mật khẩu -> Hiển thị SnackBar *"Tên đăng nhập hoặc mật khẩu không chính xác"*, không crash giao diện, giữ nguyên LoginScreen. | **PASS** |
| **3** | `ADMIN login transitions to AdminShell with active sidebar` | Nhập tài khoản `admin` / `<valid_password>` -> Đăng nhập thành công, chuyển hướng mượt mà sang `AdminShell`, hiển thị Dashboard, Sidebar `Travel Planner / Admin Portal` không còn bất kỳ lỗi rendering nào. | **PASS** |
| **4** | `Non-ADMIN user is rejected with permission error and remains unauthenticated` | Nhập tài khoản vai trò `USER` -> Bị từ chối quyền truy cập, hiển thị thông báo lỗi bảo mật, không lưu session. | **PASS** |
| **5** | `Session restore on app launch preserves authenticated ADMIN state` | Khởi động app khi có sẵn token ADMIN hợp lệ trong LocalStorage -> Tự động khôi phục phiên đăng nhập và hiển thị ngay `AdminShell`. | **PASS** |

---

## 6. KẾT QUẢ KIỂM TRA & XÁC MINH TOÀN HỆ THỐNG

### 6.1. Flutter Analyze (Static Analysis)
```powershell
Push-Location Travel_Planner/frontend/web; flutter analyze; Pop-Location
```
**Kết quả:**
```
Analyzing web...
No issues found! (ran in 4.6s)
```
*(0 lỗi, 0 cảnh báo, 0 lint issues)*

### 6.2. Toàn bộ Flutter Test Suite
```powershell
Push-Location Travel_Planner/frontend/web; flutter test; Pop-Location
```
**Kết quả:**
```
00:07 +66: D:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/test/widget_test.dart: Web LoginScreen renders portal title, inputs and buttons
00:07 +67: All tests passed!
```
*(67/67 bài test PASS 100%, bao gồm toàn bộ Moderation, Places, Layout, 401 Handling, Username Validation và Login Flow)*

### 6.3. Flutter Web Production Build
```powershell
Push-Location Travel_Planner/frontend/web; flutter build web --dart-define=API_BASE_URL=http://localhost:8080; Pop-Location
```
**Kết quả:**
```
Compiling lib\main.dart for the Web...                             60.6s
√ Built build\web
```
*(Build thành công, không phát sinh lỗi biên dịch hay tree-shaking)*

### 6.4. Trạng thái Backend
- `GET http://localhost:8080/api/health` -> HTTP 200 OK (`{"status":"UP","service":"travel-planner-backend"}`).
- Tiến trình Backend Spring Boot (PID 8212) vẫn hoạt động ổn định liên tục, không bị khởi động lại hay gián đoạn.

---

## 7. KẾT LUẬN & CAM KẾT GIT
- Vấn đề lỗi hồi quy khi đăng nhập và render Admin Portal đã được điều tra thực tế, xác định chính xác nguyên nhân gốc rễ và xử lý triệt để.
- Toàn bộ thiết kế Admin Shell, Sidebar có thể thu gọn, Dashboard số liệu thực tế, các màn hình Kiểm duyệt và Địa điểm từ Phase 1 và Phase B được bảo toàn 100%.
- Không thực hiện bất kỳ lệnh `git commit` hay `git push` nào theo đúng yêu cầu. Working tree được giữ nguyên vẹn để người dùng đánh giá và review.
