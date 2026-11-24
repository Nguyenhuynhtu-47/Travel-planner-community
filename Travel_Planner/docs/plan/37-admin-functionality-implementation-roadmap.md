# LỘ TRÌNH TRIỂN KHAI TOÀN DIỆN PHÂN HỆ QUẢN TRỊ ADMIN (7-PHASE REFINED IMPLEMENTATION ROADMAP)
## BẢN HIỆU CHỈNH KIẾN TRÚC & AN NINH CUỐI CÙNG (FINAL EDGE-CASE PATCH)

**Mã tài liệu:** `docs/plan/37-admin-functionality-implementation-roadmap.md`  
**Dự án:** Travel Planner Community Platform  
**Ngày cập nhật:** 25/11/2026 (Final Edge-Case Patch)  
**Trạng thái:** Kế hoạch Triển khai Tinh chỉnh (Plan Refinement — Read-Only)  
**Tài liệu liên quan:**
- `docs/plan/36-admin-functionality-comprehensive-audit.md` (Báo cáo Kiểm toán Toàn diện)
- `docs/plan/38-admin-functionality-traceability-matrix.md` (Ma trận Truy vết Chức năng)
- `docs/plan/admin-design-system.md` (Quy chuẩn Thiết kế Doanh nghiệp Swiss Minimalism)

---

## 1. NGUYÊN TẮC THIẾT LẬP LỘ TRÌNH 7 GIAI ĐOẠN

Lộ trình được cấu trúc thành **7 Phase độc lập** theo thứ tự phụ thuộc kỹ thuật và yêu cầu an ninh:

```
+-----------------------------------------------------------------------------------------+
|                                ROADMAP 7 GIAI ĐOẠN ADMIN                                |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|  [PHASE 1] AUDIT TRAIL CORE (HẠ TẦNG GHI NHẬN KIỂM TOÁN CHUNG - BACKEND ONLY)          |
|  - Bảng audit_logs, Entity/Service, Allowlist Snapshot DTOs, Strict REQUIRED Transaction|
|  - Index phức hợp, Stable Pagination (created_at DESC, log_id DESC), Lưu kho 180 ngày   |
|                                     |                                                   |
|                                     v                                                   |
|  [PHASE 2] USER MANAGEMENT (QUẢN LÝ NGƯỜI DÙNG & BẢO VỆ PHIÊN)                          |
|  - Bảng độc lập admin_role_guard (loại bỏ phụ thuộc Phase 6), Chống mất Admin cuối      |
|  - Tách 2 Bean độc lập: AdminUserOrchestrationService (@Retryable) & TransactionalWorker|
|  - Tái xác thực Actor từ DB sau khi nhận Mutex lock, Chặn tự ban/hạ quyền, Ẩn Register |
|  - Rà soát bảo vệ 100% đường thay đổi role/status, Bộ 8 Integration Tests chuẩn hóa     |
|                                     |                                                   |
|                                     v                                                   |
|  [PHASE 3] ITINERARY MODERATION (KIỂM DUYỆT VÒNG ĐỜI LỊCH TRÌNH)                        |
|  - AdminItineraryController, Màn hình Itineraries, Ẩn/Khôi phục, Quy trình duyệt PRIVATE|
|  - Strict Audit cho thanh tra PRIVATE (readOnly=false; lỗi audit -> không trả dữ liệu)   |
|                                     |                                                   |
|                                     v                                                   |
|  [PHASE 4] ADMINISTRATIVE AREAS (GIAO DIỆN QUẢN LÝ ĐƠN VỊ HÀNH CHÍNH)                  |
|  - Web UI Cây 34 tỉnh/xã động, Batch Resolve tuần tự theo lô (chunk 50), dryRun, Retry  |
|  - Idempotency bảo đảm an toàn khi timeout, Cảnh báo dryRun dữ liệu thay đổi            |
|                                     |                                                   |
|                                     v                                                   |
|  [PHASE 5] AUDIT LOGS UI (GIAO DIỆN KHÁM PHÁ NHẬT KÝ KIỂM TOÁN)                        |
|  - Màn hình Audit Logs, Bộ lọc đa chiều, Xem JSON diff đã mask, Xuất CSV/JSON an toàn   |
|  - Phân định rõ: SUCCESS / DELIVERY_FAILED / FAILED vs AUDIT_PERSISTENCE_FAILED        |
|  - Bảo vệ cleanup: finally xóa file ngay, Cron job chỉ dọn file mồ côi > 2 giờ         |
|                                     |                                                   |
|                                     v                                                   |
|  [PHASE 6] SYSTEM SETTINGS (CẤU HÌNH NGHIỆP VỤ ĐỘNG & BẢO TRÌ AN TOÀN)                 |
|  - Bảng system_settings (thuần túy cấu hình nghiệp vụ, không chứa lock row)             |
|  - Thứ tự Filter chuẩn mực: CorsFilter -> JwtAuthenticationFilter -> MaintenanceFilter |
|  - Phân biệt Servlet Multipart 5MB (tĩnh) vs Business limit (động <= 5MB)               |
|                                     |                                                   |
|                                     v                                                   |
|  [PHASE 7] DASHBOARD V2 (BẢNG ĐIỀU KHIỂN VẬN HÀNH TOÀN DIỆN & THỐNG KÊ TỔNG HỢP)       |
|  - AdminDashboardController 1 API summary gộp số liệu thật, Biểu đồ tăng trưởng thực tế |
|                                                                                         |
+-----------------------------------------------------------------------------------------+
```

---

## 2. PHÂN TÍCH KỸ THUẬT & HIỆU CHỈNH BẢO MẬT BẮT BUỘC

### 2.1. Tính Toàn vẹn Giao dịch Kiểm toán & Phân Định Sự Cố Audit Export
Phương án xử lý lỗi và ranh giới giao dịch cho Audit Log được phân loại rõ ràng:

