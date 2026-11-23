# BÁO CÁO AUDIT TOÀN DIỆN PHÂN HỆ ADMIN (TRAVEL PLANNER WEB & BACKEND)
**Tài liệu tham chiếu:** `docs/plan/14-admin-module-implementation-audit.md`  
**Ngày thực hiện:** 22/11/2026  
**Phạm vi audit:** Spring Boot Backend (`backend`), Flutter Web Admin (`frontend/web`), MySQL Database (`travel_planner`), Tài liệu đặc tả (`Travel_Planner_Function_Specification.md`, `docs/ai/`)

---

## I. Executive Summary

Phân hệ Admin của dự án Travel Planner hiện đang ở trạng thái **triển khai bán phần (partially implemented)**, tập trung chủ yếu vào module Quản lý Địa điểm chuẩn hóa (Places Management) và khung xác thực phân quyền Role-Based Access Control (RBAC).

### 1. Những chức năng đã hoàn thành nổi bật
- **Xác thực & Kiểm soát phân quyền (Auth & RBAC):** Hoàn chỉnh và an toàn ở cả hai đầu. Backend bảo vệ nghiêm ngặt toàn bộ tiền tố `/api/admin/**` với `hasRole('ADMIN')` qua Spring Security và `@PreAuthorize`. Flutter Web Admin có bộ lọc vai trò (`auth_notifier.dart`) từ chối đăng nhập và xóa sạch token nếu người dùng mang vai trò `USER`.
- **Quản lý Địa điểm Chuẩn hóa (Places Management):** Hoàn thiện 100% cả Backend (`AdminPlaceController`) và Frontend Web (`AdminPlacesScreen`). Hỗ trợ đầy đủ CRUD, tìm kiếm với bộ điều tiết debounce, lọc theo danh mục chuẩn `PlaceCategory`, lọc trạng thái (`ACTIVE`, `HIDDEN`), xem chi tiết và định vị trực quan trên bản đồ Leaflet (`WebMapView`). Đã được xác minh qua 20 unit/widget tests.
- **Hồ sơ Quản trị viên (Admin Profile):** Hoàn thiện kết nối Backend (`/api/user/profile`) và giao diện Web (`ProfileScreen`).

### 2. Những phần còn thiếu và rủi ro quan trọng
- **Lệch khớp hợp đồng API Kiểm duyệt Cộng đồng (Moderation API Contract Mismatch - CRITICAL):** Module Kiểm duyệt bài viết và báo cáo vi phạm (`AdminModerationScreen`) đã được lập trình giao diện rất chi tiết (711 dòng code, 3 tab), nhưng đang bị **mất kết nối hoàn toàn ở runtime** do sai lệch URL endpoint và cấu trúc tham số giữa Flutter Web và Spring Boot (`PATCH /api/admin/community/posts/{id}` vs `/api/admin/community/posts/{id}/moderate`; `PATCH /api/admin/community/reports/{id}` body vs `@RequestParam resolution`; `/api/admin/community/media-assets` vs `/api/admin/media-assets`). Toàn bộ 11 test của module này trên Web đều dùng `MockClient` mô phỏng URL sai nên test pass nhưng gọi thật sẽ lỗi 404/405.
- **Tính năng Backend chưa có giao diện (Backend Only):** Phân hệ liên kết đơn vị hành chính và xử lý địa danh (`AdminPlaceAdministrativeAreaController` với preview resolution, auto-resolve, manual link, batch resolve) đã chạy tốt ở backend nhưng Flutter Web hoàn toàn chưa có giao diện để thao tác.
- **Các phân hệ cốt lõi chưa triển khai (Not Started):**
  - **Dashboard & Thống kê:** Chưa có API backend (`/api/admin/stats`), Web chỉ có màn hình placeholder (`WebPlaceholderScreen`). Thư mục `features/dashboard/` chỉ có `.gitkeep`.
  - **Quản lý người dùng (User Management):** Chưa có API danh sách, tìm kiếm, khóa/mở khóa tài khoản admin. Thư mục `features/users/` chỉ có `.gitkeep`.
  - **Quản lý lịch trình (Itinerary Management):** Backend chưa có API duyệt/ẩn/xóa lịch trình cho Admin. Thư mục `features/itineraries/` chỉ có `.gitkeep`.
  - **Quản lý thông báo (Notifications):** Chưa có backend entity/API và giao diện Web. Thư mục `features/notifications/` chỉ có `.gitkeep`.
