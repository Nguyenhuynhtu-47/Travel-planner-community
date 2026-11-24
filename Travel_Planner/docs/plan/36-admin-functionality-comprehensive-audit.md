# BÁO CÁO KIỂM TOÁN TOÀN DIỆN HỆ THỐNG QUẢN TRỊ ADMIN (FLUTTER WEB & SPRING BOOT BACKEND)
## TÀI LIỆU RÀ SOÁT & ĐỐI CHIẾU KIẾN TRÚC MÃ NGUỒN THỰC TẾ (FINAL EDGE-CASE PATCH)

**Mã tài liệu:** `docs/plan/36-admin-functionality-comprehensive-audit.md`  
**Dự án:** Travel Planner Community Platform  
**Ngày cập nhật:** 25/11/2026 (Final Edge-Case Patch)  
**Giai đoạn:** Rà soát & Tinh chỉnh Kế hoạch (Plan Refinement — Read-Only, No Source Code Changes)  
**Tài liệu tham chiếu:**
- `AGENTS.md`
- `Travel_Planner_Function_Specification.md`
- `docs/ai/00-project-context.md` đến `docs/ai/12-project-status-and-next-steps.md`
- `docs/plan/admin-design-system.md`
- Báo cáo triển khai Admin Phase 1 đến Phase 6 (`docs/plan/26-*.md` đến `docs/plan/31-*.md`)
- Báo cáo Brand Identity, UI Refinement, Hover (`docs/plan/33-*.md` đến `docs/plan/35-*.md`)
- Báo cáo Audit trước đây (`docs/plan/14-admin-module-implementation-audit.md`)

---

## 1. TỔNG QUAN VÀ BỐI CẢNH KIỂM TOÁN

### 1.1. Mục tiêu kiểm toán
Thực hiện khảo sát độc lập, toàn diện và khách quan toàn bộ hệ sinh thái tính năng quản trị Admin của dự án Travel Planner, bao gồm:
1. Đối chiếu hiện trạng mã nguồn thực tế tại Spring Boot Backend (`Travel_Planner/backend`) và Flutter Web Admin (`Travel_Planner/frontend/web`).
2. Khảo sát 100% các Controller, Service, Repository, Model/Entity, DTO, Security Configuration, Database Schema và Automated Test Suites.
3. Rà soát chi tiết 11 Sidebar Tabs và các Route điều hướng thực tế trên Cổng Quản trị Flutter Web.
4. Kiểm toán chuyên sâu 7 nhóm module nghiệp vụ trọng tâm (Dashboard, Users, Itineraries, Administrative Areas, Audit Logs, System Settings, và các module đã vận hành).
5. Phân loại chính xác trạng thái từng chức năng theo các cấp độ quy chuẩn: `DONE`, `PARTIAL`, `FRONTEND_ONLY`, `BACKEND_ONLY`, `NOT_IMPLEMENTED`, `BLOCKED`.
6. Phân tích rủi ro an ninh, phân quyền RBAC, tính toàn vẹn dữ liệu và đảm bảo khả năng tương thích ngược tuyệt đối với ứng dụng Flutter Mobile.

### 1.2. Nguyên tắc kiến trúc cốt lõi
Hệ thống Travel Planner tuân thủ nghiêm ngặt 7 nguyên tắc thiết kế bất biến:
- **Backend là Single Source of Truth:** Toàn bộ nghiệp vụ, xác thực, phân quyền và kiểm soát dữ liệu nằm tại Spring Boot.
- **Frontend Thin-Client:** Flutter Web chỉ chịu trách nhiệm hiển thị giao diện, điều hướng, thu thập input và gọi REST API.
- **Không nghiệp vụ quan trọng ở Frontend:** Tuyệt đối không tính toán chỉ số nghiệp vụ, lọc quyền hay suy diễn trạng thái nghiệp vụ trên Web.
- **Nói KHÔNG với Mock / Stub Data:** Không tạo dữ liệu giả, không mock API để làm cho giao diện có vẻ hoàn chỉnh khi Backend chưa hỗ trợ.
- **Server-Side Enforcement:** Mọi thao tác quản trị bắt buộc phải được kiểm tra quyền `ROLE_ADMIN` tại Backend (qua Spring Security filter chain và `@PreAuthorize`). Việc ẩn nút ở UI chỉ là hỗ trợ trải nghiệm người dùng (UX), không phải biện pháp bảo mật.
- **Tương thích Mobile:** Không thay đổi các API, DTO, Database invariants làm ảnh hưởng đến hoạt động của Flutter Mobile App đang chạy.
- **An toàn dữ liệu:** Không xóa cứng dữ liệu người dùng khi chưa có chính sách rõ ràng; tôn trọng quyền riêng tư đối với lịch trình cá nhân.