1. **Nhóm Thao tác Kiểm toán Bắt buộc (Strict Audit - Bất khả phân ly):**
   - *Phạm vi bao gồm:*
     - Đột biến tài khoản: Khóa/mở khóa (`USER_BAN`, `USER_UNBAN`), điều chỉnh vai trò (`USER_ROLE_CHANGE`).
     - Kiểm duyệt nội dung: Ẩn/khôi phục lịch trình (`ITINERARY_MODERATE`), xóa vĩnh viễn bài viết (`POST_PURGE`), xử lý báo cáo (`REPORT_RESOLVE`).
     - Cấu hình hệ thống: Cập nhật tham số (`SETTING_UPDATE`), bật/tắt chế độ bảo trì (`MAINTENANCE_TOGGLE`).
     - **Thanh tra riêng tư:** Mở xem lịch trình cá nhân (`ITINERARY_PRIVATE_INSPECT`).
     - **Xuất nhật ký:** Trích xuất file kiểm toán (`AUDIT_EXPORT`).
   - *Transaction Boundary:* Bắt buộc thực thi trong cùng giao dịch nguyên tử (`Propagation.REQUIRED`, `readOnly = false`).
   - *Xử lý lỗi & Rollback:*
     - Nếu việc ghi bản ghi vào bảng `audit_logs` gặp sự cố (lỗi kết nối DB, vi phạm ràng buộc, ổ đĩa đầy), ngoại lệ được ném ra và **toàn bộ giao dịch nghiệp vụ chính bị ROLLBACK**. Nghiệp vụ chính không bao giờ được commit nếu audit log thất bại.
     - **Quy tắc tuyệt đối cho `ITINERARY_PRIVATE_INSPECT`:** Không được đánh dấu giao dịch là `readOnly = true` vì thao tác này cần chèn bản ghi vào `audit_logs`. Bản ghi audit log phải được ghi nhận và flush thành công trước khi dữ liệu được serialize trả về. Nếu ghi log thất bại, ném `AuditTrailPersistenceException` $\rightarrow$ ánh xạ HTTP 500 và **tuyệt đối không trả về payload lịch trình PRIVATE**.
     - **Phân Định Lỗi Xuất File vs Lỗi Lưu Trữ Audit (`AUDIT_EXPORT`):**
       - Mỗi request xuất dữ liệu được gán một `Export ID` (UUID duy nhất) để liên kết toàn bộ vòng đời.
       - **Trạng thái `SUCCESS`:** Dữ liệu trích xuất hoàn tất $\rightarrow$ file tạm tạo thành công $\rightarrow$ bản ghi Strict Audit commit thành công vào DB với `result_status = 'SUCCESS'`. **Chỉ khi Audit Log đã commit thành công**, file tạm mới đủ điều kiện được stream về client. *Lưu ý:* `SUCCESS` không khẳng định trình duyệt đã tải trọn vẹn, mà xác nhận máy chủ đã tạo và thẩm quyền hóa dữ liệu xuất thành công.
       - **Trạng thái `DELIVERY_FAILED`:** File tạm đã tạo và bản ghi Audit `SUCCESS` đã commit, nhưng quá trình truyền tải HTTP tới client bị lỗi mạng, ngắt kết nối (`ClientAbortException`) hoặc socket timeout. Hệ thống bắt ngoại lệ tại controller streaming và ghi nhận sự kiện `AUDIT_EXPORT_DELIVERY_FAILED` liên kết qua `Export ID` bằng transaction độc lập (`REQUIRES_NEW`).
       - **Trạng thái `FAILED`:** Lỗi xảy ra khi truy vấn dữ liệu hoặc tạo artifact tạm (ví dụ query timeout, tràn ổ cứng tạm), trong khi cơ sở dữ liệu vẫn hoạt động bình thường. Ghi nhận `result_status = 'FAILED'` qua transaction độc lập (`REQUIRES_NEW`).
       - **Trường hợp Đặc biệt: `AUDIT_PERSISTENCE_FAILED` (Cơ sở Dữ liệu gặp Sự cố / Down):**
         - Nếu chính cơ sở dữ liệu bị mất kết nối, lỗi mạng hoặc đầy ổ đĩa DB: **Giao dịch `REQUIRES_NEW` cũng sẽ thất bại**.
         - Hệ thống **tuyệt đối không khẳng định đã ghi thành công bản ghi FAILED** vào DB khi DB đang down.
         - File tạm tạo ra **lập tức bị xóa bỏ**, **tuyệt đối không gửi file về cho client**.
         - Ghi nhận lỗi nghiêm trọng ra hệ thống nhật ký ứng dụng độc lập (`org.slf4j.Logger.error("CRITICAL AUDIT FAILURE: Export aborted because audit trail could not be persisted to DB for exportId={}", exportId)`).
       - **Bảo Vệ File Cleanup Khi Đang Stream:**
         - File tạm được lưu tại thư mục hệ thống: `java.io.tmpdir/travel_planner_exports/{exportId}.csv`.
         - Dọn dẹp tức thì trong khối `finally` của controller streaming ngay sau khi stream hoàn tất hoặc gặp lỗi ngắt kết nối.
         - Cron job dọn dẹp định kỳ (`@Scheduled(cron = "0 0 * * * *")`): **Chỉ xóa các file mồ côi có tuổi thọ cũ hơn 2 giờ** (`currentTime - lastModified > 2 hours`). Do mọi request HTTP stream đều có timeout tối đa 10 phút, cron **tuyệt đối không bao giờ xóa file đang được stream hợp lệ**.
   - *Trade-off:* Đảm bảo tính toàn vẹn 100% và trách nhiệm giải trình tuyệt đối (Non-repudiation) theo chuẩn an ninh doanh nghiệp.

2. **Nhóm Đo đạc Hiệu năng & Giám sát Hạ tầng (Best-effort Telemetry):**
   - *Phạm vi:* Thu thập chỉ số CPU/RAM, số kết nối database pool, trace network, thống kê lượt truy cập thông thường qua Logback/SLF4J/Micrometer.
   - *Tuyệt đối không áp dụng cho bảng `audit_logs`*: Mọi thao tác quản trị ghi vào bảng `audit_logs` đều là Strict Audit.

### 2.2. Chiến lược Che chắn Dữ liệu Nhạy cảm (Data Masking Architecture)
1. **Quy tắc Bất biến:** Tuyệt đối không serialize trực tiếp các JPA Entities (`User`, `Itinerary`, `Place`, `Post`) vào cột `before_data_json` hay `after_data_json`. Việc này ngăn ngừa triệt để lỗi vòng lặp Jackson, ngoại lệ lazy loading ngoài session, và nguy cơ rò rỉ các cột nhạy cảm như `password` (bcrypt hash), `token_version`.
2. **Tiếp cận Ưu tiên Danh sách Cho phép (Allowlist-First):**
   Mỗi loại đối tượng được định nghĩa một DTO Snapshot chuyên biệt:
   - `UserAuditSnapshot`: `userId`, `username`, `handle`, `email` (đã mask), `role`, `status`.
   - `ItineraryAuditSnapshot`: `itineraryId`, `title`, `totalDays`, `visibility`, `status`.
   - `PlaceAuditSnapshot`: `placeId`, `name`, `category`, `address`, `status`, `administrativeCode`.
   - `SettingAuditSnapshot`: `settingKey`, `settingValue`, `settingGroup`.
3. **Bộ lọc Từ khóa Cấm Bổ trợ (Denylist Fallback):**
   Lớp tiện ích `DataMaskingUtil` quét toàn bộ JSON trước khi persist:
   - Các trường trùng khớp: `password`, `token`, `secret`, `authorization`, `credentials`, `apiKey`, `privateKey` $\rightarrow$ thay thế bằng `***MASKED***`.
   - PII nhạy cảm: Số điện thoại (`090****123`), Email (`u***@domain.com`).

### 2.3. Cấu hình Upload Multipart & Thứ tự Filter Chain Chế độ Bảo trì
1. **Phân biệt Ranh giới Servlet Multipart và Dynamic Setting:**
   - Cấu hình tại `application.properties`:
     ```properties
     spring.servlet.multipart.max-file-size=${MAX_FILE_SIZE:5MB}
     spring.servlet.multipart.max-request-size=${MAX_REQUEST_SIZE:6MB}
     ```
   - Đây là **giới hạn tĩnh của Servlet Container (Tomcat)**, được nạp lúc khởi động JVM. Bất kỳ request nào lớn hơn 5MB sẽ bị chặn ở tầng filter mạng với lỗi `MaxUploadSizeExceededException`. **Không thể thay đổi giá trị này tại runtime từ database.**
   - Cấu hình động `MEDIA_MAX_IMAGE_SIZE_MB` trong `system_settings`:
     - Đóng vai trò là ngưỡng nghiệp vụ kiểm tra bổ sung tại Service và gợi ý client-side validation.
     - Giá trị cấu hình này **bắt buộc phải $\le 5\text{MB}$**.
     - UI Web Admin phải hiển thị rõ thông báo: "Giới hạn upload nghiệp vụ (tối đa 5MB theo cấu hình Servlet Container; nếu muốn nâng vượt mức này cần cập nhật biến môi trường và khởi động lại máy chủ)".
2. **Thứ tự Filter Chain Chuẩn mực cho Maintenance Mode:**
   - **Lớp 1: `CorsFilter` (hoặc `cors()` trong Spring Security):**
     - **Chạy đầu tiên!** Xử lý toàn bộ request HTTP `OPTIONS` (CORS Preflight) từ trình duyệt (Flutter Web) và trả về ngay HTTP 200 OK kèm các header `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`.
     - Tuyệt đối không để bộ lọc bảo trì chặn request `OPTIONS` bằng 503, vì trình duyệt sẽ coi là lỗi CORS và từ chối gửi request chính.
   - **Lớp 2: `JwtAuthenticationFilter`:**
     - Chạy tiếp theo để giải mã JWT token, kiểm tra `token_version` và `user_sessions`.
     - Nếu token hợp lệ, nạp `Authentication` chứa `ROLE_ADMIN` vào `SecurityContextHolder`.
   - **Lớp 3: `MaintenanceModeFilter`:**
     - Đặt sau `JwtAuthenticationFilter` và trước `AuthorizationFilter`.
     - Kiểm tra cờ `SYSTEM_MAINTENANCE_MODE`:
       - Nếu không bảo trì (`false`): tiếp tục chuỗi filter.
       - Nếu đang bảo trì (`true`):
         - Cho phép public endpoint thiết yếu: `GET /api/health` và `POST /api/auth/login`.
         - Với mọi request khác: Đọc `SecurityContextHolder.getContext().getAuthentication()`.
         - **CHỈ cho phép tiếp tục NẾU:** `auth != null && auth.isAuthenticated() && auth.getAuthorities().contains("ROLE_ADMIN")`.
         - Nếu không có quyền Admin (kể cả request mang vai trò `USER` gọi vào `/api/admin/**`): Lập tức trả về **HTTP 503 Service Unavailable** kèm body JSON thông báo bảo trì.
   - **Không bao giờ dùng URI `/api/admin/**` làm căn cứ bypass!**

