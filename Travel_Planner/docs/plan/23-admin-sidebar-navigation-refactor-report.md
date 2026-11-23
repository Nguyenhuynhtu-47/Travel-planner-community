# BÁO CÁO TOÀN DIỆN: REFACTOR ADMIN SIDEBAR NAVIGATION & UNIFIED PAGE NAVIGATION

**Ngày thực hiện:** 23/11/2026  
**Chi nhánh làm việc:** `feature/admin-moderation-integration`  
**Mục tiêu:** Tái cấu trúc toàn bộ hệ thống điều hướng Flutter Web Admin của Travel Planner:
1. Chuyển đổi Sidebar sang kiến trúc **Text-only** (hoàn toàn không còn icon chức năng hoặc trang trí, chỉ giữ lại chevron cho các thao tác dropdown/collapse).
2. Xây dựng Sidebar trở thành **nơi điều hướng duy nhất** giữa toàn bộ các chức năng quản trị.
3. Phân loại cấu trúc menu thành:
   - **Type A (Dropdown/Accordion):** Cho các nhóm chức năng có quan hệ cha – con (Quản lý cộng đồng, Quản lý nội dung, Hệ thống).
   - **Type B (Standalone):** Cho các mục chức năng độc lập (Dashboard, Quản lý địa điểm, Quản lý lịch trình).
4. **Loại bỏ hoàn toàn nested tabs điều hướng chức năng bên trong màn hình:** Phân rã `AdminModerationScreen` thành 3 màn hình độc lập (`AdminPostsScreen`, `AdminReportsScreen`, `AdminMediaScreen`), ánh xạ 1:1 trực tiếp từ Sidebar menu item sang màn hình độc lập.
5. Bảo toàn 100% logic nghiệp vụ, backend APIs, JWT authentication, RBAC, và toàn bộ bộ lọc/thao tác CRUD, moderation, purge, retry.

---

## 1. Kết quả Rà soát & Audit Cấu trúc Điều hướng Cũ

### 1.1. Hiện trạng trước Refactor
- **Sidebar có icon hỗn hợp:** Mỗi mục menu hiển thị một icon Material bên cạnh tiêu đề (`Icons.dashboard`, `Icons.article`, `Icons.report_problem`, `Icons.place`, v.v.). Header logo cũng có icon `Icons.travel_explore`.
- **Lồng ghép chức năng (Nested Multi-page Tab Host):**
  - Màn hình `AdminModerationScreen` đóng vai trò là một container chứa đồng thời cả 3 phân hệ chức năng:
    1. Kiểm duyệt bài viết (`AdminPostModel`, duyệt bài HIDDEN/ACTIVE, hard purge).
    2. Quản lý báo cáo vi phạm (`AdminPostReportModel`, giải quyết RESOLVED/DISMISSED).
    3. Quản lý tài nguyên media (`AdminMediaAssetModel`, dead-letter filter, retry purge).
  - Cả 3 chức năng này được chuyển đổi qua lại bằng một thanh `AdminTabBar` / `TabBarView` nội bộ.
  - Sidebar chuyển hướng đến cùng màn hình `AdminModerationScreen` với `initialTabIndex` khác nhau (0, 1, 2).
- **Vấn đề trải nghiệm quản trị (UX Inconsistency):**
  - Người dùng có thể bị nhầm lẫn giữa điều hướng cấp ứng dụng (Sidebar) và điều hướng cấp trang (Tabs).
  - Không có sự phân biệt trực quan giữa các nhóm chức năng cha – con và các tính năng độc lập.

---

## 2. Kiến trúc Điều hướng Mới (Unified SaaS Navigation Architecture)

### 2.1. Text-Only Sidebar với Phân cấp Trực quan
- **Xóa bỏ 100% icons:**
  - Không còn icon bên cạnh menu items, icon nhóm hay icon trang trí ở logo.
  - Khu vực branding sử dụng typography thuần túy: chữ in hoa đậm `TRAVEL PLANNER` và phụ đề `Admin Portal`.
  - Khi sidebar thu gọn (`isCollapsed: true`, width 68px), hệ thống hiển thị các token viết tắt ngắn gọn (ví dụ: `TP`, `DB`, `CĐ`, `ĐĐ`, `LT`, `ND`, `HT`) kèm tooltip đầy đủ.
- **Chỉ báo tương tác duy nhất:**
  - Chevron mũi tên (`Icons.chevron_right` / `Icons.expand_more`) được sử dụng độc quyền làm chỉ báo trạng thái đóng/mở của dropdown parent menu.
  - `Icons.chevron_left` / `Icons.chevron_right` ở góc dưới làm chỉ báo thu gọn / mở rộng Sidebar.

