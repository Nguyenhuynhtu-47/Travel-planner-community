# BÁO CÁO TOÀN DIỆN: REDESIGN GIAO DIỆN WEB ADMIN – SECOND DESIGN PASS (PROFESSIONAL SAAS/ERP)

**Ngày thực hiện:** 23/11/2026  
**Chi nhánh làm việc:** `feature/admin-moderation-integration`  
**Mục tiêu:** Thực hiện một đợt redesign triệt để, tái cấu trúc toàn diện phân hệ quản trị Flutter Web Admin của Travel Planner sang chuẩn **Professional SaaS / ERP Admin Dashboard**, giải quyết dứt điểm các hạn chế thẩm mỹ "AI-generated" và lỗi bất đồng bộ nested tab/report.

---

## 1. Kết quả Điều tra & Sửa lỗi: Nested Tab & "Quản lý báo cáo"

### 1.1. Hiện tượng trong ảnh chụp thực tế
Khi người dùng chọn Sidebar item **"Quản lý báo cáo"**, thanh Breadcrumbs hiển thị đúng `Admin / QUẢN LÝ CỘNG ĐỒNG / Quản lý báo cáo`, tuy nhiên thanh tab con bên dưới vẫn giữ chọn tab con **"Bài viết"** và bảng dữ liệu hiển thị danh sách bài viết thay vì danh sách báo cáo vi phạm.

### 1.2. Nguyên nhân kỹ thuật gốc rễ (Root Cause Analysis)
1. **Dùng chung một Stateful Widget không có định danh Key:**
   - Trong `AdminShell._buildCurrentContent()`, cả ba tab Sidebar:
     - `AdminTab.posts` (Kiểm duyệt bài viết)
     - `AdminTab.reports` (Quản lý báo cáo)
     - `AdminTab.media` (Quản lý Media)
   - Đều trả về cùng một widget `AdminModerationScreen(initialTabIndex: ...)`.
   - Do không gán `key: ValueKey(_currentTab)`, Flutter tái sử dụng lại đối tượng `State` (`_AdminModerationScreenState`) đã được khởi tạo trước đó.
2. **Cơ chế TabController không đồng bộ tức thì:**
   - Khi `didUpdateWidget` được gọi, code trước đó sử dụng `_tabController.animateTo(widget.initialTabIndex)`. Phương thức này phụ thuộc vào chu kỳ vsync và animation ticker, dẫn đến việc không cập nhật ngay lập tức `index` hoặc bị bỏ qua nếu animation đang trong tiến trình khác.
3. **Thiếu liên kết hai chiều (Two-way synchronization):**
   - Khi người dùng click chọn tab con trực tiếp trên giao diện `AdminModerationScreen`, widget này không phát sự kiện ngược lại cho `AdminShell`. Dẫn đến tình trạng thanh Breadcrumb và Sidebar bị lệch hoàn toàn so với nội dung thực tế đang hiển thị trên màn hình.

### 1.3. Giải pháp khắc phục triệt để
- **Phân tách Key rõ ràng:** Trong `AdminShell`, mỗi nhánh `AdminTab.posts`, `AdminTab.reports`, `AdminTab.media` được truyền khóa định danh duy nhất:
  - `key: const ValueKey(AdminTab.posts)`
  - `key: const ValueKey(AdminTab.reports)`
  - `key: const ValueKey(AdminTab.media)`
  - Giúp Flutter luôn mount đúng màn hình với `initialIndex` chính xác tương ứng từ Sidebar.
- **Đồng bộ index trực tiếp:** Trong `didUpdateWidget`, thiết lập trực tiếp `_tabController.index = widget.initialTabIndex` để đảm bảo chuyển tab tức thì không phụ thuộc animation trễ.
- **Đồng bộ hai chiều với Callback `onNavigateTab`:** Bổ sung callback `onNavigateTab` vào `AdminModerationScreen`. Khi người dùng click bất kỳ tab nào trên `AdminTabBar`, callback được gọi để cập nhật `_currentTab` của `AdminShell`, lập tức đồng bộ Sidebar highlight và Breadcrumb ở Header.

---

## 2. Hệ thống Thiết kế Dùng chung (Shared Admin Design System)

Để ngăn chặn việc mỗi màn hình tự thiết kế một kiểu, các shared components cốt lõi đã được xây dựng theo ngôn ngữ SaaS/ERP:

1. **`AdminPageHeader` (`lib/shared/widgets/admin_page_header.dart`):**
   - Tiêu đề màn hình phẳng (flat), font chữ 18px bold, chữ màu `AppColors.textPrimary`.
   - Phụ đề (subtitle) xúc tích 12.5px, viền dưới 1px hairline (`AppColors.border`).
   - Khu vực hành động bên phải cho phép đính kèm nút "Làm mới" (outlined) và Primary Action CTA ("Thêm địa điểm").
   - **Loại bỏ hoàn toàn các card bao quanh page header cồng kềnh.**

2. **`AdminToolbar` (`lib/shared/widgets/admin_toolbar.dart`):**
   - Thanh công cụ phẳng hợp nhất tìm kiếm (search field kích thước chuẩn 320px, cao 34px), các bộ lọc dropdown, và các hành động phụ trợ.
   - Viền dưới 1px tinh tế, nền trắng `AppColors.surface`, tự động chuyển sang layout wrap trên màn hình hẹp (< 768px).

3. **`AdminStatusBadge` (`lib/shared/widgets/admin_status_badge.dart`):**
   - Badge trạng thái chuẩn mực, font 11px semi-bold, viền 1px bo góc nhẹ 4px.
   - Bảng màu semantic dịu mắt (không dùng màu huỳnh quang chói lóa):
     - Xanh lá mềm (`#ECFDF5`, viền `#A7F3D0`, chữ `#047857`) cho `ACTIVE`, `RESOLVED`, `UP`.
     - Vàng cam mềm (`#FEF3C7`, viền `#FCD34D`, chữ `#92400E`) cho `PENDING`.
     - Hổ phách (`#FFFBEB`, viền `#FDE68A`, chữ `#B45309`) cho `HIDDEN`.
     - Đỏ dịu (`#FEF2F2`, viền `#FECACA`, chữ `#B91C1C`) cho `DELETED`, `BANNED`, `DEAD_LETTER`.
     - Xám trung tính (`#F3F4F6`, viền `#E5E7EB`, chữ `#4B5563`) cho `DISMISSED`.
     - Xanh dương mềm (`#EFF6FF`, viền `#BFDBFE`, chữ `#1D4ED8`) cho `UNATTACHED`.
     - Xanh lục mạ (`#F0FDF4`, viền `#BBF7D0`, chữ `#15803D`) cho `ATTACHED`.

4. **`AdminTabBar` (`lib/shared/widgets/admin_tab_bar.dart`):**
   - Thanh tab con phẳng (flat tab strip), chiều cao chuẩn 40px, viền 1px dưới.
   - Active indicator sắc nét với gạch chân 2px màu thương hiệu Crimson (`AppColors.primary`).
   - Loại bỏ icon thừa, khoảng cách padding dư thừa và bóng đổ.

---

## 3. Chi tiết Redesign các Màn hình Quản trị

### 3.1. Dashboard (`admin_dashboard_screen.dart`)
- **Page Header:** Tích hợp `AdminPageHeader` phẳng, hiển thị dòng chào "Xin chào, {fullName}!" tinh gọn cùng nút "Làm mới" viền mảnh.
- **Unified Metric Strip (Vùng thống kê hợp nhất):**
  - Thay thế 4 card tách rời và icon nền màu tròn bằng **1 thanh metric liền mạch** viền 1px.
  - Phân chia 4 chỉ số (Địa điểm chuẩn hóa, Bài viết cộng đồng, Báo cáo chờ xử lý, Tài nguyên Media) bằng các đường phân cách dọc 1px.
  - Số liệu hiển thị lớn (26px w800), nhãn danh mục rõ ràng, hiệu ứng hover nhẹ và hỗ trợ click điều hướng trực tiếp sang tab tương ứng.
  - Báo cáo tồn đọng (> 0) tự động kích hoạt cảnh báo màu đỏ tinh tế trên nhãn và số liệu.
- **Khu vực dữ liệu trọng tâm (2-column data grid):**
  - Hai khối dữ liệu chính: Báo cáo vi phạm đang chờ xử lý & Bài viết cộng đồng gần đây.
  - Bố trí theo grid 2 cột cân xứng (chuyển sang 1 cột trên màn hình nhỏ).
  - Trình bày dạng danh sách/bảng với đường kẻ mỏng 1px, ID badge, thông tin tác giả/người báo cáo, status badge, và nút thao tác trực tiếp.