### 2.4. Rà Soát Mọi Đường Dẫn Thay Đổi Admin Role/Status & Kiểm Tra Actor Sau Lock
1. **Rà soát toàn diện mã nguồn Backend hiện hành:**
   - Đã khảo sát 100% các Controller và Service: Backend hiện tại **hoàn toàn chưa có bất kỳ API public hay admin nào cho phép thay đổi `User.role` hoặc `User.status`** (kể cả `ProfileController` chỉ cho sửa text/avatar; `register` luôn gán `Role.USER`; không có API xóa/hủy tài khoản tự do).
   - Do đó, **2 endpoint được lên kế hoạch tại Phase 2 là đường dẫn duy nhất thay đổi role/status**:
     - `PATCH /api/admin/users/{id}/role`
     - `PATCH /api/admin/users/{id}/status`
   - **Quy tắc Bất biến:** Mọi thao tác có khả năng thay đổi số lượng Admin ACTIVE (kể cả các tính năng mở rộng trong tương lai như soft-delete hay deactivation) **bắt buộc phải đi qua cùng một Mutex duy nhất: `admin_role_guard`**.
2. **Quy tắc Bắt buộc: Tải lại và Tái Xác thực Actor Sau Khi Nhận Lock:**
   - Khi có nhiều request đồng thời xếp hàng chờ mutex, Actor có thể đã bị Admin khác hạ quyền hoặc khóa tài khoản trong thời gian chờ lock.
   - **Do đó, tuyệt đối không tin cậy hoàn toàn vào claims trong `SecurityContextHolder` trước lock.**
   - Ngay sau khi thực hiện `SELECT * FROM admin_role_guard WHERE guard_name = 'ADMIN_ROLE_MUTEX' FOR UPDATE;`:
     1. Tải lại thực thể Actor từ cơ sở dữ liệu trong transaction hiện tại: `userRepository.findByUsername(actorUsername)`.
     2. Kiểm tra quyền thực tế: Actor phải có `status == ACTIVE` và `role == ADMIN`.
     3. Nếu Actor đã bị khóa hoặc bị hạ quyền trong lúc chờ lock $\rightarrow$ **lập tức ném `AccessDeniedException` (HTTP 403 Forbidden)** và hủy bỏ toàn bộ thao tác, không cho phép tiếp tục!
     4. Kiểm tra Anti Self-Action: `actor.userId == target.userId` $\rightarrow$ ném `BadRequestException` (HTTP 400).
     5. Kiểm tra Last-Admin Invariant: `SELECT COUNT(*) FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE'`. Nếu target là Admin ACTIVE và số lượng $\le 1$ $\rightarrow$ ném `BadRequestException` (HTTP 400).
3. **Ranh giới Spring Bean Proxy Phân Tách Rõ Ràng (Tách 2 Bean Độc Lập):**
   - Trong Spring, nếu `@Retryable` và `@Transactional` nằm trong cùng một Bean, việc gọi `this.method()` là self-invocation sẽ **bỏ qua Spring AOP Proxy**, dẫn đến không tạo transaction mới cho từng retry attempt.
   - Thiết kế chuẩn mực bắt buộc **tách biệt thành 2 Spring Bean độc lập**:
     - **Bean 1 — `AdminUserOrchestrationService` (Retry Service):**
       ```java
       @Service
       public class AdminUserOrchestrationService {
           private final AdminUserTransactionalWorker worker;

           public AdminUserOrchestrationService(AdminUserTransactionalWorker worker) {
               this.worker = worker;
           }

           @Retryable(
               retryFor = {CannotAcquireLockException.class, PessimisticLockingFailureException.class},
               maxAttempts = 3,
               backoff = @Backoff(delay = 100, multiplier = 2)
           )
           public UserAdminResponse updateUserRoleWithRetry(Long targetUserId, UpdateUserRoleRequest request, String actorUsername) {
               return worker.executeRoleUpdateInNewTransaction(targetUserId, request, actorUsername);
           }
       }
       ```
     - **Bean 2 — `AdminUserTransactionalWorker` (Transactional Worker):**
       ```java
       @Component
       public class AdminUserTransactionalWorker {
           @Transactional(propagation = Propagation.REQUIRES_NEW, isolation = Isolation.READ_COMMITTED)
           public UserAdminResponse executeRoleUpdateInNewTransaction(Long targetUserId, UpdateUserRoleRequest request, String actorUsername) {
               // 1. SELECT * FROM admin_role_guard WHERE guard_name = 'ADMIN_ROLE_MUTEX' FOR UPDATE;
               // 2. Reload actor from DB -> verify status ACTIVE && role ADMIN (if not -> throw AccessDeniedException)
               // 3. Verify target != actor (if equals -> throw BadRequestException)
               // 4. Verify count(active admins) > 1 if target is active admin
               // 5. Update target role & revoke sessions via token_version
               // 6. Strict audit log (REQUIRED in same tx)
               // 7. Commit
           }
       }
       ```
     - Nhờ tách 2 Bean, mỗi lần retry từ Bean 1 gọi sang Bean 2 đều đi qua Spring AOP Proxy, kích hoạt một transaction vật lý hoàn toàn mới và sạch sẽ (`REQUIRES_NEW`).
     - **Chỉ retry lỗi lock contention/deadlock; tuyệt đối không retry lỗi nghiệp vụ.**
4. **Bộ 8 Integration Tests Bắt buộc Cho Phase 2 (Thiết Kế Chuẩn Mực Dữ Liệu):**
   - **Test 1: Anti Self-Demotion:** `admin_1` gửi request hạ quyền chính `admin_1` $\rightarrow$ bị chặn ngay với HTTP 400 Bad Request (`CANNOT_DEMOTE_SELF`).
   - **Test 2: Anti Self-Ban:** `admin_1` gửi request ban chính `admin_1` $\rightarrow$ bị chặn ngay với HTTP 400 Bad Request (`CANNOT_BAN_SELF`).
   - **Test 3: Last-Admin Demotion:** Khi hệ thống chỉ có 1 Admin ACTIVE, hạ quyền Admin này bị 400 Bad Request (`CANNOT_DEMOTE_LAST_ADMIN`).
   - **Test 4: Last-Admin Ban:** Khi hệ thống chỉ có 1 Admin ACTIVE, ban Admin này bị 400 Bad Request (`CANNOT_BAN_LAST_ADMIN`).
   - **Test 5: Concurrent Demotion with Active Actor (`concurrentDemotion_actorPrivilegeMaintained_invariantMaintained()`):**
     - Setup ban đầu: 2 Admin ACTIVE (`admin_A`, `admin_B`).
     - Thread 1 (`actor: admin_A, target: admin_B`) vs Thread 2 (`actor: admin_B, target: admin_A`).
     - Thread 1 nhận lock trước $\rightarrow$ demote `admin_B` thành USER.
     - Thread 2 unblock nhận lock $\rightarrow$ kiểm tra lại actor `admin_B` từ DB thấy role đã là `USER` $\rightarrow$ bị từ chối với 403 AccessDeniedException!
     - **Khẳng định DB:** `SELECT COUNT(*) FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE' == 1`.
   - **Test 6: Concurrent Promote & Demote:** Setup 2 Admin ACTIVE (`admin_A`, `admin_B`) và 1 User (`user_C`). `admin_A` nâng quyền `user_C` thành Admin, `admin_B` hạ quyền `admin_B` (sai - self demote) $\rightarrow$ `admin_A` hạ quyền `admin_B`. Cả 2 commit tuần tự; final count = 2 Admin ACTIVE (`admin_A`, `user_C`).
   - **Test 7: Concurrent Ban & Demote (`concurrentBanAndDemote_lastAdminProtected()`):**
     - **Setup kiểm thử chuẩn mực:** Khởi tạo chính xác **3 Admin ACTIVE** (`admin_A`, `admin_B`, `admin_C`).
     - Luồng 1: `actor: admin_A, target: admin_C`, Action: `DEMOTE` (`admin_C` $\rightarrow$ `USER`).
     - Luồng 2: `actor: admin_B, target: admin_C`, Action: `BAN` (`admin_C` $\rightarrow$ `BANNED`).
     - Cả hai actor đều là Admin ACTIVE độc lập và không tự thao tác lên chính mình.
     - Luồng 1 nhận lock trước $\rightarrow$ demote `admin_C` thành USER. Active admins còn 2 (`admin_A`, `admin_B`).
     - Luồng 2 unblock nhận lock $\rightarrow$ `admin_B` vẫn là Admin ACTIVE, target `admin_C` đã là USER $\rightarrow$ ban `user C` thành BANNED.
     - **Kết quả cuối cùng:** Số Admin ACTIVE là 2 (`admin_A`, `admin_B`), bảo vệ tuyệt đối không làm mất Admin cuối cùng!
   - **Test 8: Actor Loses Privilege While Waiting For Mutex (`actorLosesPrivilegeWhileWaitingForMutex_rejected()`):**
     - Admin A demote Admin B. Trong lúc đó, Admin B đang gửi request ban Admin C.
     - Khi Admin B nhận lock, worker kiểm tra lại DB thấy Admin B đã là `USER` $\rightarrow$ ném 403 Forbidden, hủy thao tác, bảo đảm Admin C không bị ban trái phép!