- **Kiến trúc giao diện Web Admin chưa có Shell/Sidebar:** Web Admin hiện không có thanh điều hướng Sidebar/Drawer chuẩn mực, mà chuyển trang rời rạc qua `Navigator.push`.

### 3. Đánh giá mức độ sẵn sàng của Admin Web
- **Mức độ sẵn sàng tổng thể:** **Chưa sẵn sàng đưa vào vận hành thực tế (Not Production Ready)**.
- Hiện tại, chỉ có duy nhất tính năng Quản lý Địa điểm (`AdminPlacesScreen`) có thể hoạt động end-to-end với Backend. Quản trị viên chưa thể quản lý người dùng, xem thống kê, hay kiểm duyệt bài viết trên môi trường chạy thật.

---

## II. Admin Architecture

```
                    +-------------------------------------------------------+
                    |                   FLUTTER WEB ADMIN                   |
                    |                   (frontend/web)                      |
                    +-------------------------------------------------------+
                    |  - WebPlaceholderScreen (Temporary Home Shell)        |
                    |  - AdminPlacesScreen (Places CRUD + WebMapView)       |
                    |  - AdminModerationScreen (Posts, Reports, Media UI)   |
                    |  - ProfileScreen (Admin Personal Profile)             |
                    |  - AuthNotifier & Storage (LocalStorage token)        |
                    +-------------------------------------------------------+
                                                |
                                                | HTTP REST / JSON
                                                | Authorization: Bearer <JWT>
                                                v
                    +-------------------------------------------------------+
                    |                  SPRING BOOT BACKEND                  |
                    |             (Travel_Planner / backend)                |
                    +-------------------------------------------------------+
                    |  Security Layer:                                      |
                    |  - SecurityConfig (.requestMatchers("/api/admin/**")  |
                    |    .hasRole("ADMIN"))                                 |
                    |  - JwtAuthenticationFilter (Token & Session Validate) |
                    |                                                       |
                    |  Admin Controllers:                                   |
                    |  - AdminPlaceController (/api/admin/places)           |
                    |  - AdminPlaceAdministrativeAreaController             |
                    |    (/api/admin/places/{id}/administrative-area/**)    |
                    |  - AdminCommunityController (/api/admin)              |
                    |                                                       |
                    |  Services & Logic:                                    |
                    |  - PlaceServiceImpl / PlaceAdministrativeAreaService  |
                    |  - PostServiceImpl (Moderate, Purge, Resolve, Retry)  |
                    |  - CommentServiceImpl (Admin soft-delete override)    |
                    +-------------------------------------------------------+
                                                |
                                                | JPA / Hibernate
                                                v
                    +-------------------------------------------------------+
                    |                    MYSQL DATABASE                     |
                    |                   (travel_planner)                    |
                    +-------------------------------------------------------+
                    |  - users (role: ADMIN / USER; status: ACTIVE/BANNED)  |
                    |  - places (status: ACTIVE / HIDDEN; administrative_id)|
                    |  - administrative_areas (3,355 official units)        |
                    |  - posts (status, moderated_at, moderated_by, reason) |
                    |  - post_reports (status: PENDING/RESOLVED/DISMISSED)  |
                    |  - media_assets (status, retry_count, dead_lettered)  |
                    |  - comments & post_comments (status: ACTIVE/DELETED)  |
                    +-------------------------------------------------------+
```

### Luồng giao tiếp và Phân quyền
1. **Đăng nhập Web:** Người dùng gửi thông tin tới `POST /api/auth/login`. Nếu thành công, `AuthNotifier` đọc claim `role`. Nếu `role != 'ADMIN'`, `AuthNotifier` lập tức hủy token, xóa storage và chặn truy cập.
2. **Xác thực API:** Mọi request gửi tới `/api/admin/**` đều kèm header `Authorization: Bearer <token>`. `JwtAuthenticationFilter` giải mã token, kiểm tra phiên hoạt động trong `user_sessions`, gán quyền `ROLE_ADMIN` vào `SecurityContext`.
3. **Bảo vệ tầng sâu:** Spring Security tự động từ chối (HTTP 403 Forbidden) nếu request không có `ROLE_ADMIN`. Ngoài ra, các service (như `PostServiceImpl`) kiểm tra thêm `admin.getRole() == Role.ADMIN` trước khi ghi dữ liệu.

---

## III. Admin Feature Inventory