### 2.2. Phân loại Cấu trúc Menu (Dropdown vs. Standalone)
| Mục Menu | Phân loại | Mục con / Hành vi | Màn hình độc lập ánh xạ |
| :--- | :--- | :--- | :--- |
| **Tổng quan Dashboard** | Standalone (Type B) | Trực tiếp | `AdminDashboardScreen` |
| **Quản lý cộng đồng** | Dropdown (Type A) | • Kiểm duyệt bài viết<br>• Quản lý báo cáo<br>• Quản lý người dùng | • `AdminPostsScreen`<br>• `AdminReportsScreen`<br>• `PlaceholderFeatureView(users)` |
| **Quản lý địa điểm** | Standalone (Type B) | Trực tiếp | `AdminPlacesScreen` |
| **Quản lý lịch trình** | Standalone (Type B) | Trực tiếp | `PlaceholderFeatureView(itineraries)` |
| **Quản lý nội dung** | Dropdown (Type A) | • Quản lý Media<br>• Khu vực hành chính | • `AdminMediaScreen`<br>• `PlaceholderFeatureView(administrativeAreas)` |
| **Hệ thống** | Dropdown (Type A) | • Nhật ký hoạt động<br>• Cài đặt hệ thống | • `PlaceholderFeatureView(auditLogs)`<br>• `PlaceholderFeatureView(settings)` |

- **Cơ chế Auto-expand & Badge thông minh:**
  - Khi người dùng chọn bất kỳ menu con nào (hoặc khi truy cập bằng URL/route), dropdown cha tự động mở rộng để đảm bảo menu con đang kích hoạt luôn hiển thị rõ ràng.
  - Menu con **"Quản lý báo cáo"** hiển thị badge số lượng báo cáo chờ xử lý (`badgeCount > 0`). Khi dropdown cha bị đóng lại, badge này nổi lên trên dòng tiêu đề cha để cảnh báo admin.

---

## 3. Phân rã Màn hình Độc lập (Screen Decomposition)

Loại bỏ hoàn toàn `AdminTabBar` và cơ chế lồng tab chức năng bên trong màn hình. Thay vào đó, mỗi chức năng được triển khai thành một màn hình độc lập hoàn chỉnh:

### 3.1. `AdminPostsScreen` (`lib/features/moderation/presentation/screens/admin_posts_screen.dart`)
- **Vai trò:** Quản lý và kiểm duyệt bài viết cộng đồng vi phạm tiêu chuẩn.
- **Header & Toolbar:**
  - `AdminPageHeader` riêng biệt với tiêu đề "Kiểm duyệt bài viết" và phụ đề hướng dẫn.
  - `AdminToolbar` tích hợp ô tìm kiếm nội dung/tác giả/ID, bộ lọc trạng thái dropdown (`ALL`, `ACTIVE`, `HIDDEN`), và nút "Làm mới".
- **Bảng dữ liệu & Hành động:**
  - DataTable hiển thị ID, Tác giả, Nội dung, Ảnh đính kèm, Trạng thái (`AdminStatusBadge`), Ngày tạo, Thao tác.
  - Dialog xem chi tiết bài viết (kèm ảnh Cloudinary, lượt thích, bình luận, lý do kiểm duyệt).
  - Dialog và hành động Ẩn bài viết (`HIDDEN`) / Khôi phục bài viết (`ACTIVE`).
  - Dialog cảnh báo nguy hiểm và hành động Xóa vĩnh viễn (`Hard Purge`).

### 3.2. `AdminReportsScreen` (`lib/features/moderation/presentation/screens/admin_reports_screen.dart`)
- **Vai trò:** Tiếp nhận, rà soát và phân giải các báo cáo vi phạm từ cộng đồng.
- **Header & Toolbar:**
  - `AdminPageHeader` riêng biệt: "Quản lý báo cáo vi phạm".
  - `AdminToolbar` với bộ lọc trạng thái (`PENDING`, `RESOLVED`, `DISMISSED`, `ALL`) và nút "Làm mới".
- **Bảng dữ liệu & Hành động:**
  - DataTable hiển thị REPORT ID, POST ID, NGƯỜI BÁO CÁO, LÝ DO, CHI TIẾT, TRẠNG THÁI, NGÀY BÁO CÁO, THAO TÁC.
  - Dialog xem chi tiết báo cáo và thông tin người báo cáo.
  - Nút thao tác nhanh trực tiếp trên từng hàng: "Xử lý vi phạm" (`RESOLVED`), "Bỏ qua" (`DISMISSED`).