### 2.5. Kiểm duyệt Lịch trình Riêng tư (Private Itinerary Moderation Protocol)
- **Nguyên tắc phân định:**
  - `PUBLIC`: Lịch trình công khai, Admin có thể tra cứu và duyệt danh sách tự do.
  - `PRIVATE`: Chuyến đi cá nhân, Admin **không có danh sách duyệt tự do**.
- **Quy trình mở xem thanh tra Lịch trình PRIVATE:**
  - Endpoint `GET /api/admin/itineraries/{id}`:
    - Nếu lịch trình có `visibility == PRIVATE`: Request bắt buộc phải đính kèm query parameter `reportId` (Long) và `inspectionReason` (String, tối thiểu 10 ký tự).
    - Backend kiểm tra tính hợp lệ:
      1. Báo cáo `reportId` tồn tại trong bảng `post_reports` / `itinerary_reports` và đang ở trạng thái `PENDING`.
      2. Đối tượng bị báo cáo trong report khớp chính xác với `{id}` của lịch trình.
      3. Lý do thanh tra không được để trống.
    - Ghi nhận bắt buộc 1 bản ghi vào `audit_logs` với action `ITINERARY_PRIVATE_INSPECT` trong cùng transaction (`Propagation.REQUIRED`, `readOnly = false`). Nếu ghi log thất bại $\rightarrow$ rollback và **tuyệt đối không trả payload**.
    - Nếu không thỏa mãn: Ném lỗi **HTTP 403 Forbidden**.
  - Phạm vi quyền hạn: **Chỉ đọc (Read-Only Inspector)**. Admin tuyệt đối không có quyền chỉnh sửa tiêu đề, chi phí hay các hoạt động trong chuyến đi của người dùng.

### 2.6. Thiết kế Xử lý Tuần tự theo Lô cho Batch Resolve (Sequential Batch Processing)
- **Bản chất Backend & Idempotency:**
  - `PlaceAdministrativeAreaServiceImpl.batchResolveAndLink` là hàm xử lý **ĐỒNG BỘ 100% (Synchronous)**, nhận `BatchResolvePlacesRequest(dryRun, overwriteExisting, placeIds)` và trả về ngay `BatchLinkingReportResponse`.
  - **Tính Idempotency được bảo đảm:**
    - Khi `overwriteExisting = false`: Những địa điểm đã có `administrative_id != null` sẽ được tự động bỏ qua (`SKIPPED`).
    - Nếu request bị timeout ở tầng HTTP Gateway (504) nhưng Backend đã commit xong trong DB: Khi client gửi lại batch đó (hoặc retry), Backend sẽ kiểm tra thấy địa điểm đã có mã hành chính và an toàn bỏ qua, không gây nhân đôi hay sai lệch dữ liệu.
- **Thiết kế UI Slicing & Sequential Batching:**
  - Frontend Web Admin chia danh sách `placeIds` cần xử lý thành các lô tuần tự (chunk size 50 places/batch).
  - Vòng lặp gửi tuần tự từng batch lên server kèm thanh tiến độ trực quan:
    - `TOTAL`: Tổng số địa điểm cần xử lý.
    - `PROCESSED`: Số địa điểm đã qua xử lý.
    - `SUCCESS`: Số địa điểm đã liên kết thành công.
    - `FAILURE`: Số địa điểm gặp lỗi phân giải.
    - `SKIPPED`: Số địa điểm bị bỏ qua (do đã có mã và `overwriteExisting = false`).
    - `PENDING`: Số địa điểm còn lại trong hàng đợi.
  - **Cảnh báo Chế độ Dry-run:** Khi bật `dryRun = true`, giao diện hiển thị banner cảnh báo: "Kết quả xem trước (Dry-run) chỉ phản ánh trạng thái hiện thời của cơ sở dữ liệu. Dữ liệu địa giới hoặc tọa độ địa điểm có thể thay đổi trước khi thực thi ghi dữ liệu thực tế."
  - Hỗ trợ cơ chế Retry với tính đảm bảo Idempotent: gom danh sách các `placeId` bị thất bại để gửi lại trong một đợt retry riêng biệt.
  - Cây địa giới hiển thị trên UI nạp động hoàn toàn từ `/api/administrative-areas/**`, tuyệt đối không hardcode số lượng tỉnh/xã.

### 2.7. Thiết kế Lưu trữ, Chỉ mục & Bất biến cho Audit Log Engine
- **Chỉ mục phức hợp (Compound Indexes) tối ưu hóa truy vấn:**
  ```sql
  INDEX idx_audit_actor_created (actor_id, created_at DESC),
  INDEX idx_audit_action_created (action_type, created_at DESC),
  INDEX idx_audit_target_created (target_type, target_id, created_at DESC),
  INDEX idx_audit_created_at (created_at DESC)
  ```
- **Phân trang Ổn định (Stable Pagination):**
  - Mọi truy vấn phân trang nhật ký kiểm toán bắt buộc áp dụng thứ tự sắp xếp kép: `ORDER BY created_at DESC, log_id DESC` để bảo đảm tính tất định và không bị trôi/lặp bản ghi giữa các trang khi hệ thống có lượng log ghi dồn dập.
- **Tính Bất biến Tuyệt đối (Append-Only):**
  - Bảng `audit_logs` và `AdminAuditLogRepository` chỉ cung cấp `save` (INSERT) và `findAll` (SELECT).
  - Không cung cấp bất kỳ API cập nhật hoặc xóa log nào cho Admin.
- **Giới hạn Xuất Dữ liệu Bằng Projection / Streaming:**
  - Phân trang bắt buộc ở tầng máy chủ (mặc định 20, tối đa 50 bản ghi/trang).
  - Giới hạn cứng xuất file báo cáo (`AUDIT_EXPORT`): Tối đa 5,000 bản ghi mỗi lần xuất, sử dụng interface-based projection (`AuditLogExportProjection`) và streaming response xả bộ đệm liên tục để chống cạn kiệt bộ nhớ (OOM).
- **Chính sách Lưu trữ & Lưu kho Dữ liệu (Retention & Archiving):**
  - Dữ liệu trực tuyến lưu trữ 180 ngày trong bảng `audit_logs`.
  - Bản ghi cũ hơn 180 ngày được định kỳ chuyển sang kho lưu trữ lạnh (`audit_logs_archive` hoặc cold partition) bằng script bảo trì máy chủ chuyên dụng, không xóa tùy tiện.
  - Quản trị viên có thể tra cứu lịch sử lưu trữ qua bộ lọc khoảng thời gian mở rộng với quyền hạn được kiểm soát nghiêm ngặt.

---

## 3. CHI TIẾT 7 GIAI ĐOẠN TRIỂN KHAI

---

### GIAI ĐOẠN 1: AUDIT TRAIL CORE (HẠ TẦNG GHI NHẬN KIỂM TOÁN DÙNG CHUNG)