| STT | Nhóm chức năng | Tên chức năng cụ thể | Backend API | Flutter Web UI | Kiểm thử (Tests) | Trạng thái | Ghi chú |
|:---:|---|---|---|---|---|:---:|---|
| **1** | **Xác thực & Bảo mật** | Đăng nhập Admin | `POST /api/auth/login` | `LoginScreen` | Web (PASS) + Backend (PASS) | **COMPLETED** | Chặn vai trò USER ở cả 2 đầu |
| | | Đăng xuất máy chủ | `POST /api/auth/logout` | `AuthNotifier.logout()` | Web (PASS) + Backend (PASS) | **COMPLETED** | Thu hồi phiên trên database |
| | | Bảo vệ API quyền Admin | `SecurityConfig` (`hasRole('ADMIN')`) | `_isPublicAuthPath` / Gatekeeper | Backend 403 integration tests | **COMPLETED** | Backend là nguồn chân lý tối thượng |
| **2** | **Quản lý Địa điểm** | Xem danh sách địa điểm chuẩn hóa | `GET /api/admin/places` | `AdminPlacesScreen` | 20 Web tests + Backend tests | **COMPLETED** | Lọc theo danh mục, trạng thái, phân trang |
| | | Xem chi tiết địa điểm | `GET /api/admin/places/{id}` | `AdminPlacesScreen` (detail panel) | Web tests (PASS) | **COMPLETED** | Hiển thị tọa độ, địa chỉ, ảnh bìa |
| | | Thêm mới địa điểm | `POST /api/admin/places` | `PlaceFormDialog` | Web tests (PASS) | **COMPLETED** | Tạo địa điểm chuẩn hóa vào DB |
| | | Chỉnh sửa địa điểm | `PUT /api/admin/places/{id}` | `PlaceFormDialog` | Web tests (PASS) | **COMPLETED** | Cập nhật thông tin, tọa độ |
| | | Ẩn / Xóa mềm địa điểm | `DELETE /api/admin/places/{id}` | `HidePlaceDialog` | Web tests (PASS) | **COMPLETED** | Chuyển trạng thái sang `HIDDEN` |
| | | Hiển thị bản đồ Leaflet | Không cần API riêng (Client Map) | `WebMapView` (CARTO Voyager) | Map smoke test (PASS) | **COMPLETED** | Xem vị trí ghim trực quan |
| **3** | **Dữ liệu Địa giới** | Xem trước liên kết địa giới (Preview) | `POST /api/admin/places/{id}/administrative-area/preview` | Chưa có | Backend tests (PASS) | **BACKEND ONLY** | Chưa có UI trên Web |
| | | Tự động phân giải & gán mã (Resolve) | `POST /api/admin/places/{id}/administrative-area/resolve` | Chưa có | Backend tests (PASS) | **BACKEND ONLY** | Chưa có UI trên Web |
| | | Gán thủ công mã hành chính (Manual Link) | `POST /api/admin/places/{id}/administrative-area/link` | Chưa có | Backend tests (PASS) | **BACKEND ONLY** | Có kiểm tra vùng cách ly Resolution 388 |
| | | Hủy gán địa giới (Unlink) | `DELETE /api/admin/places/{id}/administrative-area` | Chưa có | Backend tests (PASS) | **BACKEND ONLY** | Chưa có UI trên Web |
| | | Xử lý hàng loạt địa giới (Batch Resolve) | `POST /api/admin/places/administrative-area/batch-resolve` | Chưa có | Backend tests (PASS) | **BACKEND ONLY** | Chưa có UI trên Web |
| **4** | **Kiểm duyệt Bài viết** | Lấy danh sách bài viết quản trị | `GET /api/admin/community/posts` | `AdminModerationScreen` (Tab 1) | Web MockClient (PASS) | **COMPLETED** | Phân trang, lọc theo status |
| | | Đổi trạng thái bài viết (Moderate Post) | `PATCH /api/admin/community/posts/{id}/moderate` | `AdminModerationScreen` | Web MockClient (PASS) | **BROKEN** | Lệch URL (`/posts/{id}`) và tên trường (`reason` vs `moderationReason`) |
| | | Xóa vĩnh viễn bài viết (Purge Post) | `DELETE /api/admin/community/posts/{id}/purge` | `AdminModerationScreen` | Web MockClient (PASS) | **COMPLETED** | Khớp URL endpoint `/purge` |
| **5** | **Xử lý Báo cáo** | Lấy danh sách báo cáo vi phạm | `GET /api/admin/community/reports` | `AdminModerationScreen` (Tab 2) | Web MockClient (PASS) | **COMPLETED** | Lọc theo status (PENDING, RESOLVED...) |
| | | Xử lý báo cáo (Resolve Report) | `PATCH /api/admin/community/reports/{id}/resolve` | `AdminModerationScreen` | Web MockClient (PASS) | **BROKEN** | Lệch cấu trúc: Web gửi PATCH body, Backend nhận `@RequestParam resolution` |
| **6** | **Dọn dẹp Phương tiện** | Danh sách tệp phương tiện rác/lỗi | `GET /api/admin/media-assets` | `AdminModerationScreen` (Tab 3) | Web MockClient (PASS) | **BROKEN** | Lệch URL: Web gọi `/api/admin/community/media-assets` (thừa `community`) |
| | | Thử lại xóa tệp Cloudinary (Retry) | `POST /api/admin/media-assets/{id}/retry` | `AdminModerationScreen` | Web MockClient (PASS) | **BROKEN** | Lệch URL tương tự như trên |
| **7** | **Quản lý Bình luận** | Xóa mềm bình luận lịch trình/hoạt động | `DELETE /api/comments/{id}` (quyền Admin) | Chưa có | Backend tests (PASS) | **PARTIAL** | Backend cho phép admin xóa, nhưng dùng API chung, không có trang quản trị riêng |
| | | Xóa bình luận bài đăng cộng đồng | `DELETE /api/community/posts/{pId}/comments/{cId}` | Chưa có | Backend tests (PASS) | **PARTIAL** | Tương tự, dùng API người dùng |
| **8** | **Dashboard & Thống kê** | API thống kê tổng quan (Metrics) | Chưa có (`/api/admin/stats`) | Chưa có (`features/dashboard/`) | Chưa có | **NOT STARTED** | Nằm trong kế hoạch Phase 4 cũ, chưa viết code |
| | | Biểu đồ & Chỉ số tăng trưởng | Chưa có | `WebPlaceholderScreen` (tạm) | Chưa có | **NOT STARTED** | Hiện chỉ là màn hình tĩnh chào mừng |
| **9** | **Quản lý Người dùng** | Danh sách & tìm kiếm người dùng admin | Chưa có (`/api/admin/users`) | Chưa có (`features/users/`) | Chưa có | **NOT STARTED** | Chỉ có API tìm kiếm public cho mobile |
| | | Khóa / Mở khóa tài khoản (Ban/Unban) | Chưa có (`PUT /api/admin/users/{id}/status`)| Chưa có | Chưa có | **NOT STARTED** | Cột DB `status=BANNED` đã có nhưng chưa có API |
| **10**| **Quản lý Lịch trình** | Danh sách & lọc lịch trình quản trị | Chưa có (`/api/admin/itineraries`) | Chưa có (`features/itineraries/`) | Chưa có | **NOT STARTED** | Backend `ItineraryService` chỉ cho chính chủ sửa |
| | | Ẩn / Gỡ lịch trình vi phạm | Chưa có | Chưa có | Chưa có | **NOT STARTED** | Chưa có logic gỡ bài của admin |
| **11**| **Quản lý Thông báo** | Soạn & gửi thông báo từ Admin | Chưa có | Chưa có (`features/notifications/`) | Chưa có | **NOT STARTED** | Chưa có entity/bảng Notification |
| **12**| **Hồ sơ Cá nhân Admin**| Xem & cập nhật thông tin cá nhân | `GET/PUT /api/user/profile` | `ProfileScreen` | Web tests (PASS) | **COMPLETED** | Đổi họ tên, ảnh đại diện, số điện thoại |

