# MA TRẬN TRUY VẾT CHỨC NĂNG QUẢN TRỊ ADMIN (ADMIN FUNCTIONALITY TRACEABILITY MATRIX)
## ĐỒNG BỘ CHUỖI 11 MẮT XÍCH & LỘ TRÌNH 7 GIAI ĐOẠN (FINAL EDGE-CASE PATCH)

**Mã tài liệu:** `docs/plan/38-admin-functionality-traceability-matrix.md`  
**Dự án:** Travel Planner Community Platform  
**Ngày cập nhật:** 25/11/2026 (Final Edge-Case Patch)  
**Trạng thái:** Kế hoạch & Rà soát Truy vết (Traceability Refinement — Read-Only)  
**Tài liệu liên quan:**
- `docs/plan/36-admin-functionality-comprehensive-audit.md` (Báo cáo Kiểm toán Toàn diện)
- `docs/plan/37-admin-functionality-implementation-roadmap.md` (Lộ trình Triển khai 7 Phase)

---

## 1. HƯỚNG DẪN ĐỌC MA TRẬN TRUY VẾT

Ma trận này truy vết dòng chảy logic khép kín từ Giao diện Quản trị viên đến Tầng Dữ liệu và Kiểm thử qua **chuỗi 11 mắt xích kiến trúc chuẩn mực**:
$$\text{Chức năng} \longrightarrow \text{Sidebar Tab} \longrightarrow \text{Route Path} \longrightarrow \text{Screen \& Dialog} \longrightarrow \text{Repository} \longrightarrow \text{REST API} \longrightarrow \text{Controller} \longrightarrow \text{Service} \longrightarrow \text{Entity / DB} \longrightarrow \text{Permission} \longrightarrow \text{Tests}$$

### Ký hiệu quy ước trạng thái:
- `[EXISTS - VERIFIED]`: Mắt xích đã tồn tại trong mã nguồn thực tế, đã được kiểm chứng hoạt động tốt với automated tests.
- `[EXISTS - REFACTOR]`: Mắt xích đã có giao diện ban đầu nhưng cần tái cấu trúc hoặc nâng cấp API gộp tối ưu hiệu năng tại Phase 7.
- `[PLANNED Phase X]`: Mắt xích đã được lên kế hoạch xây dựng chi tiết tại Phase X (từ Phase 1 đến Phase 7).
- `[MISSING]`: Mắt xích chưa tồn tại trong mã nguồn hiện tại, là khoảng trống kỹ thuật cần bổ sung trong phase tương ứng.

---

## 2. MA TRẬN TRUY VẾT TOÀN BỘ 42 CHỨC NĂNG QUẢN TRỊ

### PHẦN I: XÁC THỰC, PHÂN QUYỀN & HỒ SƠ QUẢN TRỊ (6 CHỨC NĂNG)