#### 1. Mục tiêu
- Xây dựng bảng `audit_logs`, entity, repository và dịch vụ dùng chung `AuditLogService` ở tầng Backend.
- Cung cấp hạ tầng ghi nhận bất biến cho các Phase tiếp theo (User, Itinerary, Area, Settings).
- Thiết lập cơ chế Transaction phân tầng: Strict Audit trong cùng transaction (`Propagation.REQUIRED`) cho mọi thao tác đột biến, kiểm tra riêng tư (`ITINERARY_PRIVATE_INSPECT`) và xuất nhật ký (`AUDIT_EXPORT`).
- Tích hợp bộ lọc Data Masking với Allowlist Snapshot DTOs và Denylist fallback.
- **Phạm vi: Backend Only. Tuyệt đối chưa làm giao diện Web ở Phase này.**

#### 2. Thiết kế Database
- **Tạo bảng `audit_logs`:**
  ```sql
  CREATE TABLE IF NOT EXISTS audit_logs (
      log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
      actor_id INT NOT NULL,
      actor_username VARCHAR(50) NOT NULL,
      action_type VARCHAR(50) NOT NULL,
      target_type VARCHAR(50) NOT NULL,
      target_id VARCHAR(100) NOT NULL,
      reason VARCHAR(255) NULL,
      result_status VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
      before_data_json TEXT NULL,
      after_data_json TEXT NULL,
      ip_address VARCHAR(45) NULL,
      user_agent VARCHAR(255) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_audit_actor_created (actor_id, created_at DESC),
      INDEX idx_audit_action_created (action_type, created_at DESC),
      INDEX idx_audit_target_created (target_type, target_id, created_at DESC),
      INDEX idx_audit_created_at (created_at DESC)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  ```
- **Kịch bản Rollback an toàn:** `DROP TABLE IF EXISTS audit_logs;`

#### 3. Thiết kế Backend
- `AuditLog` entity, `AuditActionType` enum:
  - `USER_BAN`, `USER_UNBAN`, `USER_ROLE_CHANGE`, `ITINERARY_MODERATE`, `ITINERARY_PRIVATE_INSPECT`, `POST_PURGE`, `REPORT_RESOLVE`, `SETTING_UPDATE`, `MAINTENANCE_TOGGLE`, `AUDIT_EXPORT`.
- `AuditLogRepository`: Kế thừa `JpaRepository<AuditLog, Long>` và `JpaSpecificationExecutor<AuditLog>`. Không hỗ trợ mutation query (`update`, `delete`).
- `DataMaskingUtil`: Allowlist DTO mapper kết hợp Denylist JSON cleaner.
- `AuditLogService` & `AuditLogServiceImpl`:
  - `void logStrictAction(...)`: Chạy trong transaction hiện tại (`Propagation.REQUIRED`). Nếu lỗi $\rightarrow$ rollback toàn bộ nghiệp vụ.

#### 4. Kế hoạch Kiểm thử & DoD Phase 1
- **Unit Tests:** `DataMaskingUtilTest` (kiểm tra allowlist, denylist, mask số điện thoại/email), `AuditLogServiceTest` (kiểm thử transaction rollback khi audit log gặp sự cố).
- **Integration Tests:** `AuditLogRepositoryTest` (kiểm thử chèn bản ghi, kiểm thử tính bất biến không thể cập nhật/xóa, kiểm thử hiệu năng chỉ mục và stable pagination).
- **DoD Phase 1:** Bảng `audit_logs` được tạo chuẩn xác; test suite đạt 100% pass; cơ chế atomic rollback hoạt động ổn định khi audit log lỗi.

---

### GIAI ĐOẠN 2: USER MANAGEMENT (QUẢN LÝ NGƯỜI DÙNG & BẢO VỆ PHIÊN)

#### 1. Mục tiêu
- Xây dựng hoàn chỉnh chức năng Quản lý Người dùng cả Backend lẫn Web UI.
- Danh sách, tìm kiếm, phân trang máy chủ, xem chi tiết hồ sơ tài khoản và danh sách phiên đăng nhập.
- Khóa (`BAN`) và mở khóa (`UNBAN`) tài khoản kèm lý do vi phạm bắt buộc; thu hồi toàn bộ phiên làm việc của user lập tức qua `token_version` và `user_sessions`.
- Phân quyền vai trò (`USER` ↔ `ADMIN`) với bảng độc lập `admin_role_guard`, kiến trúc tách 2 Spring Bean độc lập bọc `@Retryable` và `@Transactional(REQUIRES_NEW)`.
- Tải lại và tái xác thực Actor từ DB sau khi nhận lock, chống mất Admin cuối cùng và chặn tự khóa/hạ quyền chính mình.
- Bảo vệ 100% đường thay đổi role/status qua cùng một Mutex duy nhất.
- **Loại bỏ hoàn toàn form Đăng ký (`RegisterScreen`) khỏi Web Admin.**

#### 2. Thiết kế Database & Backend
- **Tạo bảng độc lập `admin_role_guard` (loại bỏ forward dependency với Phase 6):**
  ```sql
  CREATE TABLE IF NOT EXISTS admin_role_guard (
      guard_id INT PRIMARY KEY,
      guard_name VARCHAR(50) NOT NULL UNIQUE,
      locked_at DATETIME NULL,
      locked_by VARCHAR(50) NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

  INSERT INTO admin_role_guard (guard_id, guard_name) VALUES (1, 'ADMIN_ROLE_MUTEX')
  ON DUPLICATE KEY UPDATE guard_name = guard_name;
  ```
- Bổ sung index tối ưu truy vấn người dùng:
  ```sql
  CREATE INDEX idx_users_admin_filter ON users(role, status, created_at DESC);
  ```
- Tách 2 Spring Bean:
  - `AdminUserOrchestrationService`: `@Retryable(retryFor = {CannotAcquireLockException.class, PessimisticLockingFailureException.class})`.
  - `AdminUserTransactionalWorker`: `@Transactional(propagation = Propagation.REQUIRES_NEW, isolation = Isolation.READ_COMMITTED)`.
- `AdminUserController` tại `@RequestMapping("/api/admin/users")`, `@PreAuthorize("hasRole('ADMIN')")`:
  - `GET /api/admin/users` (Query: `keyword`, `role`, `status`, `page`, `size`, `sort`) $\rightarrow$ `PageResponse<UserAdminResponse>`.
  - `GET /api/admin/users/{id}` $\rightarrow$ `UserAdminDetailResponse`.
  - `PATCH /api/admin/users/{id}/status` $\rightarrow$ `UpdateUserStatusRequest` (`status`, `reason`).
  - `PATCH /api/admin/users/{id}/role` $\rightarrow$ `UpdateUserRoleRequest` (`role`, `reason`).
- Tích hợp gọi `auditLogService.logStrictAction(...)` trong cùng transaction (`Propagation.REQUIRED`).

#### 3. Thiết kế Frontend Web Admin
- `features/users/presentation/screens/admin_users_screen.dart`:
  - Tích hợp `AdminPageHeader`, `AdminToolbar` (search debounce, role & status filters).
  - `AdminDataTable`: Cột ID, Tên & Avatar, Handle, Email, Vai trò, Trạng thái, Ngày tạo, Thao tác.
- Dialogs: `UserDetailDialog`, `BanUserDialog`, `ChangeRoleDialog`.
- Loại bỏ liên kết/nút mở `RegisterScreen` trên `LoginScreen`.

#### 4. Kế hoạch Kiểm thử & DoD Phase 2
- **Concurrency Integration Tests (8 Tests Bắt buộc Chuẩn Mực):**
  1. `antiSelfDemotion_rejected()`
  2. `antiSelfBan_rejected()`
  3. `lastAdminDemotion_rejected()`
  4. `lastAdminBan_rejected()`
  5. `concurrentDemotion_actorPrivilegeMaintained_invariantMaintained()`
  6. `concurrentPromoteAndDemote_success()`
  7. `concurrentBanAndDemote_lastAdminProtected()` (Setup 3 Admin ACTIVE: `admin_A`, `admin_B`, `admin_C`).
  8. `actorLosesPrivilegeWhileWaitingForMutex_rejected()`
- **Session Revocation Test:** Kiểm thử tài khoản bị ban thì access token cũ bị chặn ngay ở request kế tiếp trên cả Mobile và Web.
- **Widget Tests:** Kiểm thử `AdminUsersScreen`, dialog khóa tài khoản, dialog đổi vai trò.
- **DoD Phase 2:** Quản lý người dùng hoạt động hoàn hảo; không thể tự khóa/hạ quyền chính mình; không thể mất Admin cuối cùng; form đăng ký bị loại bỏ.