---

## IV. Chi tiết các chức năng đã triển khai

### 1. Quản lý Địa điểm Chuẩn hóa (Places Management)
- **Mô tả chức năng:** Cho phép Quản trị viên quản lý danh mục địa điểm toàn hệ thống (dùng chung cho việc lập kế hoạch lịch trình của người dùng mobile).
- **Thao tác quản trị:**
  - Tra cứu theo từ khóa với bộ tìm kiếm tự động trì hoãn 350ms (debounce).
  - Lọc theo 8 nhóm danh mục (`PlaceCategory`): Điểm tham quan, Nhà hàng, Khách sạn, Cà phê, Giải trí, Mua sắm, Khác.
  - Lọc theo trạng thái hiển thị (`ACTIVE`, `HIDDEN`).
  - Mở form thêm mới hoặc chỉnh sửa: điền tên, địa chỉ, chọn danh mục, nhập kinh độ/vĩ độ, URL ảnh, mô tả.
  - Xem bản đồ tương tác Leaflet: ghim vị trí địa điểm được chọn.
  - Ẩn địa điểm (soft-delete): xác nhận qua dialog chuyển trạng thái sang `HIDDEN`, không làm mất địa điểm trong các hoạt động lịch trình lịch sử.
- **API Backend xử lý:** `AdminPlaceController` (`/api/admin/places`).
- **Dữ liệu sử dụng:** Bảng `places`, quan hệ với `administrative_areas`.
- **Mức độ kiểm tra:** Rất cao. 20 tests trong `admin_place_test.dart` và test suite backend `PlaceControllerTest`.
- **Giới hạn hiện tại:** Chưa hỗ trợ kéo thả trực tiếp marker trên bản đồ để tự động điền kinh độ/vĩ độ (phải nhập tọa độ bằng số).