### 3.2. Quản lý Kiểm duyệt Bài viết & Báo cáo (`admin_moderation_screen.dart`)
- **Nested Tab Strip:** Sử dụng `AdminTabBar` phẳng với 3 tab: Bài viết, Báo cáo vi phạm, Tài nguyên Media.
- **Thanh công cụ Toolbar:**
  - Bộ lọc trạng thái bài viết / báo cáo đưa vào dropdown 32px viền 1px.
  - Nút "Làm mới" với icon refresh xám trung tính, loại bỏ hoàn toàn nút hồng lớn.
- **Bảng dữ liệu Data Table:**
  - Tiêu đề cột nền trung tính `AppColors.surfaceSoft`, font in hoa 11.5px bold `AppColors.muted`.
  - Độ cao dòng gọn (44–52px).
  - Trạng thái áp dụng `AdminStatusBadge`.
  - Nhóm nút thao tác ("Chi tiết", "Ẩn"/"Khôi phục", "Hard Purge") trình bày gọn gàng, có màu sắc phân biệt hợp lý (xanh cho khôi phục, cam cho ẩn, đỏ cho xóa vĩnh viễn).

### 3.3. Quản lý Địa điểm Chuẩn hóa (`admin_places_screen.dart`)
- **Header:** `AdminPageHeader` mang tiêu đề rõ ràng, tích hợp nút "Thêm địa điểm" (`ElevatedButton` Crimson) và nút "Làm mới".
- **Toolbar:** `AdminToolbar` tích hợp ô tìm kiếm tự động thu phóng (320px) với icon xóa nhanh, dropdown lọc Danh mục và dropdown lọc Trạng thái trên cùng một hàng.
- **Bố cục Wide Layout:**
  - Cột trái (60%): Danh sách địa điểm phẳng, hiển thị ảnh thumbnail, tọa độ, địa chỉ, status badge.
  - Cột phải (40%): Chi tiết địa điểm đã chọn, bản đồ `WebMapView` tích hợp marker định vị, thông tin tọa độ và nút sửa/ẩn trực quan.

### 3.4. Hồ sơ cá nhân & Placeholder Views
- `ProfileScreen`: Loại bỏ bóng đổ `0x0A000000`, sử dụng viền 1px sắc nét, bo góc 8px/4px, bố cục form cài đặt tài khoản ERP/SaaS chuẩn mực.
- `PlaceholderFeatureView`: Bố cục container gọn 640px max-width, typography rõ ràng, không khoảng trắng vô nghĩa.

---

## 4. Xác nhận Nguyên tắc & Tính Toàn vẹn Hệ thống

- [x] **Backend & Database:** Không thay đổi bất kỳ file Backend Java, database entity, migration hay API contract nào.
- [x] **Nghiệp vụ & Quyền hạn:** Giữ nguyên 100% logic phân quyền RBAC, JWT authentication, moderation actions (hide/restore/purge), report resolution, và Places CRUD.
- [x] **Thứ tự Navigation:** Giữ nguyên đúng 11 tab và 5 nhóm chức năng trên `AdminSidebar`.
- [x] **Color Palette:** Giữ nguyên màu nhận diện thương hiệu `AppColors.primary` (#FF385C / Crimson) nhưng sử dụng tiết chế, không lạm dụng.

---

## 5. Kết quả Kiểm thử & Xác minh Kỹ thuật

1. **Bộ kiểm thử tự động (`flutter test`):**
   - Chạy toàn bộ 67 widget & unit tests của web frontend:
   - **Kết quả:** `00:09 +67: All tests passed!` (100% pass, exit code 0).
2. **Kiểm tra phân tích tĩnh (`flutter analyze`):**
   - Quét toàn bộ mã nguồn `frontend/web`:
   - **Kết quả:** `No issues found! (ran in 3.6s)` (0 errors, 0 warnings).
3. **Biên dịch sản phẩm Web (`flutter build web`):**
   - Biên dịch web với cờ `API_BASE_URL`:
   - **Kết quả:** `√ Built build\web` (exit code 0).
4. **Kiểm tra trạng thái Git (`git status`):**
   - Working tree an toàn, chỉ chứa các file giao diện frontend web và tài liệu liên quan.