---

### GIAI ĐOẠN 3: ITINERARY MODERATION (KIỂM DUYỆT VÒNG ĐỜI LỊCH TRÌNH)

#### 1. Mục tiêu
- Xây dựng chức năng Kiểm duyệt Lịch trình du lịch toàn hệ thống ở chế độ Chỉ đọc (Read-Only) kết hợp Kiểm duyệt trạng thái (`HIDDEN`/`ACTIVE`).
- Thiết lập quy trình thanh tra lịch trình riêng tư (`PRIVATE`) có điều kiện qua `reportId`, lý do tối thiểu 10 ký tự, và ghi nhận Strict Audit Log bắt buộc trong transaction `readOnly = false` (nếu ghi log lỗi $\rightarrow$ không trả payload).
- Bảo vệ quyền riêng tư người dùng: Admin tuyệt đối không chỉnh sửa nội dung chuyến đi.

#### 2. Thiết kế Database & Backend
- Database: Bảng `itineraries` giữ nguyên cấu trúc. Bổ sung index:
  ```sql
  CREATE INDEX idx_itineraries_admin_query ON itineraries(status, visibility, created_at DESC);
  ```
- `AdminItineraryController` tại `@RequestMapping("/api/admin/itineraries")`, `@PreAuthorize("hasRole('ADMIN')")`:
  - `GET /api/admin/itineraries`: Danh sách lịch trình công khai có phân trang và bộ lọc.
  - `GET /api/admin/itineraries/{id}`: Xem chi tiết read-only. Nếu `visibility == PRIVATE`, kiểm tra bắt buộc `reportId` (trạng thái PENDING và trỏ đúng itinerary) và `inspectionReason`. Ghi nhận Strict Audit Log trước khi trả dữ liệu.
  - `PATCH /api/admin/itineraries/{id}/moderate`: Ẩn hoặc khôi phục lịch trình kèm lý do vi phạm. Ghi nhận `audit_logs` cùng transaction (`Propagation.REQUIRED`).
- DTOs: `ItineraryAdminResponse`, `ItineraryAdminDetailResponse`, `ModerateItineraryRequest`.

#### 3. Thiết kế Frontend Web Admin
- `features/itineraries/presentation/screens/admin_itineraries_screen.dart`:
  - Toolbar lọc trạng thái (`ACTIVE`, `HIDDEN`), lọc hiển thị, tìm kiếm từ khóa.
  - `AdminDataTable` hiển thị đầy đủ thông tin chuyến đi.
- `ItineraryDetailDialog`: Chế độ chỉ đọc, xem timeline ngày, danh sách hoạt động, bản đồ lộ trình mini. Không có nút chỉnh sửa nội dung.
- `ModerateItineraryDialog`: Hộp thoại ẩn/khôi phục kèm trường nhập lý do vi phạm.

#### 4. Kế hoạch Kiểm thử & DoD Phase 3
- **Security & Privacy Tests:** Kiểm thử từ chối truy cập lịch trình PRIVATE khi thiếu `reportId` hoặc lý do; kiểm thử không trả dữ liệu khi audit log bị ngắt kết nối; kiểm thử ném lỗi khi cố tình gửi payload chỉnh sửa hoạt động.
- **Mobile Compatibility Tests:** Kiểm thử Feed Khám phá trên mobile tự động loại trừ lịch trình bị ẩn; tác giả vẫn nhìn thấy chuyến đi trong profile cá nhân kèm cảnh báo vi phạm.
- **DoD Phase 3:** Màn hình lịch trình hoạt động tốt; tôn trọng quyền riêng tư người dùng; không làm ảnh hưởng tính năng Mobile.

---

### GIAI ĐOẠN 4: ADMINISTRATIVE AREAS (GIAO DIỆN QUẢN LÝ ĐƠN VỊ HÀNH CHÍNH)

#### 1. Mục tiêu
- Xây dựng giao diện Quản lý Đơn vị Hành chính (`AdminAdministrativeAreasScreen`) dựa trên 5 API Backend hiện có tại `AdminPlaceAdministrativeAreaController` và các API tra cứu public.
- Cung cấp cây phân cấp địa giới hiển thị động (không hardcode số lượng tỉnh/xã trên UI).
- Cung cấp công cụ Batch Resolve xử lý tuần tự theo lô (Sequential Batching, chunk size 50 places) kèm giao diện trực quan và báo cáo kết quả chi tiết.
- Hỗ trợ chế độ chạy thử an toàn `dryRun = true` có banner cảnh báo và cơ chế Retry bảo đảm tính Idempotent cho các địa điểm thất bại.
- Tích hợp công cụ gán mã hành chính trực tiếp vào màn hình Quản lý Địa điểm (`AdminPlacesScreen`).

#### 2. Thiết kế Database & Backend
- Database: Không thay đổi schema.
- Backend: Bổ sung 1 endpoint thống kê tỷ lệ liên kết tại `AdminPlaceAdministrativeAreaController`:
  - `GET /api/admin/places/administrative-area/stats` $\rightarrow$ `{"totalPlaces": ..., "linkedPlaces": ..., "unlinkedPlaces": ..., "coveragePercentage": ...}`.
- Tái sử dụng `POST /api/admin/places/administrative-area/batch-resolve` theo đúng bản chất đồng bộ (Synchronous).

#### 3. Thiết kế Frontend Web Admin
- `features/administrative_areas/presentation/screens/admin_administrative_areas_screen.dart`:
  - Dải KPI độ bao phủ địa lý nạp từ API `/stats`.
  - Cây danh mục 34 tỉnh/thành phố nạp động từ `/api/administrative-areas/provinces`; khi nhấp vào tỉnh thì gọi `/api/administrative-areas/{code}/children` để hiển thị xã/phường. **Tuyệt đối không hardcode số lượng đơn vị hành chính trong UI.**
  - `BatchResolvePanel`: Khung điều khiển chia lô tuần tự (chunk 50), hỗ trợ bật/tắt `dryRun`, `overwriteExisting`, hiển thị tiến độ 6 trạng thái (`TOTAL`, `PROCESSED`, `SUCCESS`, `FAILURE`, `SKIPPED`, `PENDING`), banner cảnh báo dryRun và nút Retry cho các địa điểm thất bại.
- `PlaceAdministrativeAreaDialog`: Tích hợp vào `AdminPlacesScreen` cho phép xem trước và gán mã thủ công (tuân thủ Nghị quyết 388).

#### 4. Kế hoạch Kiểm thử & DoD Phase 4
- **Backend Tests:** Kiểm thử API stats; kiểm thử xử lý batch-resolve cho danh sách `placeIds`; kiểm thử tính idempotent khi gọi lại batch đã liên kết.
- **Widget Tests:** Kiểm thử nạp động cây tỉnh/xã; kiểm thử modal chạy batch-resolve tuần tự theo lô; kiểm thử hiển thị tiến độ và cơ chế retry.
- **DoD Phase 4:** Màn hình đơn vị hành chính hiển thị đầy đủ cây địa giới động; chạy Batch Resolve và hiển thị kết quả thành công; tích hợp gán mã trên Places Screen hoàn tất.

---

### GIAI ĐOẠN 5: AUDIT LOGS UI (GIAO DIỆN KHÁM PHÁ NHẬT KÝ KIỂM TOÁN)

#### 1. Mục tiêu
- Xây dựng giao diện tra cứu và kiểm toán chuyên sâu cho Nhật ký Hoạt động (`AdminTab.auditLogs`).
- Cho phép Quản trị viên truy vết mọi hành vi nhạy cảm đã diễn ra trong hệ thống: ai đã thực hiện, vào lúc nào, từ IP nào, lý do là gì, và dữ liệu trước/sau thay đổi (Before/After Diff) đã được che chắn thông tin nhạy cảm.
- Bảo đảm tính bất biến: Quản trị viên thông thường không có quyền chỉnh sửa hoặc xóa nhật ký.
- Cung cấp tính năng Xuất file kiểm toán có giới hạn cứng (tối đa 5,000 dòng) với `Export ID` và quy trình phân định (`SUCCESS` / `DELIVERY_FAILED` / `FAILED` vs `AUDIT_PERSISTENCE_FAILED`).
- Bảo vệ dọn dẹp file tạm: `finally` xóa ngay sau khi stream; Cron chỉ dọn file mồ côi > 2 giờ, không xóa file đang stream.