### 2. Khung Xác thực, Bảo mật & Phân quyền (Authentication & Authorization)
- **Mô tả chức năng:** Đảm bảo chỉ tài khoản quản trị mới có quyền truy cập vào cổng Web Admin và gọi API quản trị.
- **Thao tác quản trị:**
  - Đăng nhập qua tài khoản admin (ví dụ: `admin_master` / `admin@travelplanner.local`).
  - Nếu đăng nhập bằng tài khoản người dùng thường (`USER`), hệ thống báo lỗi rõ ràng `"Tài khoản không có quyền truy cập trang quản trị"` và xóa phiên.
  - Đăng xuất an toàn: gọi API thu hồi phiên tại máy chủ (`/api/auth/logout`) và xóa token tại trình duyệt.
- **API Backend xử lý:** `AuthController` (`/api/auth/login`, `/api/auth/logout`, `/api/auth/me`), `SecurityConfig.java`.
- **Dữ liệu sử dụng:** Bảng `users`, `user_sessions`.
- **Mức độ kiểm tra:** 100% PASS trên cả Backend (`AuthControllerTest`, `AuthSecurityUnitTest`) và Web (`auth_401_test.dart`).

### 3. Hồ sơ Cá nhân Quản trị viên (Admin Profile)
- **Mô tả chức năng:** Quản trị viên có thể xem và cập nhật thông tin cá nhân của mình.
- **Thao tác quản trị:** Nhấp vào menu Tài khoản ở góc phải AppBar -> chọn "Hồ sơ" -> chỉnh sửa họ tên, số điện thoại, tiểu sử, ảnh đại diện -> Lưu.
- **API Backend xử lý:** `ProfileController` (`/api/user/profile`).
- **Dữ liệu sử dụng:** Bảng `users`.
- **Mức độ kiểm tra:** Hoạt động tốt và tương thích với API profile chung.

---

## V. Các chức năng chưa hoàn thiện và Sai lệch hợp đồng (Gaps & Defects)

### 1. Sai lệch hợp đồng API Kiểm duyệt Cộng đồng (Critical Mismatches)

Giao diện `AdminModerationScreen` đã được code hoàn chỉnh về mặt UI nhưng không thể kết nối thành công với Backend do các bất đồng bộ sau:

#### A. Đổi trạng thái kiểm duyệt bài viết (Post Moderation)
- **Frontend gọi:** `PATCH /api/admin/community/posts/{id}` kèm body `{ "status": "HIDDEN", "reason": "Vi phạm spam" }` (tại `moderation_repository.dart:47-50`).
- **Backend lắng nghe:** `@PatchMapping("/community/posts/{id}/moderate")` tại `AdminCommunityController:38` kèm DTO `ModeratePostRequest` (chứa trường `moderationReason`, không phải `reason`).
- **Hậu quả:** Trình duyệt nhận lỗi **HTTP 405 Method Not Allowed** hoặc **HTTP 404 Not Found**. Nếu sửa URL, lý do kiểm duyệt vẫn bị `null` do sai tên trường JSON.

#### B. Xử lý báo cáo vi phạm (Resolve Report)
- **Frontend gọi:** `PATCH /api/admin/community/reports/{id}` kèm body `{ "status": "RESOLVED" }` (tại `moderation_repository.dart:98-101`).
- **Backend lắng nghe:** `@PatchMapping("/community/reports/{id}/resolve")` với `@RequestParam ReportStatus resolution` tại `AdminCommunityController:64-67`.
- **Hậu quả:** Trình duyệt nhận lỗi **HTTP 405 / 404** vì Backend không có mapping cho `PATCH /community/reports/{id}` và không nhận status qua request body.