---

## 2. KIỂM TOÁN KIẾN TRÚC BẢO MẬT VÀ PHÂN QUYỀN THỰC TẾ

### 2.1. Khảo sát Chuyên sâu Cơ chế Xác thực & Thu hồi Phiên (Authentication & Session Revocation)

Để tránh suy đoán chủ quan, toàn bộ tầng bảo mật đã được kiểm tra trực tiếp từ mã nguồn Java:

1. **Cấu trúc JWT Token (`JwtTokenProvider.java`):**
   - Token chứa các claims: `subject` (username), `userId`, `email`, `role` (`USER` / `ADMIN`), `tokenVersion`, và `sessionId` (UUID).
   - Thời gian sống mặc định: `expirationMs = 86400000` (24 giờ).
2. **Kiểm tra trạng thái tài khoản & Quyền hạn (`UserDetailsServiceImpl.java` & `CustomUserDetails.java`):**
   - Khi nạp người dùng:
     ```java
     boolean isActive = user.getStatus() == UserStatus.ACTIVE;
     boolean isNotBanned = user.getStatus() != UserStatus.BANNED;
     boolean isVerified = Boolean.TRUE.equals(user.getEmailVerified());
     boolean isEnabled = isActive && isVerified;
     ```
   - Trả về `CustomUserDetails` với `accountNonLocked = isNotBanned` và `enabled = isEnabled`.
3. **Bộ lọc xác thực (`JwtAuthenticationFilter.java`):**
   - Đã tích hợp sẵn 3 lớp bảo vệ tự động (Triple Enforcement):
     - **Lớp 1 (Session State):** Nếu JWT có `sessionId`, kiểm tra `userSessionService.isSessionActive(sessionId)`. Nếu session đã bị đánh dấu `REVOKED` hoặc hết hạn, `SecurityContextHolder.clearContext()` ngay lập tức.
     - **Lớp 2 (Account Status):** Kiểm tra `userDetails.isEnabled() && userDetails.isAccountNonLocked()`. Nếu `status == BANNED` thì `isAccountNonLocked() == false` $\rightarrow$ request bị từ chối xác thực.
     - **Lớp 3 (Token Version):** So khớp `tokenVersionFromJwt == currentDbVersion`. Nếu `users.token_version` trong database bị tăng lên, token cũ lập tức bị vô hiệu hóa toàn cục.
4. **Cơ chế thu hồi phiên hiện có (`UserSessionServiceImpl.java`):**
   - Đã có sẵn hàm `revokeAllSessions(String username)`:
     ```java
     user.setTokenVersion((user.getTokenVersion() != null ? user.getTokenVersion() : 1) + 1);
     userRepository.save(user);
     userSessionRepository.revokeAllSessionsForUser(user.getUserId(), ACTIVE, REVOKED);
     ```
5. **Cơ chế phản hồi tại Client (Flutter Mobile & Flutter Web):**
   - Cả hai client `frontend/mobile` và `frontend/web` đều có `ApiClient` tích hợp `globalOnUnauthorized`: khi nhận HTTP 401 Unauthorized, client tự động xóa sạch token lưu cục bộ và điều hướng người dùng về màn hình Đăng nhập kèm thông báo phiên hết hạn / tài khoản bị khóa.