#### 2. Thiết kế Database & Backend
- Database: Tái sử dụng bảng `audit_logs` đã xây dựng từ Phase 1.
- Backend xây dựng `AdminAuditLogController` tại `@RequestMapping("/api/admin/audit-logs")`, `@PreAuthorize("hasRole('ADMIN')")`:
  - `GET /api/admin/audit-logs` (Query: `actorId`, `actionType`, `targetType`, `fromDate`, `toDate`, `page`, `size`, `sort`) $\rightarrow$ `PageResponse<AuditLogResponse>` (sắp xếp mặc định: `created_at DESC, log_id DESC`).
  - `GET /api/admin/audit-logs/{id}` $\rightarrow$ `AuditLogDetailResponse`.
  - `GET /api/admin/audit-logs/action-types` $\rightarrow$ `List<String>`.
  - `GET /api/admin/audit-logs/export` $\rightarrow$ Xuất dữ liệu kiểm toán định dạng CSV hoặc JSON (giới hạn cứng max 5,000 dòng theo quy trình chuẩn hóa có `Export ID`).
- Không cung cấp bất kỳ API mutation nào (`POST`, `PUT`, `DELETE`).

#### 3. Thiết kế Frontend Web Admin
- `features/audit_logs/presentation/screens/admin_audit_logs_screen.dart`:
  - Toolbar lọc đa chiều: Dropdown loại hành động, ô tìm kiếm Actor/TargetId, bộ chọn khoảng thời gian, nút xuất file.
  - `AdminDataTable`: Cột ID, Thời gian, Người thực hiện, Hành động (`AdminStatusBadge`), Đối tượng, Mã đối tượng, Địa chỉ IP, Trạng thái, Thao tác.
- `AuditLogDetailDialog`: Modal hiển thị chi tiết ngữ cảnh và khung JSON diff so sánh Before / After với dữ liệu đã được mask an toàn.

#### 4. Kế hoạch Kiểm thử & DoD Phase 5
- **Backend Tests:** Kiểm thử phân trang ổn định (stable pagination); kiểm thử giới hạn xuất 5,000 bản ghi; kiểm tra quy trình xuất file ghi audit log trước khi cho phép tải; kiểm thử ghi nhận `DELIVERY_FAILED` khi client ngắt kết nối; kiểm tra không có endpoint mutation nào tồn tại.
- **Widget Tests:** Kiểm thử render bảng audit logs, kiểm thử đổi filter hành động, mở modal xem JSON diff.
- **DoD Phase 5:** Toàn bộ lịch sử thao tác từ Phase 1 đến Phase 4 hiển thị chính xác; dữ liệu nhạy cảm hiển thị `***MASKED***`; không có hành động sửa/xóa log.

---

### GIAI ĐOẠN 6: SYSTEM SETTINGS (CẤU HÌNH NGHIỆP VỤ ĐỘNG & BẢO TRÌ AN TOÀN)

#### 1. Mục tiêu
- Xây dựng phân hệ Cài đặt Hệ thống (`AdminTab.settings`) cho các tham số nghiệp vụ có thể thay đổi động trong quá trình vận hành mà không cần khởi động lại máy chủ.
- Thiết lập ranh giới bảo mật nghiêm ngặt: Tuyệt đối không đưa bí mật hệ thống (Secret Keys, Passwords, Database Credentials) lên giao diện. Bảng `system_settings` chỉ chứa cấu hình nghiệp vụ, không bị lẫn lộn dòng khóa kỹ thuật.
- Minh định rõ ràng: Giới hạn Servlet Multipart 5MB là tĩnh (ở JVM level), trong khi cấu hình động `MEDIA_MAX_IMAGE_SIZE_MB` là ngưỡng nghiệp vụ kiểm tra bổ sung (phải $\le 5\text{MB}$).
- Thứ tự filter an toàn: `CorsFilter` (OPTIONS preflight 200 OK) $\rightarrow$ `JwtAuthenticationFilter` $\rightarrow$ `MaintenanceModeFilter` (kiểm tra `ROLE_ADMIN` để bypass).

#### 2. Phân nhóm Cấu hình Nghiệp vụ Cho phép
1. **Chính sách Kiểm duyệt Cộng đồng:** Ngưỡng số báo cáo vi phạm để tự động ẩn bài viết (`MODERATION_AUTO_HIDE_THRESHOLD`, int, 1 - 50, mặc định: 5).
2. **Chuẩn hóa Địa lý:** Ngưỡng độ tin cậy tối thiểu để tự động liên kết địa giới (`GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD`, double, 0.50 - 1.00, mặc định: 0.85).
3. **Giới hạn Tài nguyên Nghiệp vụ:** Dung lượng tệp ảnh tải lên tối đa hiển thị gợi ý cho client (`MEDIA_MAX_IMAGE_SIZE_MB`, int, 1 - 5 MB, mặc định: 2). UI ghi rõ: không thể vượt quá giới hạn Servlet Container 5MB mà không khởi động lại server.
4. **Chế độ Bảo trì:** Cờ bảo trì toàn cục (`SYSTEM_MAINTENANCE_MODE`, boolean, mặc định: false) và thông điệp thông báo (`SYSTEM_MAINTENANCE_MESSAGE`).

#### 3. Thiết kế Database & Backend
- **Tạo bảng `system_settings`:**
  ```sql
  CREATE TABLE IF NOT EXISTS system_settings (
      setting_key VARCHAR(100) PRIMARY KEY,
      setting_value TEXT NOT NULL,
      setting_group VARCHAR(50) NOT NULL,
      description VARCHAR(255) NULL,
      value_type VARCHAR(20) NOT NULL DEFAULT 'STRING',
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      updated_by VARCHAR(50) NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  ```
- `SystemSettingService`: Quản lý đọc/ghi cấu hình có bộ nhớ đệm (In-memory Cache), hàm làm mới cache khi có cập nhật.
- `MaintenanceModeFilter`: Đặt sau `JwtAuthenticationFilter`, kiểm tra `ROLE_ADMIN` để bypass bảo trì an toàn.
- `AdminSettingsController` tại `@RequestMapping("/api/admin/settings")`, `@PreAuthorize("hasRole('ADMIN')")`:
  - `GET /api/admin/settings` $\rightarrow$ Danh sách cấu hình theo nhóm (loại trừ các key nhạy cảm).
  - `PUT /api/admin/settings/{key}` $\rightarrow$ Cập nhật 1 cấu hình kèm kiểm tra validation min/max.
- Ghi nhận `audit_logs` bắt buộc trong cùng transaction (`Propagation.REQUIRED`).

#### 4. Thiết kế Frontend Web Admin
- `features/settings/presentation/screens/admin_settings_screen.dart`:
  - Bố cục các phân đoạn cấu hình Swiss Minimalist.
  - Switch toggle cho chế độ bảo trì kèm hộp thoại cảnh báo nguy cơ ảnh hưởng toàn hệ thống.
  - Number fields có validation min/max cho ngưỡng kiểm duyệt và dung lượng ảnh (giới hạn tối đa 5MB).
  - Nút `[Lưu cấu hình]` có loading state và thông báo kết quả.

#### 5. Kế hoạch Kiểm thử & DoD Phase 6
- **Security & Bypass Tests:** Kiểm thử khi bật bảo trì: user thường nhận 503; request không có token nhận 503; Admin đã xác thực bypass thành công; endpoint `/api/health` và `/api/auth/login` vẫn hoạt động bình thường; request CORS OPTIONS preflight nhận 200 OK.
- **Validation Tests:** Kiểm thử cập nhật cấu hình vượt ngoài phạm vi giá trị cho phép (ví dụ upload > 5MB) bị từ chối với lỗi 400.
- **DoD Phase 6:** Cấu hình động cập nhật thành công và có hiệu lực ngay tại backend; Admin bypass bảo trì an toàn; không lộ bất kỳ bí mật hệ thống nào.

---

### GIAI ĐOẠN 7: DASHBOARD V2 (BẢNG ĐIỀU KHIỂN VẬN HÀNH TOÀN DIỆN & THỐNG KÊ TỔNG HỢP)