#### C. Quản lý dọn dẹp ảnh Media Asset
- **Frontend gọi:** `GET /api/admin/community/media-assets` và `POST /api/admin/community/media-assets/{id}/retry` (tại `api_constants.dart:27-28`).
- **Backend lắng nghe:** `@GetMapping("/media-assets")` và `@PostMapping("/media-assets/{id}/retry")` tại `AdminCommunityController:73, 82` (đường dẫn thực tế là `/api/admin/media-assets`, không có tiền tố `/community`).
- **Hậu quả:** Gọi API trả về **HTTP 404 Not Found**.

### 2. Các chức năng Backend đã hoàn thiện nhưng chưa có UI (Backend Only)
- **Gán và Chuẩn hóa Đơn vị Hành chính cho Địa điểm (`AdminPlaceAdministrativeAreaController`):**
  - Đã có đầy đủ 5 endpoint: `previewResolution`, `resolveAndLink`, `linkManually`, `unlink`, `batchResolveAndLink`.
  - Đã tích hợp bộ dữ liệu chuẩn 3,355 đơn vị hành chính Việt Nam và quy tắc cách ly Nghị quyết 388/NQ-UBTVQH16.
  - **Thiếu sót:** Trên Flutter Web, màn hình `AdminPlacesScreen` hoàn toàn không có nút bấm, modal hay công cụ nào để quản trị viên chạy tính năng phân giải địa giới tự động hoặc gán mã thủ công.

### 3. Các phân hệ chưa triển khai (Not Started)
- **Dashboard & Thống kê (`features/dashboard/`):**
  - Tài liệu đặc tả yêu cầu: biểu đồ số liệu thật người dùng, lịch trình, bài viết, tăng trưởng.
  - Hiện trạng: Chưa có API `/api/admin/stats`. Flutter Web chỉ có 1 thư mục rỗng với `.gitkeep` và hiển thị thẻ tĩnh `WebPlaceholderScreen`.
- **Quản lý Tài khoản Người dùng (`features/users/`):**
  - Tài liệu đặc tả yêu cầu: xem danh sách tài khoản, tìm kiếm, xem chi tiết, khóa tài khoản (`BANNED`), mở khóa, ghi lý do khóa.
  - Hiện trạng: Bảng `users` đã có cột `status` (`ACTIVE`, `INACTIVE`, `BANNED`), nhưng Backend chưa có Controller/Service quản lý người dùng cho Admin, Flutter Web chỉ có thư mục rỗng.
- **Quản lý Lịch trình Du lịch (`features/itineraries/`):**
  - Tài liệu đặc tả yêu cầu: xem tất cả lịch trình trong cộng đồng, tìm kiếm, xem chi tiết, ẩn/gỡ lịch trình vi phạm chính sách.
  - Hiện trạng: Backend chưa có endpoint `/api/admin/itineraries`. Phân quyền trong `ItineraryServiceImpl` chỉ cho phép chính chủ tác giả thao tác. Thư mục trên Web là rỗng.
- **Quản lý Đánh giá & Bình luận Lịch trình (`features/reviews/`, `features/comments/`):**
  - Hiện trạng: Chưa có giao diện tập trung để xem danh sách bình luận/đánh giá bị báo cáo.
- **Hệ thống Quản trị Thông báo (`features/notifications/`):**
  - Hiện trạng: Chưa có cấu trúc dữ liệu và API gửi thông báo từ Admin tới người dùng.

---

## VI. Security & Authorization Audit

### 1. Phân quyền và Bảo vệ Endpoint
- **Bảo vệ tầng mạng/HTTP:**
  - `SecurityConfig.java` cấu hình `.requestMatchers("/api/admin/**").hasRole("ADMIN")`. Mọi truy cập vào tiền tố `/api/admin` từ người dùng không có JWT hoặc mang vai trò `ROLE_USER` đều bị chặn đứng với mã HTTP 403 Forbidden.
  - Các controller `AdminPlaceController` và `AdminPlaceAdministrativeAreaController` được gia cố thêm `@PreAuthorize("hasRole('ADMIN')")` ở cấp độ lớp.
  - `PostServiceImpl` có kiểm tra logic nghiệp vụ `if (admin.getRole() != Role.ADMIN) throw new ForbiddenException(...)`.