| STT | Chức năng Quản trị | Sidebar Tab | Route Path | Frontend Screen & Dialog | Frontend Repository | Backend REST API | Backend Controller | Backend Service & Impl | Entity & DB Table | Quyền Hạn (Permission) | Automated Tests | Trạng thái & Kế hoạch |
|:---:|---|---|---|---|---|---|---|---|---|---|---|:---:|
| **1.1** | **Đăng nhập Quản trị viên** | *(Khung Auth ngoài Shell)* | `/login` | `LoginScreen` ([#L1-L240](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/auth/presentation/screens/login_screen.dart)) | `AuthRepository:login` | `POST /api/auth/login` | `AuthController` | `AuthServiceImpl:login`<br>`UserSessionServiceImpl` | `User`, `UserSession`<br>(`users`, `user_sessions`) | Public (`permitAll()`), kiểm tra `role == ADMIN` | `AuthControllerTest`<br>`auth_401_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **1.2** | **Đăng xuất máy chủ & Xóa phiên** | Top Header & Sidebar Bottom | N/A (Action) | `AdminHeader`, `AdminSidebar` | `AuthNotifier:logout` | `POST /api/auth/logout` | `AuthController` | `AuthServiceImpl:logout`<br>`UserSessionServiceImpl:revoke` | `UserSession`<br>(`user_sessions`) | Authenticated | `AuthControllerTest`<br>`widget_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **1.3** | **Kiểm tra phiên & Token Guard** | Shell Root Gatekeeper | Mọi route | `AdminShell:isAdmin` ([#L42-L46](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart#L42-L46)) | `AuthNotifier:checkAuthStatus` | `GET /api/auth/me` | `AuthController` | `UserDetailsServiceImpl`<br>`JwtTokenProvider` | `User`<br>(`users.token_version`) | `ROLE_ADMIN`<br>Token JWT valid | `AuthSecurityUnitTest`<br>`admin_phase6_final_consistency_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **1.4** | **Xem hồ sơ cá nhân Admin** | `Hồ sơ cá nhân` (`AdminTab.profile`) | `/profile` | `ProfileScreen` ([#L1-L658](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/profile/presentation/screens/profile_screen.dart)) | `ProfileRepository:getProfile` | `GET /api/user/profile` | `ProfileController` | `ProfileServiceImpl:getProfile` | `User`<br>(`users`) | Authenticated (Admin/User) | `admin_phase6_final_consistency_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **1.5** | **Cập nhật hồ sơ cá nhân Admin** | `Hồ sơ cá nhân` (`AdminTab.profile`) | `/profile` | `ProfileScreen` (Edit Form) | `ProfileRepository:updateProfile` | `PUT /api/user/profile` | `ProfileController` | `ProfileServiceImpl:updateProfile` | `User`<br>(`users`) | Authenticated (Admin/User) | `admin_phase6_final_consistency_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **1.6** | **Loại bỏ form Đăng ký tự do** | N/A (Bảo mật Auth) | `/register` | `RegisterScreen` [EXISTS -> CẦN ẨN] | `AuthRepository:register` | `POST /api/auth/register` | `AuthController` | `AuthServiceImpl:register` | `User` (luôn gán `Role.USER`) | Public [LỖ HỔNG CẦN KHẮC PHỤC] | `admin_phase6_final_consistency_test.dart` | **PLANNED Phase 2** |

---

### PHẦN II: HẠ TẦNG GHI NHẬN KIỂM TOÁN DÙNG CHUNG (2 CHỨC NĂNG)

| STT | Chức năng Quản trị | Sidebar Tab | Route Path | Frontend Screen & Dialog | Frontend Repository | Backend REST API | Backend Controller | Backend Service & Impl | Entity & DB Table | Quyền Hạn (Permission) | Automated Tests | Trạng thái & Kế hoạch |
|:---:|---|---|---|---|---|---|---|---|---|---|---|:---:|
| **2.1** | **Hạ tầng ghi nhận Audit Trail Core Engine** | N/A (Tầng hạ tầng Backend) | N/A | Gọi nội bộ từ các Admin Services | N/A | Không có API trực tiếp | N/A | `AuditLogServiceImpl:logStrictAction` [MISSING] | `AuditLog`<br>(`audit_logs`) [MISSING] | Internal Component (`Propagation.REQUIRED`, Append-Only) | `AuditLogServiceTest`<br>`AuditLogRepositoryTest` [PLANNED Phase 1] | **PLANNED Phase 1** |
| **2.2** | **Bộ lọc Data Masking & Allowlist Snapshot DTOs** | N/A (Tầng hạ tầng Backend) | N/A | Tự động xử lý Before/After snapshot | N/A | N/A | N/A | `DataMaskingUtil:maskJson` [MISSING] | Không lưu secret vào DB | Internal Component | `DataMaskingUtilTest` [PLANNED Phase 1] | **PLANNED Phase 1** |

---

### PHẦN III: QUẢN LÝ NGƯỜI DÙNG (5 CHỨC NĂNG)

| STT | Chức năng Quản trị | Sidebar Tab | Route Path | Frontend Screen & Dialog | Frontend Repository | Backend REST API | Backend Controller | Backend Service & Impl | Entity & DB Table | Quyền Hạn (Permission) | Automated Tests | Trạng thái & Kế hoạch |
|:---:|---|---|---|---|---|---|---|---|---|---|---|:---:|
| **3.1** | **Danh sách người dùng phân trang & lọc** | `Quản lý người dùng` (`AdminTab.users`) | `/users` | `PlaceholderFeatureView` [THAY THẾ BỞI `AdminUsersScreen`] | `UserAdminRepository:getUsers` [MISSING] | `GET /api/admin/users` [MISSING] | `AdminUserController` [MISSING] | `AdminUserServiceImpl:getUsers` [MISSING] | `User`<br>(`users`) | `ROLE_ADMIN` | `admin_users_phase2_test.dart` [PLANNED Phase 2] | **PLANNED Phase 2** |
| **3.2** | **Xem chi tiết quản trị người dùng & phiên** | `Quản lý người dùng` (`AdminTab.users`) | `/users` | `UserDetailDialog` [MISSING] | `UserAdminRepository:getUserDetail` [MISSING] | `GET /api/admin/users/{id}` [MISSING] | `AdminUserController` [MISSING] | `AdminUserServiceImpl:getUserDetail` [MISSING] | `User`, `UserSession`, `Itinerary`, `Post` | `ROLE_ADMIN` | Unit & Integration Tests [PLANNED Phase 2] | **PLANNED Phase 2** |
| **3.3** | **Khóa tài khoản (`BAN`) & Thu hồi phiên** | `Quản lý người dùng` (`AdminTab.users`) | `/users` | `BanUserDialog` [MISSING] | `UserAdminRepository:updateStatus` [MISSING] | `PATCH /api/admin/users/{id}/status` [MISSING] | `AdminUserController` [MISSING] | `AdminUserOrchestrationService:updateUserStatusWithRetry`<br>`AdminUserTransactionalWorker`<br>`UserSessionService:revokeAllSessions` [EXISTS] | `User.status`, `token_version`, `user_sessions`, `admin_role_guard`, `audit_logs` | `ROLE_ADMIN`<br>(Chặn tự khóa, `admin_role_guard` Mutex, @Retryable, Tái xác thực Actor) | Integration & Guard Tests (8 tests) [PLANNED Phase 2] | **PLANNED Phase 2** |
| **3.4** | **Mở khóa tài khoản (`UNBAN`)** | `Quản lý người dùng` (`AdminTab.users`) | `/users` | `UnbanUserDialog` [MISSING] | `UserAdminRepository:updateStatus` [MISSING] | `PATCH /api/admin/users/{id}/status` [MISSING] | `AdminUserController` [MISSING] | `AdminUserOrchestrationService`<br>`AdminUserTransactionalWorker` [MISSING] | `User.status = ACTIVE`, `audit_logs` | `ROLE_ADMIN` (Strict Audit) | Unit & Widget Tests [PLANNED Phase 2] | **PLANNED Phase 2** |
| **3.5** | **Điều chỉnh vai trò (`USER` ↔ `ADMIN`)** | `Quản lý người dùng` (`AdminTab.users`) | `/users` | `ChangeRoleDialog` [MISSING] | `UserAdminRepository:updateRole` [MISSING] | `PATCH /api/admin/users/{id}/role` [MISSING] | `AdminUserController` [MISSING] | `AdminUserOrchestrationService:updateUserRoleWithRetry`<br>`AdminUserTransactionalWorker` [MISSING] | `User.role`, `admin_role_guard`, `audit_logs` | `ROLE_ADMIN`<br>(Chặn tự hạ quyền, Chống mất Admin cuối qua `admin_role_guard`, @Retryable, Tái xác thực Actor) | Concurrency & Guard Tests (8 tests) [PLANNED Phase 2] | **PLANNED Phase 2** |

---

### PHẦN IV: QUẢN LÝ LỊCH TRÌNH (4 CHỨC NĂNG)

| STT | Chức năng Quản trị | Sidebar Tab | Route Path | Frontend Screen & Dialog | Frontend Repository | Backend REST API | Backend Controller | Backend Service & Impl | Entity & DB Table | Quyền Hạn (Permission) | Automated Tests | Trạng thái & Kế hoạch |
|:---:|---|---|---|---|---|---|---|---|---|---|---|:---:|
| **4.1** | **Danh sách lịch trình toàn hệ thống** | `Quản lý lịch trình` (`AdminTab.itineraries`) | `/itineraries` | `PlaceholderFeatureView` [THAY THẾ BỞI `AdminItinerariesScreen`] | `ItineraryAdminRepository:getItineraries` [MISSING] | `GET /api/admin/itineraries` [MISSING] | `AdminItineraryController` [MISSING] | `AdminItineraryServiceImpl:getAdminItineraries` [MISSING] | `Itinerary`<br>(`itineraries`) | `ROLE_ADMIN` | `admin_itineraries_phase3_test.dart` [PLANNED Phase 3] | **PLANNED Phase 3** |
| **4.2** | **Xem chi tiết lịch trình (Read-Only Inspector)** | `Quản lý lịch trình` (`AdminTab.itineraries`) | `/itineraries` | `ItineraryDetailDialog` [MISSING] | `ItineraryAdminRepository:getDetail` [MISSING] | `GET /api/admin/itineraries/{id}` [MISSING] | `AdminItineraryController` [MISSING] | `AdminItineraryServiceImpl:getAdminItineraryById` [MISSING] | `Itinerary`, `ItineraryDay`, `Activity` | `ROLE_ADMIN`<br>(PRIVATE: reportId + Strict Audit trước khi trả dữ liệu, `readOnly=false`) | Privacy & Security Test [PLANNED Phase 3] | **PLANNED Phase 3** |
| **4.3** | **Ẩn lịch trình vi phạm tiêu chuẩn cộng đồng** | `Quản lý lịch trình` (`AdminTab.itineraries`) | `/itineraries` | `ModerateItineraryDialog` [MISSING] | `ItineraryAdminRepository:moderate` [MISSING] | `PATCH /api/admin/itineraries/{id}/moderate` [MISSING] | `AdminItineraryController` [MISSING] | `AdminItineraryServiceImpl:moderateItinerary` [MISSING] | `Itinerary.status = HIDDEN`, `audit_logs` | `ROLE_ADMIN` (Strict Audit) | Lifecycle Moderation Test [PLANNED Phase 3] | **PLANNED Phase 3** |
| **4.4** | **Khôi phục lịch trình hoạt động công khai** | `Quản lý lịch trình` (`AdminTab.itineraries`) | `/itineraries` | `ModerateItineraryDialog` [MISSING] | `ItineraryAdminRepository:moderate` [MISSING] | `PATCH /api/admin/itineraries/{id}/moderate` [MISSING] | `AdminItineraryController` [MISSING] | `AdminItineraryServiceImpl:moderateItinerary` [MISSING] | `Itinerary.status = ACTIVE`, `audit_logs` | `ROLE_ADMIN` (Strict Audit) | Lifecycle Moderation Test [PLANNED Phase 3] | **PLANNED Phase 3** |

---

### PHẦN V: QUẢN LÝ ĐƠN VỊ HÀNH CHÍNH & ĐỊA ĐIỂM (9 CHỨC NĂNG)

| STT | Chức năng Quản trị | Sidebar Tab | Route Path | Frontend Screen & Dialog | Frontend Repository | Backend REST API | Backend Controller | Backend Service & Impl | Entity & DB Table | Quyền Hạn (Permission) | Automated Tests | Trạng thái & Kế hoạch |
|:---:|---|---|---|---|---|---|---|---|---|---|---|:---:|
| **5.1** | **Danh sách địa điểm chuẩn hóa phân trang** | `Quản lý địa điểm` (`AdminTab.places`) | `/places` | `AdminPlacesScreen` ([#L1-L1079](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/locations/presentation/screens/admin_places_screen.dart)) | `PlaceRepository:getAdminPlacesPaged` | `GET /api/admin/places` | `AdminPlaceController` | `PlaceServiceImpl:getAdminPlaces` | `Place`<br>(`places`) | `ROLE_ADMIN` | `admin_places_phase5_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **5.2** | **Xem chi tiết địa điểm & vị trí bản đồ** | `Quản lý địa điểm` (`AdminTab.places`) | `/places` | `_showPlaceDetailDialog` (`WebMapView`) | `PlaceRepository:getAdminPlaceById` | `GET /api/admin/places/{id}` | `AdminPlaceController` | `PlaceServiceImpl:getAdminPlaceById` | `Place`, `PlaceProviderMapping`, `AdministrativeArea` | `ROLE_ADMIN` | `admin_places_phase5_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **5.3** | **Thêm địa điểm mới (2 cột click-to-pin)** | `Quản lý địa điểm` (`AdminTab.places`) | `/places` | `PlaceFormDialog` ([#L1-L450](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/locations/presentation/widgets/place_form_dialog.dart)) | `PlaceRepository:createPlace` | `POST /api/admin/places` | `AdminPlaceController` | `PlaceServiceImpl:createPlace` | `Place`, `PlaceProviderMapping` | `ROLE_ADMIN` (Chống trùng 300m) | `admin_places_phase5_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **5.4** | **Chỉnh sửa thông tin địa điểm** | `Quản lý địa điểm` (`AdminTab.places`) | `/places` | `PlaceFormDialog` (Edit Mode) | `PlaceRepository:updatePlace` | `PUT /api/admin/places/{id}` | `AdminPlaceController` | `PlaceServiceImpl:updatePlace` | `Place`<br>(`places`) | `ROLE_ADMIN` | `admin_places_phase5_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **5.5** | **Ẩn địa điểm (Soft-delete an toàn)** | `Quản lý địa điểm` (`AdminTab.places`) | `/places` | `HidePlaceDialog` ([#L1-L120](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/locations/presentation/widgets/hide_place_dialog.dart)) | `PlaceRepository:deletePlace` | `DELETE /api/admin/places/{id}` | `AdminPlaceController` | `PlaceServiceImpl:deletePlace` | `Place.status = HIDDEN` (Bảo toàn activities) | `ROLE_ADMIN` | `admin_places_phase5_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **5.6** | **Cây phân cấp 34 tỉnh/thành & xã/phường (Động)** | `Khu vực hành chính` (`AdminTab.administrativeAreas`) | `/administrative-areas` | `PlaceholderFeatureView` [THAY THẾ BỞI `AdminAdministrativeAreasScreen`] | `AdministrativeAreaRepository` [MISSING] | `GET /api/administrative-areas/provinces`<br>`GET /api/administrative-areas/{code}/children` | `AdministrativeAreaController` [EXISTS] | `AdministrativeAreaServiceImpl` [EXISTS] | `AdministrativeArea`<br>(`administrative_areas`) | Public (`permitAll()`), nạp động không hardcode | `admin_admin_areas_phase4_test.dart` [PLANNED Phase 4] | **PLANNED Phase 4** |
| **5.7** | **Báo cáo tỷ lệ chuẩn hóa địa giới toàn hệ thống** | `Khu vực hành chính` (`AdminTab.administrativeAreas`) | `/administrative-areas` | `AdminAdministrativeAreasScreen` (KPI Strip) [MISSING] | `AdministrativeAreaRepository:getStats` [MISSING] | `GET /api/admin/places/administrative-area/stats` [MISSING] | `AdminPlaceAdministrativeAreaController` [BỔ SUNG] | `PlaceAdministrativeAreaServiceImpl` [BỔ SUNG] | `places.administrative_id`, `administrative_areas` | `ROLE_ADMIN` | Unit & Integration Test [PLANNED Phase 4] | **PLANNED Phase 4** |
| **5.8** | **Kích hoạt Batch Resolve (Đồng bộ Tuần tự theo lô)** | `Khu vực hành chính` (`AdminTab.administrativeAreas`) | `/administrative-areas` | `BatchResolveControlPanel` [MISSING] | `AdministrativeAreaRepository:batchResolve` [MISSING] | `POST /api/admin/places/administrative-area/batch-resolve` | `AdminPlaceAdministrativeAreaController` [EXISTS] | `PlaceAdministrativeAreaServiceImpl:batchResolveAndLink` [EXISTS] | `places.administrative_id`, `audit_logs` | `ROLE_ADMIN` (Đồng bộ, chunk 50, dryRun warning, Idempotent Retry) | Batch Resolution Test [PLANNED Phase 4] | **PLANNED Phase 4** |
| **5.9** | **Xem trước & Gán mã hành chính cho Place** | `Quản lý địa điểm` (`AdminTab.places`) | `/places` | `PlaceAdministrativeAreaDialog` [MISSING] | `PlaceRepository:linkArea` [MISSING] | `POST /api/admin/places/{id}/administrative-area/preview`<br>`POST /api/admin/places/{id}/administrative-area/link` | `AdminPlaceAdministrativeAreaController` [EXISTS] | `PlaceAdministrativeAreaServiceImpl:linkManually` [EXISTS] | `places.administrative_id`, `audit_logs` | `ROLE_ADMIN` (Nghị quyết 388 Guard) | Backend Integration Test (PASS) | **PLANNED Phase 4** |

---

### PHẦN VI: NỘI DUNG CỘNG ĐỒNG & MEDIA ASSETS (8 CHỨC NĂNG)

| STT | Chức năng Quản trị | Sidebar Tab | Route Path | Frontend Screen & Dialog | Frontend Repository | Backend REST API | Backend Controller | Backend Service & Impl | Entity & DB Table | Quyền Hạn (Permission) | Automated Tests | Trạng thái & Kế hoạch |
|:---:|---|---|---|---|---|---|---|---|---|---|---|:---:|
| **6.1** | **Danh sách bài viết có phân trang & lọc** | `Kiểm duyệt bài viết` (`AdminTab.posts`) | `/posts` | `AdminPostsScreen` ([#L1-L888](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_posts_screen.dart)) | `ModerationRepository:getPostsPaged` | `GET /api/admin/community/posts` | `AdminCommunityController` | `PostServiceImpl:getAdminPosts` | `Post`<br>(`posts`) | `ROLE_ADMIN` | `admin_moderation_phase3_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **6.2** | **Xem chi tiết bài viết & gallery ảnh** | `Kiểm duyệt bài viết` (`AdminTab.posts`) | `/posts` | `_showPostDetailDialog` (`AdminDialog`) | `ModerationRepository` | `GET /api/admin/community/posts/{id}` | `AdminCommunityController` | `PostServiceImpl:getAdminPostById` | `Post`, `PostMedia`<br>(`posts`, `post_media`) | `ROLE_ADMIN` | `admin_moderation_phase3_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **6.3** | **Ẩn / Khôi phục bài viết vi phạm** | `Kiểm duyệt bài viết` (`AdminTab.posts`) | `/posts` | `_moderatePost` (`AdminDialog` nhập lý do) | `ModerationRepository:moderatePost` | `PATCH /api/admin/community/posts/{id}/moderate` | `AdminCommunityController` | `PostServiceImpl:moderatePost` | `Post`<br>(`posts.status`, `moderated_by`, `reason`) | `ROLE_ADMIN` | `admin_moderation_phase3_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **6.4** | **Xóa vĩnh viễn bài viết (Hard Purge)** | `Kiểm duyệt bài viết` (`AdminTab.posts`) | `/posts` | `_purgePost` (`AdminDialog` cảnh báo đỏ) | `ModerationRepository:purgePost` | `DELETE /api/admin/community/posts/{id}/purge` | `AdminCommunityController` | `PostServiceImpl:purgePost` | `Post`, `PostComment`, `PostLike`, `MediaAsset` | `ROLE_ADMIN` | `admin_moderation_phase3_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **6.5** | **Danh sách báo cáo vi phạm phân trang** | `Quản lý báo cáo` (`AdminTab.reports`) | `/reports` | `AdminReportsScreen` ([#L1-L621](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_reports_screen.dart)) | `ModerationRepository:getReportsPaged` | `GET /api/admin/community/reports` | `AdminCommunityController` | `PostServiceImpl:getAdminReports` | `PostReport`<br>(`post_reports`) | `ROLE_ADMIN` | `admin_moderation_phase3_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **6.6** | **Xử lý vi phạm / Bỏ qua báo cáo** | `Quản lý báo cáo` (`AdminTab.reports`) | `/reports` | `_resolveReport` (Hành động trực tiếp) | `ModerationRepository:resolveReport` | `PATCH /api/admin/community/reports/{id}/resolve` | `AdminCommunityController` | `PostServiceImpl:resolveReport` | `PostReport`<br>(`post_reports.status`, `resolved_by`) | `ROLE_ADMIN` | `admin_moderation_phase3_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **6.7** | **Giám sát tài nguyên Media (Bảng & Lưới ảnh)** | `Quản lý hình ảnh` (`AdminTab.media`) | `/media` | `AdminMediaScreen` ([#L1-L1068](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_media_screen.dart)) | `ModerationRepository:getMediaAssetsPaged` | `GET /api/admin/media-assets` | `AdminCommunityController` | `PostServiceImpl:getAdminMediaAssets` | `MediaAsset`<br>(`media_assets`) | `ROLE_ADMIN` | `admin_media_phase4_test.dart` | **DONE** [EXISTS - VERIFIED] |
| **6.8** | **Thử lại dọn dẹp ảnh lỗi / Dead-letter** | `Quản lý hình ảnh` (`AdminTab.media`) | `/media` | `AdminMediaScreen` (`_retryAsset`) | `ModerationRepository:retryMediaAsset` | `POST /api/admin/media-assets/{id}/retry` | `AdminCommunityController` | `PostServiceImpl:retryMediaAsset` | `MediaAsset`<br>(`retry_count`, `locked_at`) | `ROLE_ADMIN` | `admin_media_phase4_test.dart` | **DONE** [EXISTS - VERIFIED] |

---

### PHẦN VII: HỆ THỐNG & TỔNG QUAN (AUDIT UI, SETTINGS, DASHBOARD V2) (8 CHỨC NĂNG)

| STT | Chức năng Quản trị | Sidebar Tab | Route Path | Frontend Screen & Dialog | Frontend Repository | Backend REST API | Backend Controller | Backend Service & Impl | Entity & DB Table | Quyền Hạn (Permission) | Automated Tests | Trạng thái & Kế hoạch |
|:---:|---|---|---|---|---|---|---|---|---|---|---|:---:|
| **7.1** | **Danh sách Nhật ký kiểm toán phân trang** | `Nhật ký hoạt động` (`AdminTab.auditLogs`) | `/audit-logs` | `PlaceholderFeatureView` [THAY THẾ BỞI `AdminAuditLogsScreen`] | `AuditLogRepository:getLogs` [MISSING] | `GET /api/admin/audit-logs` [MISSING] | `AdminAuditLogController` [MISSING] | `AdminAuditLogServiceImpl:getLogs` [MISSING] | `AuditLog`<br>(`audit_logs`) | `ROLE_ADMIN` (Read-Only, Stable Pagination `created_at DESC, log_id DESC`) | `admin_audit_logs_phase5_test.dart` [PLANNED Phase 5] | **PLANNED Phase 5** |
| **7.2** | **Xem chi tiết bản ghi & Before/After JSON Diff** | `Nhật ký hoạt động` (`AdminTab.auditLogs`) | `/audit-logs` | `AuditLogDetailDialog` [MISSING] | `AuditLogRepository:getLogById` [MISSING] | `GET /api/admin/audit-logs/{id}` [MISSING] | `AdminAuditLogController` [MISSING] | `AdminAuditLogServiceImpl:getLogById` [MISSING] | `AuditLog`<br>(`audit_logs`) | `ROLE_ADMIN` (Read-Only) | Unit & Widget Test [PLANNED Phase 5] | **PLANNED Phase 5** |
| **7.3** | **Xuất nhật ký kiểm toán (Export CSV/JSON)** | `Nhật ký hoạt động` (`AdminTab.auditLogs`) | `/audit-logs` | `AdminAuditLogsScreen` (Nút Export) [MISSING] | `AuditLogRepository:export` [MISSING] | `GET /api/admin/audit-logs/export` [MISSING] | `AdminAuditLogController` [MISSING] | `AdminAuditLogServiceImpl:exportLogs`<br>(Export ID, 4 trạng thái SUCCESS/DELIVERY_FAILED/FAILED/AUDIT_PERSISTENCE_FAILED, lease-based cleanup cron > 2h) [MISSING] | `audit_logs` streaming | `ROLE_ADMIN` (Strict Audit `AUDIT_EXPORT`, max 5.000 dòng, Quy trình 4 trạng thái có Export ID, fallback app logger khi DB sập) | Export Integrity Test [PLANNED Phase 5] | **PLANNED Phase 5** |
| **7.4** | **Xem danh sách cấu hình hệ thống động** | `Cài đặt` (`AdminTab.settings`) | `/settings` | `PlaceholderFeatureView` [THAY THẾ BỞI `AdminSettingsScreen`] | `SettingsRepository:getSettings` [MISSING] | `GET /api/admin/settings` [MISSING] | `AdminSettingsController` [MISSING] | `SystemSettingServiceImpl:getSettings` [MISSING] | `SystemSetting`<br>(`system_settings`) [MISSING] | `ROLE_ADMIN` (Secret excluded) | `admin_settings_phase6_test.dart` [PLANNED Phase 6] | **PLANNED Phase 6** |
| **7.5** | **Cập nhật cấu hình ngưỡng kiểm duyệt & upload** | `Cài đặt` (`AdminTab.settings`) | `/settings` | `AdminSettingsScreen` (Edit Panels) [MISSING] | `SettingsRepository:updateSetting` [MISSING] | `PUT /api/admin/settings/{key}` [MISSING] | `AdminSettingsController` [MISSING] | `SystemSettingServiceImpl:updateSetting` [MISSING] | `SystemSetting`, `audit_logs` | `ROLE_ADMIN` (Strict Audit, Upload limit $\le 5\text{MB}$) | Dynamic Config Test [PLANNED Phase 6] | **PLANNED Phase 6** |
| **7.6** | **Bật / Tắt chế độ bảo trì hệ thống toàn cục** | `Cài đặt` (`AdminTab.settings`) | `/settings` | `AdminSettingsScreen` (Maintenance Switch) [MISSING] | `SettingsRepository:updateSetting` [MISSING] | `PUT /api/admin/settings/SYSTEM_MAINTENANCE_MODE` [MISSING] | `AdminSettingsController` [MISSING] | `SystemSettingServiceImpl:updateSetting` [MISSING] | `SystemSetting`, `audit_logs` | `ROLE_ADMIN` (Strict Audit, CorsFilter -> JwtFilter -> MaintenanceFilter) | Maintenance Mode Test [PLANNED Phase 6] | **PLANNED Phase 6** |
| **7.7** | **API Thống kê Tổng hợp duy nhất (Dashboard v2)** | `Tổng quan` (`AdminTab.dashboard`) | `/dashboard` | `AdminDashboardScreen` [REFACTOR Phase 7] | `DashboardRepository:fetchDashboardSummary` [REFACTOR Phase 7] | `GET /api/admin/dashboard/summary` [MISSING] | `AdminDashboardController` [MISSING] | `AdminDashboardServiceImpl:getSummary` [MISSING] | `users`, `itineraries`, `places`, `posts`, `post_reports`, `media_assets` | `ROLE_ADMIN` | `admin_dashboard_v2_test.dart` [PLANNED Phase 7] | **PLANNED Phase 7** [EXISTS - REFACTOR] |
| **7.8** | **Biểu đồ tăng trưởng thực tế & Dòng hoạt động** | `Tổng quan` (`AdminTab.dashboard`) | `/dashboard` | `AdminDashboardScreen` (Growth Chart & Audit Stream) [MISSING] | `DashboardRepository:fetchAnalytics` [MISSING] | `GET /api/admin/dashboard/analytics` [MISSING] | `AdminDashboardController` [MISSING] | `AdminDashboardServiceImpl:getAnalytics` [MISSING] | Time-series query từ DB & `audit_logs` | `ROLE_ADMIN` | Unit & Widget Tests [PLANNED Phase 7] | **PLANNED Phase 7** |

---

## 3. TỔNG HỢP CHÍNH XÁC TOÀN BỘ 42 MẮT XÍCH CHỨC NĂNG

```
+---------------------------------------------------------------------------------------+
|                    TỔNG HỢP CHÍNH XÁC 42 MẮT XÍCH CHỨC NĂNG QUẢN TRỊ                  |
+---------------------------------------------------------------------------------------+
|                                                                                       |
|  [EXISTS - VERIFIED]         18 chức năng (42.86%)                                    |
|  - 1.1 đến 1.5: Auth & Profile (Đăng nhập, Đăng xuất, Session Guard, Xem/Sửa Profile)  |
|                 -> 5 chức năng                                                        |
|  - 5.1 đến 5.5: Places Normalization (Danh sách, Chi tiết, Thêm mới, Sửa, Ẩn mềm)     |
|                 -> 5 chức năng                                                        |
|  - 6.1 đến 6.8: Posts, Reports & Media Assets (Toàn bộ kiểm duyệt cộng đồng & ảnh)    |
|                 -> 8 chức năng                                                        |
|  Subtotal: 5 + 5 + 8 = 18 chức năng (42.86%)                                          |
|                                                                                       |
|  [EXISTS - REFACTOR]          1 chức năng (2.38%)                                     |
|  - 7.7: Dashboard Summary Stats (Nâng cấp từ 5 count APIs lên 1 summary API gộp)      |
|  Subtotal: 1 chức năng (2.38%)                                                        |
|                                                                                       |
|  [PLANNED (Phase 1 -> 7)]    23 chức năng (54.76%)                                    |
|  - Phase 1: 2.1, 2.2 (Audit Trail Core Engine) -> 2 chức năng (4.76%)                 |
|  - Phase 2: 1.6 (Ẩn Register) + 3.1 đến 3.5 (User Management) -> 6 chức năng (14.29%) |
|  - Phase 3: 4.1 đến 4.4 (Itinerary Moderation) -> 4 chức năng (9.52%)                 |
|  - Phase 4: 5.6 đến 5.9 (Administrative Areas UI) -> 4 chức năng (9.52%)              |
|  - Phase 5: 7.1 đến 7.3 (Audit Logs UI) -> 3 chức năng (7.14%)                        |
|  - Phase 6: 7.4 đến 7.6 (System Settings) -> 3 chức năng (7.14%)                      |
|  - Phase 7: 7.8 (Dashboard Analytics & Charts) -> 1 chức năng (2.38%)                 |
|  Subtotal: 2 + 6 + 4 + 4 + 3 + 3 + 1 = 23 chức năng (54.76%)                          |
|                                                                                       |
+---------------------------------------------------------------------------------------+
|  TỔNG CỘNG: CHÍNH XÁC 42 CHỨC NĂNG NGHIỆP VỤ QUẢN TRỊ TRÊN 11 SIDEBAR TABS (100.0%)   |
|  (18 Verified [42.86%] + 1 Refactor [2.38%] + 23 Planned [54.76%] = 42 [100.0%])      |
+---------------------------------------------------------------------------------------+
```