#### 1. Mục tiêu
- Nâng cấp Bảng điều khiển Tổng quan (`AdminDashboardScreen`) lên phiên bản Enterprise Dashboard v2 sau khi toàn bộ các module chính (User, Itinerary, Area, Audit, Settings) đã có dữ liệu thật.
- Thay thế hoàn toàn cơ chế gọi 5 API đếm rời rạc bằng **1 API Thống kê Tổng hợp duy nhất (`GET /api/admin/dashboard/summary`)**, tối ưu hóa hiệu năng và giảm 80% số lượng request khi tải trang.
- Bổ sung biểu đồ tăng trưởng thời gian thực và dòng hoạt động quản trị gần nhất dựa trên dữ liệu thật (nói KHÔNG với số liệu giả).

#### 2. Phạm vi Chức năng
- **Dải chỉ số Vận hành Toàn diện (6 nhóm số liệu cốt lõi):**
  1. Người dùng: Tổng tài khoản, tài khoản hoạt động, tài khoản bị khóa (`BANNED`).
  2. Địa điểm: Tổng địa điểm chuẩn hóa, số địa điểm đang hoạt động, tỷ lệ đã gán mã hành chính (%).
  3. Lịch trình: Tổng lịch trình, lịch trình công khai, số lịch trình bị ẩn do vi phạm (`HIDDEN`).
  4. Bài viết: Tổng bài viết cộng đồng, bài viết đã ẩn kiểm duyệt.
  5. Báo cáo vi phạm: Số lượng báo cáo đang chờ xử lý (`PENDING`) kèm màu cảnh báo Rausch.
  6. Tài nguyên Media: Tổng ảnh lưu trữ Cloudinary, số lượng ảnh lỗi/dead-letter.
- **Biểu đồ Tăng trưởng Thực tế (Real-Data Growth Charts):**
  - Biểu đồ số lượng người dùng mới đăng ký theo ngày trong 30 ngày gần nhất.
  - Biểu đồ bài viết cộng đồng chia sẻ theo tuần.
- **Dòng hoạt động Quản trị gần đây (Recent Audit Trail Feed):**
  - Hiển thị 5 hoạt động quản trị mới nhất từ bảng `audit_logs` (thời gian, quản trị viên, hành động, đối tượng tác động).

#### 3. Thiết kế Backend & Frontend
- Tạo mới `AdminDashboardController` tại `@RequestMapping("/api/admin/dashboard")`, `@PreAuthorize("hasRole('ADMIN')")`:
  - `GET /api/admin/dashboard/summary` $\rightarrow$ `AdminDashboardSummaryResponse`.
  - `GET /api/admin/dashboard/analytics` $\rightarrow$ `AdminAnalyticsResponse`.
- Frontend refactor `DashboardRepository` và `AdminDashboardScreen` chuyển sang gọi endpoint summary gộp.

#### 4. Kế hoạch Kiểm thử & DoD Phase 7
- **Performance & Integration Tests:** Kiểm tra API summary trả về dữ liệu chuẩn xác trong < 200ms; kiểm thử chuyển hướng từ các thẻ KPI đến các tab tương ứng.
- **DoD Phase 7:** Dashboard tải tức thời với 1 request duy nhất; hiển thị đầy đủ số liệu thực của toàn bộ hệ thống; toàn bộ 11 Sidebar Tabs trên Web Admin đều có chức năng thật 100%, không còn bất kỳ màn hình `PlaceholderFeatureView` nào.

---

## 4. MA TRẬN TIẾN ĐỘ & PHỤ THUỘC GIỮA 7 GIAI ĐOẠN

| Phase | Tên Giai đoạn | Trọng tâm Triển khai | Phụ thuộc Trước | Ưu tiên | Khối lượng Dự kiến |
|:---:|---|---|:---:|:---:|:---:|
| **Phase 1** | **Audit Trail Core** | Bảng `audit_logs`, `AuditLogService`, Allowlist DTOs, Strict REQUIRED Transaction (Backend only) | *Không có* | **P0 (Bắt buộc đầu tiên)** | Vừa (Backend only) |
| **Phase 2** | **User Management** | `AdminUserController`, Màn hình Users, Ban/Role, Bảng `admin_role_guard`, Tách 2 Bean Retry/Tx, Revoke session | Phase 1 | **P1 (Nghiệp vụ cốt lõi)** | Lớn (Backend + Web) |
| **Phase 3** | **Itinerary Moderation** | `AdminItineraryController`, Màn hình Itineraries, Ẩn/Khôi phục, Quy trình PRIVATE có Strict Audit | Phase 1 | **P1 (Nghiệp vụ cốt lõi)** | Vừa (Backend + Web) |
| **Phase 4** | **Administrative Areas** | Màn hình Admin Areas, Cây 34 tỉnh/xã động, Batch Resolve tuần tự theo lô (chunk 50), dryRun, Retry | Phase 1 | **P1 (Nghiệp vụ cốt lõi)** | Vừa (Chủ yếu Web) |
| **Phase 5** | **Audit Logs UI** | Màn hình Audit Logs, Bộ lọc đa chiều, Xem JSON diff đã mask, Xuất file phân định 3 trạng thái + bảo vệ cleanup | Phase 1 - 4 | **P2 (Giám sát vận hành)** | Vừa (Backend + Web) |
| **Phase 6** | **System Settings** | Bảng `system_settings`, Màn hình Cài đặt, Servlet limit vs Dynamic hint, Thứ tự Cors/Jwt/Maintenance Filter | Phase 1 | **P2 (Giám sát vận hành)** | Nhỏ - Vừa |
| **Phase 7** | **Dashboard v2** | `AdminDashboardController`, Gộp 1 API summary, Biểu đồ tăng trưởng thực tế | Phase 1 - 6 | **P3 (Hoàn thiện tổng thể)**| Vừa (Tối ưu hóa) |

---

## 5. ĐỊNH NGHĨA HOÀN THÀNH (DEFINITION OF DONE - DOD) CHO MỖI PHASE

Một Phase chỉ được coi là hoàn thành và được phép nghiệm thu khi đáp ứng đầy đủ 10 tiêu chí DoD:
1. **Source Code Cleanliness:** `flutter analyze` trả về 0 issues; Maven build Spring Boot biên dịch thành công 0 warnings.
2. **Design System Compliance:** Tuân thủ 100% `admin-design-system.md` (nền canvas `#FFFFFF`, viền hairline 1px `#E2E8F0`, bo góc 4px, 0 shadow, 0 gradient, màu nhận diện Rausch `#FF385C` và độ tương phản WCAG 2.1 AA `#D90740`).
3. **Data Integrity & Real API:** Không có mock data hoặc hardcoded lists; toàn bộ dữ liệu hiển thị phải đến từ REST API thật của Spring Boot. Cây địa giới nạp động từ database.
4. **State Handling:** Mọi màn hình và dialog phải xử lý đầy đủ 4 trạng thái giao diện: Đang tải (`loading`), Dữ liệu rỗng (`empty`), Có lỗi phát sinh (`error` kèm nút thử lại) và Thành công (`success`).
5. **Server-Side Pagination:** Bảng dữ liệu có phân trang máy chủ đồng bộ với backend Pageable metadata, tự động reset về trang 0 khi thay đổi bộ lọc tìm kiếm. Sắp xếp nhật ký ổn định `created_at DESC, log_id DESC`.
6. **Security & Authorization:** Endpoint quản trị được bảo vệ bởi `@PreAuthorize("hasRole('ADMIN')")`; kiểm tra quyền trên server; chặn truy cập trái phép.
7. **Strict Audit Logging Integration:** Mọi thao tác quản trị ghi/sửa/xóa, mở xem thanh tra lịch trình riêng tư và xuất file đều được ghi tự động vào `audit_logs` với transaction boundary nguyên tử (`Propagation.REQUIRED`). Nếu ghi audit thất bại $\rightarrow$ rollback toàn bộ và không trả dữ liệu.
8. **Mobile Backward Compatibility:** Không làm thay đổi hay phá vỡ hành vi hiện tại của Flutter Mobile App; các API và bảng dùng chung được bảo toàn.
9. **Automated Test Coverage:** Có đầy đủ Unit Tests, Integration Tests, Concurrency Tests, và Widget Tests cho các service/controller/màn hình mới; toàn bộ test suite pass 100%.
10. **English Development Log:** Cập nhật mục mới vào `docs/ai/09-development-log.md` bằng tiếng Anh kỹ thuật chuyên nghiệp theo đúng hướng dẫn của `AGENTS.md`.