### 2.2. Kiểm toán Quy trình Đồng bộ Batch Resolve Đơn vị Hành chính
Qua đối chiếu trực tiếp mã nguồn tại [`PlaceAdministrativeAreaServiceImpl.java#L110-L150`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/PlaceAdministrativeAreaServiceImpl.java#L110-L150):
- Endpoint `POST /api/admin/places/administrative-area/batch-resolve` xử lý **HOÀN TOÀN ĐỒNG BỘ (Synchronous)**.
- Hàm nhận `BatchResolvePlacesRequest(dryRun, overwriteExisting, placeIds)`. Duyệt qua danh sách `targetPlaces` trong cùng request thread, gọi `resolveAndLink(...)`, gom đếm kết quả và trả về ngay đối tượng `BatchLinkingReportResponse`.
- **Tính Idempotency của Backend:**
  - Nếu `overwriteExisting = false`: Những địa điểm đã có `administrative_id != null` sẽ được tự động bỏ qua (`SKIPPED`).
  - Nếu request bị timeout ở tầng HTTP Gateway (504) nhưng Backend đã commit xong trong DB: Khi client gửi lại batch đó (hoặc retry), Backend sẽ kiểm tra thấy địa điểm đã có mã hành chính và an toàn bỏ qua, không gây nhân đôi hay sai lệch dữ liệu.
- **Không có background worker hay polling endpoint:** Frontend Web Admin phải xử lý chia nhỏ danh sách (chunk size 50 places/batch), thực hiện tuần tự từng batch và hiển thị tiến độ thời gian thực.
- Cây địa giới hiển thị trên Web nạp động từ API `/api/administrative-areas/provinces` và `/api/administrative-areas/{code}/children`, **tuyệt đối không hardcode số lượng tỉnh/xã trên mã nguồn giao diện.**

### 2.3. Kiểm toán Cấu hình Upload Multipart (Servlet Container vs Business Setting)
Qua đối chiếu trực tiếp cấu hình tại `backend/src/main/resources/application.properties`:
```properties
spring.servlet.multipart.max-file-size=${MAX_FILE_SIZE:5MB}
spring.servlet.multipart.max-request-size=${MAX_REQUEST_SIZE:6MB}
```
- **Giới hạn Servlet Container (Tĩnh):** Được Spring Boot / Tomcat nạp cố định khi khởi động ứng dụng (5MB/file, 6MB/request). Bất kỳ request nào vượt quá ngưỡng này sẽ bị Servlet Filter chặn ở tầng mạng bằng lỗi `MaxUploadSizeExceededException`, trước khi vào tới Controller. **Không thể thay đổi động tại runtime mà không khởi động lại JVM.**
- **Giới hạn Nghiệp vụ Hệ thống (Động):** Cấu hình `MEDIA_MAX_IMAGE_SIZE_MB` trong bảng `system_settings` (mặc định 2MB):
  - Đóng vai trò là ngưỡng kiểm tra nghiệp vụ bổ sung tại tầng Service và gợi ý client-side validation.
  - Giá trị cấu hình này **bắt buộc phải $\le 5\text{MB}$**. Nếu Admin cấu hình $> 5\text{MB}$, Servlet container vẫn sẽ chặn ở 5MB.
  - Giao diện Cài đặt hệ thống phải ghi rõ ràng giới hạn kỹ thuật này kèm tooltip giải thích.

---

## 3. KHẢO SÁT 11 SIDEBAR TABS & ROUTE TRÊN FLUTTER WEB ADMIN

| # | Tab Tên (Tiếng Việt) | Mã Enum `AdminTab` | Phân nhóm (`AdminTabGroup`) | Route Path | Màn hình Frontend thực tế | Repository / Service Frontend | Endpoint Backend tương ứng | Trạng thái Chức năng | Bằng chứng mã nguồn |
|:---:|---|---|---|---|---|---|---|:---:|---|
| **1** | **Tổng quan** | `dashboard` | `TỔNG QUAN` | `/dashboard` | `AdminDashboardScreen` | `DashboardRepository` | `GET /api/health`<br>`GET /api/admin/places?page=0&size=1`<br>`GET /api/admin/community/posts?page=0&size=5`<br>`GET /api/admin/community/reports?status=PENDING&page=0&size=5`<br>`GET /api/admin/media-assets?page=0&size=1` | **PARTIAL** | UI hoàn chỉnh Phase 2; Backend chưa có Controller/API Stats riêng; lấy số liệu gián tiếp từ 4 API paged count |
| **2** | **Kiểm duyệt bài viết** | `posts` | `QUẢN LÝ CỘNG ĐỒNG` | `/posts` | `AdminPostsScreen` | `ModerationRepository` | `GET /api/admin/community/posts`<br>`GET /api/admin/community/posts/{id}`<br>`PATCH /api/admin/community/posts/{id}/moderate`<br>`DELETE /api/admin/community/posts/{id}/purge` | **DONE** | [`AdminCommunityController.java#L34-L66`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdminCommunityController.java#L34-L66)<br>UI có phân trang, lọc status, modal chi tiết, dialog ẩn/khôi phục, dialog purge |
| **3** | **Quản lý báo cáo** | `reports` | `QUẢN LÝ CỘNG ĐỒNG` | `/reports` | `AdminReportsScreen` | `ModerationRepository` | `GET /api/admin/community/reports`<br>`GET /api/admin/community/reports/{id}`<br>`PATCH /api/admin/community/reports/{id}/resolve` | **DONE** | [`AdminCommunityController.java#L68-L99`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdminCommunityController.java#L68-L99)<br>UI phân trang, lọc status (mặc định PENDING), modal xử lý vi phạm, bỏ qua báo cáo |
| **4** | **Quản lý người dùng** | `users` | `QUẢN LÝ CỘNG ĐỒNG` | `/users` | `PlaceholderFeatureView` | *Chưa có* | *Chưa có API Admin User trong Backend* | **NOT_IMPLEMENTED** | [`admin_shell.dart#L305`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart#L305)<br>Chỉ có placeholder; Backend thiếu `AdminUserController` |
| **5** | **Quản lý địa điểm** | `places` | `QUẢN LÝ DU LỊCH` | `/places` | `AdminPlacesScreen` | `PlaceRepository` | `GET /api/admin/places`<br>`GET /api/admin/places/{id}`<br>`POST /api/admin/places`<br>`PUT /api/admin/places/{id}`<br>`DELETE /api/admin/places/{id}` | **DONE** | [`AdminPlaceController.java#L20-L76`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdminPlaceController.java#L20-L76)<br>UI phân trang, tìm kiếm debounce, lọc category/status, modal bản đồ, form 2 cột click-to-pin, soft-delete |
| **6** | **Quản lý lịch trình** | `itineraries` | `QUẢN LÝ DU LỊCH` | `/itineraries` | `PlaceholderFeatureView` | *Chưa có* | *Chưa có API Admin Itinerary trong Backend* | **NOT_IMPLEMENTED** | [`admin_shell.dart#L306`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart#L306)<br>Chỉ có placeholder; Backend `ItineraryController` chỉ dành cho người dùng cá nhân |
| **7** | **Quản lý hình ảnh / Media** | `media` | `QUẢN LÝ NỘI DUNG` | `/media` | `AdminMediaScreen` | `ModerationRepository` | `GET /api/admin/media-assets`<br>`POST /api/admin/media-assets/{id}/retry` | **DONE** | [`AdminCommunityController.java#L101-L117`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdminCommunityController.java#L101-L117)<br>UI chế độ kép Bảng/Lưới ảnh, lọc status/dead-letter, phân trang server-side, retry xóa Cloudinary |
| **8** | **Khu vực hành chính** | `administrativeAreas` | `QUẢN LÝ NỘI DUNG` | `/administrative-areas` | `PlaceholderFeatureView` | *Chưa có* | `POST /api/admin/places/{id}/administrative-area/preview`<br>`POST /api/admin/places/{id}/administrative-area/resolve`<br>`POST /api/admin/places/{id}/administrative-area/link`<br>`DELETE /api/admin/places/{id}/administrative-area`<br>`POST /api/admin/places/administrative-area/batch-resolve`<br>`GET /api/administrative-areas/**` | **BACKEND_ONLY** | Backend đã có 5 endpoint admin tại [`AdminPlaceAdministrativeAreaController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdminPlaceAdministrativeAreaController.java) và public API, nhưng Web Admin hoàn toàn chưa có UI |
| **9** | **Nhật ký hoạt động** | `auditLogs` | `HỆ THỐNG` | `/audit-logs` | `PlaceholderFeatureView` | *Chưa có* | *Chưa có Entity / Table / Controller Audit Log* | **NOT_IMPLEMENTED** | [`admin_shell.dart#L308`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart#L308)<br>Chưa có kiến trúc ghi log kiểm toán bất biến |
| **10**| **Cài đặt hệ thống** | `settings` | `HỆ THỐNG` | `/settings` | `PlaceholderFeatureView` | *Chưa có* | *Chưa có Entity / Table / Controller Settings* | **NOT_IMPLEMENTED** | [`admin_shell.dart#L309`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart#L309)<br>Chưa có bảng lưu cấu hình động |
| **11**| **Hồ sơ cá nhân** | `profile` | `HỆ THỐNG` | `/profile` | `ProfileScreen` | `ProfileRepository` | `GET /api/user/profile`<br>`PUT /api/user/profile` | **DONE** | [`ProfileController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ProfileController.java)<br>Giao diện xem/sửa hồ sơ admin, validation, xử lý 401 tự động logout |

---

## 4. CÁC RỦI RO BẢO MẬT & ĐIỀU CHỈNH THIẾT KẾ BẮT BUỘC

### 4.1. Tính Toàn vẹn Giao dịch Kiểm toán & Phân Định Sự Cố Audit Export
- **Quy tắc phân định cốt lõi:**
  1. **Nhóm Thao tác Bắt buộc có Audit Log (Strict Audit - Bất khả phân ly):**
     - *Bao gồm:* Khóa/mở khóa tài khoản (`USER_BAN`, `USER_UNBAN`), điều chỉnh vai trò (`USER_ROLE_CHANGE`), ẩn/khôi phục lịch trình (`ITINERARY_MODERATE`), xóa vĩnh viễn bài viết (`POST_PURGE`), xử lý báo cáo (`REPORT_RESOLVE`), thay đổi cấu hình (`SETTING_UPDATE`), bật/tắt bảo trì (`MAINTENANCE_TOGGLE`), **thanh tra lịch trình riêng tư (`ITINERARY_PRIVATE_INSPECT`)**, và **xuất nhật ký kiểm toán (`AUDIT_EXPORT`)**.
     - *Transaction Boundary:* Bắt buộc thực thi trong cùng một giao dịch nguyên tử (`Propagation.REQUIRED`, `readOnly = false`).
     - *Thứ tự thực thi & Rollback:*
       - Đối với hành động đột biến dữ liệu: Ghi dữ liệu nghiệp vụ và ghi Audit Log được thực hiện trong cùng transaction; nếu ghi Audit Log thất bại $\rightarrow$ giao dịch ném ngoại lệ và **toàn bộ thao tác nghiệp vụ bị ROLLBACK**.
       - **Quy tắc cho `ITINERARY_PRIVATE_INSPECT`:** Không được dùng transaction read-only. Ghi nhận Audit Log phải hoàn tất và commit thành công trước hoặc cùng lúc với việc trả dữ liệu. **Nếu ghi Audit Log thất bại, hệ thống TUYỆT ĐỐI KHÔNG TRẢ DỮ LIỆU LỊCH TRÌNH PRIVATE**, ném ngay `AuditTrailPersistenceException` $\rightarrow$ HTTP 500.
       - **Phân Định Lỗi Audit Export vs Lỗi Lưu Trữ Audit (Audit Persistence Failure):**
         - Mỗi request xuất dữ liệu được gán một `Export ID` (UUID duy nhất).
         - **Trạng thái `SUCCESS`:** Dữ liệu trích xuất hoàn tất $\rightarrow$ file tạm tạo thành công $\rightarrow$ bản ghi Strict Audit commit thành công vào DB với `result_status = 'SUCCESS'`. **Chỉ khi Audit Log đã commit thành công**, file tạm mới đủ điều kiện được stream về client.
         - **Trạng thái `DELIVERY_FAILED`:** File tạm đã tạo và bản ghi Audit `SUCCESS` đã commit, nhưng quá trình stream HTTP về client bị đứt gãy mạng hoặc client ngắt kết nối (`ClientAbortException`). Controller streaming ghi nhận sự kiện `AUDIT_EXPORT_DELIVERY_FAILED` liên kết qua `Export ID` bằng transaction độc lập (`REQUIRES_NEW`).
         - **Trạng thái `FAILED`:** Lỗi xảy ra khi truy vấn dữ liệu hoặc tạo artifact tạm (ví dụ query timeout, tràn ổ cứng tạm), trong khi cơ sở dữ liệu vẫn hoạt động bình thường. Ghi nhận `result_status = 'FAILED'` qua transaction độc lập (`REQUIRES_NEW`).
         - **Trường hợp Đặc biệt: `AUDIT_PERSISTENCE_FAILED` (Cơ sở Dữ liệu gặp Sự cố / Down):**
           - Nếu chính cơ sở dữ liệu bị mất kết nối, lỗi mạng hoặc đầy ổ đĩa DB: **Giao dịch `REQUIRES_NEW` cũng sẽ thất bại**.
           - Hệ thống **tuyệt đối không khẳng định đã ghi thành công bản ghi FAILED** vào DB khi DB đang down.
           - File tạm tạo ra **lập tức bị xóa bỏ**, **tuyệt đối không gửi file về cho client**.
           - Ghi nhận lỗi nghiêm trọng ra hệ thống nhật ký ứng dụng độc lập (`org.slf4j.Logger.error("CRITICAL AUDIT FAILURE: Export aborted because audit trail could not be persisted to DB for exportId={}", exportId)`).
         - **Bảo Vệ File Cleanup Khi Đang Stream:**
           - File tạm được xóa trong khối `finally` của controller streaming ngay sau khi stream hoàn tất hoặc gặp lỗi ngắt kết nối.
           - Cron job định kỳ (`@Scheduled(cron = "0 0 * * * *")`): **Chỉ xóa các file mồ côi có tuổi thọ cũ hơn 2 giờ** (`currentTime - lastModified > 2 hours`). Do mọi request HTTP stream đều có timeout tối đa 10 phút, cron **tuyệt đối không bao giờ xóa file đang được stream hợp lệ**.
  2. **Best-effort Telemetry (Chỉ áp dụng cho giám sát hạ tầng & APM):**
     - Chỉ áp dụng cho các chỉ số hiệu năng CPU/RAM, trace network, hoặc log truy cập thông thường qua Logback/SLF4J, **hoàn toàn không áp dụng cho bất kỳ hành động quản trị nghiệp vụ nào trong bảng `audit_logs`**.

### 4.2. Bảo vệ Dữ liệu và Che chắn Thông tin Nhạy cảm (Data Masking)
- **Nguyên tắc:** Tuyệt đối không serialize toàn bộ JPA Entity vào cột `before_data_json` hay `after_data_json`.
- **Ưu tiên Allowlist:** Chỉ trích xuất các trường định danh và trạng thái cho phép theo từng DTO snapshot chuyên dụng:
  - `UserAuditSnapshot`: `userId`, `username`, `email` (masked), `role`, `status`.
  - `ItineraryAuditSnapshot`: `itineraryId`, `title`, `totalDays`, `visibility`, `status`.
  - `PlaceAuditSnapshot`: `placeId`, `name`, `category`, `address`, `status`, `administrativeCode`.
  - `SettingAuditSnapshot`: `settingKey`, `settingValue`, `settingGroup`.
- **Bổ sung Denylist đa tầng:** Thay thế các key nhạy cảm (`password`, `token`, `secret`, `authorization`, `credentials`, `apiKey`) bằng `***MASKED***`. PII như số điện thoại và email được làm mờ cục bộ (`090****123`, `u***@domain.com`).

### 4.3. An ninh Chế độ Bảo trì & Thứ tự Filter Chain Chuẩn mực
- **Thứ tự thực thi Filter Chain trong Spring Security:**
  1. **`CorsFilter` (CORS handling):** Bắt buộc chạy ĐẦU TIÊN! Mọi request HTTP `OPTIONS` (CORS preflight) từ browser (Flutter Web) được xử lý ngay lập tức và trả về HTTP 200 OK kèm CORS headers. Tuyệt đối không để bộ lọc bảo trì chặn preflight bằng 503.
  2. **`JwtAuthenticationFilter`:** Chạy tiếp theo, giải mã JWT, kiểm tra `token_version` và `user_sessions`, nạp `ROLE_ADMIN` vào `SecurityContextHolder`.
  3. **`MaintenanceModeFilter`:** Chạy sau khi đã xác thực:
     - Nếu hệ thống không bảo trì (`false`): cho đi tiếp.
     - Nếu hệ thống đang bảo trì (`true`):
       - Cho phép các public endpoint thiết yếu: `GET /api/health` và `POST /api/auth/login`.
       - Với mọi endpoint khác: kiểm tra `SecurityContextHolder`:
         $$\text{request.isAuthenticated()} == \text{true} \quad \text{VÀ} \quad \text{authorities.contains('ROLE_ADMIN')}$$
       - Người dùng chưa đăng nhập hoặc có vai trò `USER` (kể cả khi cố tình gọi vào `/api/admin/**`) đều nhận **HTTP 503 Service Unavailable**.
       - **Không bao giờ dùng URI `/api/admin/**` làm căn cứ bypass!**

### 4.4. Rà Soát Mọi Đường Dẫn Thay Đổi Admin Role/Status & Kiểm Tra Actor Sau Lock
- **Rà soát toàn diện mã nguồn Backend hiện hành:**
  - Kiểm tra toàn bộ mã nguồn Java: Hiện tại Backend **hoàn toàn chưa có bất kỳ API public hay admin nào cho phép thay đổi `User.role` hoặc `User.status`** (kể cả `ProfileController` chỉ cho sửa text/avatar; `register` luôn gán `Role.USER`; không có API xóa/hủy tài khoản tự do).
  - Do đó, **2 endpoint được lên kế hoạch tại Phase 2 là đường dẫn duy nhất thay đổi role/status**:
    - `PATCH /api/admin/users/{id}/role`
    - `PATCH /api/admin/users/{id}/status`
  - **Quy tắc Bất biến:** Mọi thao tác có khả năng thay đổi số lượng Admin ACTIVE (kể cả các tính năng mở rộng trong tương lai như soft-delete hay deactivation) **bắt buộc phải đi qua cùng một Mutex duy nhất: `admin_role_guard`**.
- **Quy tắc Bắt buộc: Tải lại và Tái Xác thực Actor Sau Khi Nhận Lock:**
  - Ngay sau khi thực hiện `SELECT * FROM admin_role_guard WHERE guard_name = 'ADMIN_ROLE_MUTEX' FOR UPDATE;`:
    1. Tải lại thực thể Actor từ cơ sở dữ liệu: `userRepository.findByUsername(actorUsername)`.
    2. Kiểm tra quyền thực tế: Actor phải có `status == ACTIVE` và `role == ADMIN`. Nếu Actor đã bị khóa hoặc bị hạ quyền trong lúc chờ lock $\rightarrow$ **lập tức ném `AccessDeniedException` (HTTP 403 Forbidden)**, hủy thao tác.
    3. Kiểm tra Anti Self-Action: `actor.userId == target.userId` $\rightarrow$ ném `BadRequestException` (HTTP 400).
    4. Kiểm tra Last-Admin Invariant: `SELECT COUNT(*) FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE'`. Nếu target là Admin ACTIVE và số lượng $\le 1$ $\rightarrow$ ném `BadRequestException` (HTTP 400).
- **Ranh giới Spring Bean Proxy Phân Tách Rõ Ràng (Tách 2 Bean Độc Lập):**
  - **Bean 1 — `AdminUserOrchestrationService` (Retry Service):** `@Retryable(retryFor = {CannotAcquireLockException.class, PessimisticLockingFailureException.class})`.
  - **Bean 2 — `AdminUserTransactionalWorker` (Transactional Worker):** `@Transactional(propagation = Propagation.REQUIRES_NEW, isolation = Isolation.READ_COMMITTED)`.
- **Bộ 8 Integration Tests Bắt buộc Cho Phase 2 (Được thiết kế chính xác dữ liệu):**
  1. `antiSelfDemotion_rejected()`: Admin tự hạ quyền bị 400 Bad Request (`CANNOT_DEMOTE_SELF`).
  2. `antiSelfBan_rejected()`: Admin tự ban bị 400 Bad Request (`CANNOT_BAN_SELF`).
  3. `lastAdminDemotion_rejected()`: Khi hệ thống chỉ có 1 Admin ACTIVE, hạ quyền Admin này bị 400 Bad Request (`CANNOT_DEMOTE_LAST_ADMIN`).
  4. `lastAdminBan_rejected()`: Khi hệ thống chỉ có 1 Admin ACTIVE, ban Admin này bị 400 Bad Request (`CANNOT_BAN_LAST_ADMIN`).
  5. `concurrentDemotion_actorPrivilegeMaintained_invariantMaintained()`: Setup 2 Admin ACTIVE (`admin_A`, `admin_B`). `admin_A` demote `admin_B`, `admin_B` demote `admin_A`. Luồng 1 demote `admin_B` thành công. Luồng 2 unblock kiểm tra lại thấy `admin_B` đã là `USER` $\rightarrow$ bị từ chối với 403 Forbidden. DB count active admins luôn = 1.
  6. `concurrentPromoteAndDemote_success()`: Setup 2 Admin ACTIVE (`admin_A`, `admin_B`) và 1 User (`user_C`). `admin_A` nâng quyền `user_C` thành Admin, `admin_B` hạ quyền `admin_B` (sai - self demote) $\rightarrow$ `admin_A` hạ quyền `admin_B`. Cả hai commit tuần tự; final count = 2 Admin ACTIVE (`admin_A`, `user_C`).
  7. `concurrentBanAndDemote_lastAdminProtected()`:
     - **Setup kiểm thử chuẩn mực:** Khởi tạo chính xác **3 Admin ACTIVE** (`admin_A`, `admin_B`, `admin_C`).
     - Luồng 1: `actor: admin_A, target: admin_C`, Action: `DEMOTE` (`admin_C` $\rightarrow$ `USER`).
     - Luồng 2: `actor: admin_B, target: admin_C`, Action: `BAN` (`admin_C` $\rightarrow$ `BANNED`).
     - Cả hai actor đều là Admin ACTIVE độc lập và không tự thao tác lên chính mình.
     - Luồng 1 nhận lock trước $\rightarrow$ demote `admin_C` thành USER. Active admins còn 2 (`admin_A`, `admin_B`).
     - Luồng 2 unblock nhận lock $\rightarrow$ `admin_B` vẫn là Admin ACTIVE, target `admin_C` đã là USER $\rightarrow$ ban `user C` thành BANNED.
     - **Kết quả cuối cùng:** Số Admin ACTIVE là 2 (`admin_A`, `admin_B`), bảo vệ tuyệt đối không làm mất Admin cuối cùng!
  8. `actorLosesPrivilegeWhileWaitingForMutex_rejected()`: Admin A demote Admin B. Trong lúc đó, Admin B đang gửi request ban Admin C. Khi Admin B nhận lock, worker kiểm tra lại DB thấy Admin B đã là `USER` $\rightarrow$ ném 403 Forbidden, hủy thao tác, bảo đảm Admin C không bị ban trái phép!

### 4.5. Quy trình Kiểm duyệt Lịch trình Riêng tư (Private Itinerary Moderation)
- Admin **không được duyệt danh sách tự do** toàn bộ lịch trình `PRIVATE` của người dùng.
- Để mở xem nội dung lịch trình `PRIVATE`: Admin phải cung cấp `reportId` hợp lệ và `inspectionReason` (tối thiểu 10 ký tự). Backend kiểm tra:
  1. `reportId` có tồn tại và đang ở trạng thái `PENDING`.
  2. Báo cáo đó thực sự tố cáo đúng `itineraryId` đang được yêu cầu.
  3. Ghi nhận bắt buộc 1 bản ghi vào `audit_logs` với action `ITINERARY_PRIVATE_INSPECT` trong cùng transaction (`Propagation.REQUIRED`, `readOnly = false`). Nếu ghi log thất bại $\rightarrow$ rollback và **tuyệt đối không trả payload**.
- Sau khi mở xem read-only, Admin chỉ có quyền ẩn (`HIDDEN`) hoặc khôi phục (`ACTIVE`), **tuyệt đối không được sửa đổi nội dung chuyến đi**.

### 4.6. Thiết kế Thực thi Batch Resolve Đồng bộ & Chia nhỏ Theo Lô
- Do Backend xử lý đồng bộ (`PlaceAdministrativeAreaServiceImpl.batchResolveAndLink`), Frontend Web Admin phải triển khai cơ chế chia lô tuần tự (Sequential Batching):
  - Chia danh sách `placeIds` cần chuẩn hóa thành các mẩu nhỏ (chunk size 50 places/batch).
  - Web UI gửi request xử lý từng batch tuần tự, hiển thị tiến độ thời gian thực: tổng số địa điểm, số đã xử lý, thành công, thất bại, bỏ qua và còn chờ.
  - Hỗ trợ chế độ xem trước an toàn `dryRun = true` trước khi ghi dữ liệu thật. Giao diện hiển thị cảnh báo: "Kết quả xem trước (Dry-run) chỉ phản ánh trạng thái hiện thời của cơ sở dữ liệu. Dữ liệu địa giới hoặc tọa độ địa điểm có thể thay đổi trước khi thực thi ghi dữ liệu thực tế."
  - Hỗ trợ thử lại (Retry) với tính năng bảo đảm Idempotency: gom danh sách các `placeId` bị thất bại để gửi lại.

### 4.7. Kiến trúc Lưu trữ, Đánh Chỉ mục & Truy vấn Nhật ký Kiểm toán (Audit Log Engine)
- **Đánh chỉ mục phức hợp (Compound Indexes) tối ưu hóa truy vấn:**
  ```sql
  INDEX idx_audit_actor_created (actor_id, created_at DESC),
  INDEX idx_audit_action_created (action_type, created_at DESC),
  INDEX idx_audit_target_created (target_type, target_id, created_at DESC),
  INDEX idx_audit_created_at (created_at DESC)
  ```
- **Phân trang Ổn định (Stable Pagination):**
  - Mọi truy vấn phân trang nhật ký kiểm toán bắt buộc áp dụng thứ tự sắp xếp kép: `ORDER BY created_at DESC, log_id DESC` để bảo đảm tính tất định và không bị trôi/lặp bản ghi giữa các trang khi hệ thống có lượng log ghi dồn dập.
- **Tính Bất biến Tuyệt đối (Append-Only Invariant):**
  - Bảng `audit_logs` và `AdminAuditLogRepository` chỉ cung cấp `save` (INSERT) và `findAll` (SELECT).
  - Tuyệt đối không cung cấp API cập nhật hay xóa bản ghi kiểm toán cho Quản trị viên.
- **Giới hạn Xuất Dữ liệu Bằng Projection / Streaming:**
  - Áp dụng phân trang bắt buộc ở tầng máy chủ (mặc định 20, tối đa 50 bản ghi/trang).
  - Giới hạn cứng xuất file báo cáo (`AUDIT_EXPORT`): Tối đa 5,000 bản ghi mỗi lần xuất, sử dụng interface-based projection (`AuditLogExportProjection`) và streaming response xả bộ đệm liên tục để chống cạn kiệt bộ nhớ (OOM).
- **Chính sách Lưu trữ & Lưu kho Dữ liệu (Retention & Archiving):**
  - Dữ liệu trực tuyến lưu trữ 180 ngày trong bảng `audit_logs`.
  - Bản ghi cũ hơn 180 ngày được định kỳ chuyển sang kho lưu trữ lạnh (`audit_logs_archive` hoặc cold partition) bằng script bảo trì máy chủ chuyên dụng. Quản trị viên có thể tra cứu lịch sử lưu trữ qua bộ lọc khoảng thời gian mở rộng với quyền hạn được kiểm soát nghiêm ngặt.

---

## 5. KẾT LUẬN VÀ BƯỚC TIẾP THEO

Báo cáo kiểm toán đã được hoàn thiện triệt để ở mức cao nhất (Final Edge-Case Patch), phản ánh chính xác 100% hiện trạng mã nguồn thực tế và đã xử lý toàn bộ các điểm phản biện kiến trúc của Chủ dự án. Kính mời Chủ dự án xem xét tài liệu Lộ trình tinh chỉnh tại `docs/plan/37-admin-functionality-implementation-roadmap.md`.