- **Khả năng người dùng thông thường gọi API Admin:**
  - **Bị chặn 100% tại máy chủ.** Không có kịch bản nào cho phép tài khoản `USER` gọi thành công các endpoint `/api/admin/**`.

### 2. Điểm yếu và Rủi ro Bảo mật Phát hiện được
- **Lưu trữ Token tại Web Admin (`AuthStorage`):**
  - Flutter Web đang lưu JWT trong `SharedPreferences` (thực chất là HTML5 `localStorage`).
  - *Rủi ro:* `localStorage` có thể bị truy cập bởi mã độc JavaScript nếu xảy ra lỗ hổng Cross-Site Scripting (XSS).
  - *Khuyến nghị:* Đối với cổng quản trị cấp cao, nên xem xét chuyển sang cơ chế xác thực bằng Cookie `HttpOnly; Secure; SameSite=Strict` trong môi trường sản xuất.
- **Thiếu Nhật ký Kiểm toán Quản trị (Admin Audit Logging):**
  - Khi Admin thực hiện xóa địa điểm, gỡ bài viết, xóa vĩnh viễn dữ liệu (purge) hoặc xử lý báo cáo, hệ thống không ghi lại bản ghi nào vào bảng kiểm toán riêng biệt (`admin_audit_logs`).
  - *Hậu quả:* Không thể truy vết ai là người đã xóa dữ liệu nếu có nhiều quản trị viên cùng vận hành.

---

## VII. Technical Debt & Code Issues

1. **Kiến trúc Điều hướng Web Admin (Navigation & Shell):**
   - Hiện tại ứng dụng chưa dùng layout chuẩn dạng Dashboard (thiếu Sidebar cố định / NavigationRail / Breadcrumbs).
   - Việc dùng `Navigator.push` toàn màn hình khiến trải nghiệm quản trị bị ngắt quãng, mỗi lần mở trang lại phải bấm nút Back để về màn hình chính.
2. **7 Thư mục Rỗng (Dead Directories):**
   - Sự xuất hiện của 7 thư mục `.gitkeep` (`comments`, `dashboard`, `itineraries`, `notifications`, `reviews`, `users`, `violations`) gây hiểu nhầm về độ hoàn thiện của dự án.
3. **Độ Tin Cậy của Unit Test Web (MockClient False Sense of Security):**
   - Toàn bộ test trong `admin_moderation_test.dart` đều mock các URL sai khớp (`/api/admin/community/posts/1` thay vì `/api/admin/community/posts/1/moderate`).
   - Điều này dẫn tới việc kiểm thử đạt 100% green nhưng ứng dụng thực tế bị gãy khi kết nối backend thật.

---

## VIII. Completion Assessment

Đánh giá mức độ hoàn thiện phân hệ Admin dựa trên **10 nhóm nghiệp vụ chính** được định nghĩa trong `Travel_Planner_Function_Specification.md`:

| Nhóm nghiệp vụ | Trọng số | Trạng thái kỹ thuật | Tỷ lệ hoàn thành | Đánh giá |
|---|:---:|:---:|:---:|---|
| 1. Xác thực, Đăng nhập & RBAC | 10% | COMPLETED | **100%** | Hoàn thiện cả Web & Backend |
| 2. Quản lý Địa điểm (Places CRUD & Map) | 15% | COMPLETED | **95%** | Hoàn thiện cả Web & Backend, thiếu chỉnh sửa marker trực tiếp |
| 3. Quản lý Đơn vị Hành chính & Địa giới | 10% | BACKEND ONLY | **50%** | Backend hoàn chỉnh 100%, Frontend Web 0% |
| 4. Kiểm duyệt Bài viết & Media rác | 15% | PARTIAL / BROKEN | **40%** | Code đủ 2 đầu nhưng lệch hợp đồng API, chưa chạy được thật |
| 5. Xử lý Báo cáo Vi phạm | 10% | PARTIAL / BROKEN | **40%** | Tương tự, lệch URL và cấu trúc body |
| 6. Dashboard & Thống kê số liệu | 15% | NOT STARTED | **0%** | Chưa có cả Backend và Frontend |
| 7. Quản lý Tài khoản Người dùng | 15% | NOT STARTED | **0%** | Chưa có API danh sách và khóa tài khoản |
| 8. Quản lý Lịch trình Cộng đồng | 10% | NOT STARTED | **0%** | Chưa có API và giao diện quản trị lịch trình |
| 9. Quản lý Đánh giá & Bình luận vi phạm | 5% | PARTIAL (Backend only) | **20%** | Mới có API xóa lẻ bằng quyền Admin |
| 10. Quản trị Thông báo Hệ thống | 5% | NOT STARTED | **0%** | Chưa có kế hoạch triển khai chi tiết |
| **TỔNG THỂ PHÂN HỆ ADMIN** | **100%** | **PARTIALLY IMPLEMENTED** | **38.5%** | **Cần tập trung hoàn thiện kết nối và các module cốt lõi** |