### 3.3. `AdminMediaScreen` (`lib/features/moderation/presentation/screens/admin_media_screen.dart`)
- **Vai trò:** Giám sát tài nguyên media tải lên Cloudinary, phát hiện rác và dọn dẹp các tài nguyên lỗi.
- **Header & Toolbar:**
  - `AdminPageHeader` riêng biệt: "Quản lý tài nguyên Media".
  - `AdminToolbar` với bộ lọc trạng thái (`ALL`, `UNATTACHED`, `ATTACHED`, `DELETING`, `DELETED`), checkbox lọc dead-letter (`deadLetterOnly`), và nút "Làm mới".
- **Bảng dữ liệu & Hành động:**
  - DataTable hiển thị ASSET ID, NGƯỜI TẢI LÊN, XEM TRƯỚC (thumbnail), CLOUDINARY PUBLIC ID, TRẠNG THÁI, RETRY, DEAD-LETTER badge, LỖI GẦN NHẤT, THAO TÁC.
  - Dialog xem chi tiết tài nguyên và ảnh kích thước lớn.
  - Nút thao tác thử lại xóa ("Retry xóa") cho các file đang ở trạng thái `DELETING` hoặc dead-lettered.

### 3.4. Cập nhật `AdminShell` (`lib/features/layout/presentation/screens/admin_shell.dart`)
- `_buildCurrentContent()` ánh xạ trực tiếp 1:1 từng `AdminTab` sang màn hình chuyên trách tương ứng:
  - `AdminTab.dashboard` -> `AdminDashboardScreen`
  - `AdminTab.posts` -> `AdminPostsScreen(embedded: true)`
  - `AdminTab.reports` -> `AdminReportsScreen(embedded: true)`
  - `AdminTab.media` -> `AdminMediaScreen(embedded: true)`
  - `AdminTab.places` -> `AdminPlacesScreen(embedded: true)`
  - `AdminTab.profile` -> `ProfileScreen(embedded: true)`
  - Các mục chưa triển khai -> `PlaceholderFeatureView`

---

## 4. Danh sách File Chỉnh sửa & Tạo mới

### 4.1. File mới tạo:
1. `Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_posts_screen.dart`: Màn hình độc lập kiểm duyệt bài viết.
2. `Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_reports_screen.dart`: Màn hình độc lập quản lý báo cáo vi phạm.
3. `Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_media_screen.dart`: Màn hình độc lập quản lý media assets.
4. `Travel_Planner/docs/plan/23-admin-sidebar-navigation-refactor-report.md`: Báo cáo kỹ thuật chi tiết này.

### 4.2. File cập nhật:
1. `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_sidebar.dart`: Tái cấu trúc sang text-only, hỗ trợ dropdown Type A (có auto-expand và parent badge) và standalone Type B.
2. `Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart`: Ánh xạ 1:1 trực tiếp từ `AdminTab` sang màn hình độc lập tương ứng.
3. `Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_moderation_screen.dart`: Đóng vai trò adapter tương thích ngược (export các màn hình độc lập mới và hỗ trợ các caller cũ nếu có).
4. `Travel_Planner/frontend/web/test/admin_portal_layout_test.dart`: Bổ sung test kiểm thử text-only sidebar, tương tác đóng/mở dropdown menu, chế độ thu gọn text tokens và điều hướng các màn hình độc lập.
5. `Travel_Planner/docs/ai/09-development-log.md`: Ghi nhật ký phát triển bằng tiếng Anh theo quy định dự án.

---

## 5. Kết quả Kiểm thử & Nghiệm thu (Verification & Results)

1. **Static Analysis (`flutter analyze`):**
   ```text
   Analyzing web...
   No issues found! (ran in 3.0s)
   ```
   Hoàn toàn không có lỗi (errors), không có cảnh báo (warnings), và không có linter hints nào.

2. **Unit & Widget Test Suite (`flutter test`):**
   ```text
   00:12 +68: All tests passed!
   ```
   **68/68 tests passed** (100% pass rate). Bao gồm:
   - AdminTab Domain & Grouping Tests
   - DashboardRepository Unit Tests
   - AdminSidebar Text-Only & Dropdown Toggle Widget Tests
   - AdminHeader Widget Tests
   - AdminDashboardScreen Widget Tests
   - AdminShell Full Navigation & RBAC Tests (Posts, Reports, Media, Places, Dashboard)
   - Moderation Models Serialization & Repository Tests
   - Moderation Actions & Purge Tests

3. **Production Web Build (`flutter build web`):**
   ```text
   Compiling lib\main.dart for the Web...                             72.4s
   √ Built build\web
   ```
   Biên dịch thành công bản build Web Release với cờ `--dart-define=API_BASE_URL=http://localhost:8080`.

4. **Git Safety Check (`git status`):**
   Không có file backend nào bị thay đổi ngoài ý muốn, không thực hiện commit hay push code lên Git.