*(Cách tính: Tỷ lệ tổng thể là bình quân gia quyền theo trọng số của 10 nhóm nghiệp vụ đặc tả).*

---

## IX. Recommended Implementation Roadmap

Để đưa phân hệ Admin từ mức 38.5% lên mức sẵn sàng vận hành (Production Ready), đề xuất lộ trình triển khai theo 3 giai đoạn:

### Giai đoạn 1: Sửa lỗi Hợp đồng API & Đồng bộ Moderation (P0 - Immediate)
1. **Sửa khớp Contract Kiểm duyệt:**
   - Điều chỉnh `ApiConstants.dart` và `moderation_repository.dart` trên Flutter Web để khớp 100% với Spring Boot:
     - `PATCH /api/admin/community/posts/{id}/moderate` với body `{ "status": ..., "moderationReason": ... }`.
     - `PATCH /api/admin/community/reports/{id}/resolve?resolution=...`.
     - `GET /api/admin/media-assets` và `POST /api/admin/media-assets/{id}/retry`.
   - Cập nhật lại các bài test trong `admin_moderation_test.dart` tương ứng với contract chuẩn.
2. **Kiểm thử tích hợp End-to-End:** Chạy kiểm thử luồng duyệt bài, ẩn bài, xóa bài và xử lý báo cáo giữa Flutter Web và máy chủ backend đang chạy thật.

### Giai đoạn 2: Xây dựng Dashboard & Quản lý Người dùng (P1 - Core Features)
1. **Admin Dashboard:**
   - Backend: Viết `AdminDashboardController` cung cấp `GET /api/admin/stats` (tổng số người dùng, lịch trình, địa điểm, bài viết, số báo cáo đang chờ xử lý).
   - Web: Thay thế `WebPlaceholderScreen` bằng `AdminDashboardScreen` có các thẻ thống kê trực quan và danh sách việc cần xử lý gấp.
2. **Quản lý Tài khoản Người dùng:**
   - Backend: Xây dựng `AdminUserController` cung cấp `GET /api/admin/users` (phân trang, tìm kiếm, lọc theo status) và `PUT /api/admin/users/{id}/status` (chuyển trạng thái `ACTIVE` / `BANNED`, thu hồi phiên tức thời).
   - Web: Xây dựng `AdminUsersScreen` cho phép xem danh sách người dùng, tìm kiếm theo tên/email/handle, và nút thao tác Khóa/Mở khóa tài khoản kèm lý do.
3. **Chuẩn hóa Giao diện Web Shell:** Xây dựng Sidebar điều hướng cố định (Dashboard, Địa điểm, Người dùng, Kiểm duyệt) giúp chuyển đổi qua lại thuận tiện.

### Giai đoạn 3: Quản trị Lịch trình, Tích hợp Địa giới & Thông báo (P2 - Advanced)
1. **Quản lý Lịch trình Cộng đồng:**
   - Backend: Cung cấp `GET /api/admin/itineraries` và `PATCH /api/admin/itineraries/{id}/status` (chuyển trạng thái `HIDDEN` khi vi phạm).
   - Web: Thêm màn hình `AdminItinerariesScreen` hỗ trợ tìm kiếm và gỡ lịch trình vi phạm.
2. **Giao diện Quản lý Đơn vị Hành chính:**
   - Bổ sung nút "Tự động phân giải địa giới" và "Gán mã hành chính" ngay trong form chi tiết địa điểm của `AdminPlacesScreen`.
3. **Bảng Ghi nhận Lịch sử Kiểm toán (Audit Logs):**
   - Tạo bảng `admin_audit_logs` tự động ghi nhận mọi thao tác nhạy cảm (xóa, ẩn, ban tài khoản) phục vụ đối soát an ninh.
