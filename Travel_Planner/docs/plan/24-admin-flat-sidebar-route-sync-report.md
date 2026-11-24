# BÁO CÁO TOÀN DIỆN: REFACTOR FLAT SIDEBAR & ROUTE SYNCHRONIZATION

**Ngày thực hiện:** 23/11/2026  
**Chi nhánh làm việc:** `feature/admin-moderation-integration`  
**Mục tiêu:**
1. **Loại bỏ toàn bộ dropdown** trong Sidebar Admin, bao gồm menu cha/con và các nút mở rộng/thu gọn dạng accordion.
2. Giữ nguyên 100% danh sách các tab Sidebar hiện tại, không thêm, xóa hay đổi tên bất kỳ tab nào.
3. Sidebar hiển thị thuần văn bản (text-only), không sử dụng bất kỳ icon nào.
4. Mỗi tab Sidebar mở trực tiếp một trang độc lập, không có nested tabs điều hướng chức năng bên trong màn hình.
5. Bảo toàn toàn bộ chức năng nghiệp vụ, API, dữ liệu, bộ lọc và quyền truy cập (RBAC).
6. Đồng bộ hai chiều trạng thái Sidebar chính xác theo URL / Route kể cả khi tải lại trang (F5) hoặc truy cập URL trực tiếp.

---

## 1. Các Thay Đổi Kiến Trúc & Thiết Kế Đã Triển Khai

### 1.1. Loại bỏ toàn bộ Dropdown & Menu Cha/Con
- Trước đó, Sidebar sử dụng cơ chế Dropdown Accordion (`_buildDropdownParent`) cho các nhóm *Quản lý cộng đồng*, *Quản lý nội dung*, *Hệ thống*, yêu cầu người dùng phải click vào menu cha để bung các menu con.
- Đợt refactor này đã **xóa bỏ hoàn toàn**:
  - Không còn khái niệm menu cha / menu con.
  - Không còn chỉ báo mũi tên mở rộng (`Icons.expand_more`, `Icons.chevron_right`).
  - Không còn trạng thái ẩn/hiện của các tab con.
- **Tất cả các tab được trải phẳng (Flat Navigation):**
  - Mọi tab quản trị đều hiển thị trực tiếp và có thể nhấp chọn ngay lập tức.
  - Các tiêu đề nhóm (`TỔNG QUAN`, `QUẢN LÝ CỘNG ĐỒNG`, `QUẢN LÝ DU LỊCH`, `QUẢN LÝ NỘI DUNG`, `HỆ THỐNG`) đóng vai trò nhãn phân loại tĩnh, không có hành vi click/dropdown.

### 1.2. Giữ nguyên Danh sách Tab & Chuẩn hóa Text-Only
Danh sách 10 tab cốt lõi được giữ nguyên thứ tự và tên chuẩn (`shortTitle`):
1. **Dashboard** (`AdminTab.dashboard`)
2. **Kiểm duyệt bài viết** (`AdminTab.posts`)
3. **Quản lý báo cáo** (`AdminTab.reports`) — kèm badge số lượng chờ xử lý (`badgeCount > 0`)
4. **Quản lý người dùng** (`AdminTab.users`) — kèm nhãn 'Sắp có'
5. **Quản lý địa điểm** (`AdminTab.places`)
6. **Quản lý lịch trình** (`AdminTab.itineraries`) — kèm nhãn 'Sắp có'
7. **Quản lý Media** (`AdminTab.media`)
8. **Khu vực hành chính** (`AdminTab.administrativeAreas`) — kèm nhãn 'Sắp có'
9. **Nhật ký hoạt động** (`AdminTab.auditLogs`) — kèm nhãn 'Sắp có'
10. **Cài đặt** (`AdminTab.settings`) — kèm nhãn 'Sắp có'

**Nguyên tắc hiển thị Text-only:**
- Không có bất kỳ icon nào bên cạnh tên tab.
- Trạng thái chọn (active): Nền `AppColors.primaryLight`, chữ màu đỏ thương hiệu `AppColors.primary` với `FontWeight.w600`.
- Trạng thái không chọn (inactive): Chữ màu `AppColors.textPrimary` với `FontWeight.w400`.
- Header Sidebar hiển thị thương hiệu bằng văn bản thuần túy: `Travel Planner` và `Admin Portal` (hoặc `TP` khi thu gọn).

### 1.3. Đồng bộ Trạng thái Sidebar theo Route & URL (Route Synchronization)
- **Vấn đề trước đây:**
  - Khi người dùng tải lại trang (F5) hoặc nhập trực tiếp URL như `http://localhost:8080/#/reports` hay `http://localhost:8080/#/places`, ứng dụng luôn tự động reset về tab mặc định `dashboard`.
  - Khi người dùng bấm chuyển tab trên Sidebar, URL trên thanh địa chỉ trình duyệt không được cập nhật tương ứng.
- **Giải pháp triệt để:**
  1. **Định nghĩa Route Contract trong `AdminTab` (`admin_tab.dart`):**
     - Bổ sung getter `routePath` ánh xạ từng tab sang path URL chuẩn (`/dashboard`, `/posts`, `/reports`, `/places`, `/media`, v.v.).
     - Bổ sung phương thức phân giải `AdminTab.fromRoute(String? rawRoute)` chuẩn hóa cả hash fragment (`#/reports`) lẫn direct path (`/reports`), tự động fallback an toàn về `dashboard` nếu route rỗng.
  2. **Khởi tạo đúng Route tại `main.dart` & `admin_shell.dart`:**
     - Trong `main.dart`, khi tài khoản đã xác thực, route hiện tại được đọc trực tiếp từ `Uri.base.fragment` hoặc `Uri.base.path` thông qua `AdminTab.fromRoute(...)` và truyền làm `initialTab` cho `AdminShell`.
     - Trong `_AdminShellState.initState()`, kiểm tra và thiết lập `_currentTab` khớp tuyệt đối với URL trình duyệt ngay lần đầu load trang.
  3. **Cập nhật URL không reload qua `SystemNavigator`:**
     - Khi người dùng click chọn tab hoặc chuyển hướng nội bộ (`_onSelectTab`), `AdminShell` gọi `SystemNavigator.routeInformationUpdated(uri: Uri.parse(tab.routePath))`.
     - URL trên thanh địa chỉ trình duyệt lập tức thay đổi mượt mà theo đúng tab tương ứng (hỗ trợ đầy đủ lịch sử trình duyệt, Back/Forward, và Refresh giữ nguyên trang).

### 1.4. Đảm bảo Mỗi Tab mở Một Trang Độc Lập (No Nested Functional Tabs)
- `AdminTab.dashboard` -> `AdminDashboardScreen` (Metric strip & 2-column data grid).
- `AdminTab.posts` -> `AdminPostsScreen` (Header, Toolbar tìm kiếm & lọc ALL/ACTIVE/HIDDEN, DataTable, dialog chi tiết, duyệt/ẩn/purge).
- `AdminTab.reports` -> `AdminReportsScreen` (Header, Toolbar lọc PENDING/RESOLVED/DISMISSED/ALL, DataTable, dialog chi tiết, resolve/dismiss).
- `AdminTab.places` -> `AdminPlacesScreen` (Header, Toolbar danh mục & trạng thái, DataTable & Map preview).
- `AdminTab.media` -> `AdminMediaScreen` (Header, Toolbar trạng thái & dead-letter checkbox, DataTable thumbnail, retry).
- `AdminTab.profile` -> `ProfileScreen`.
- Các tab placeholder -> `PlaceholderFeatureView`.
- **Hoàn toàn không có thanh tab con (nested tabs) bên trong các màn hình chức năng.**

---

## 2. Danh sách Files Chỉnh sửa

1. `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_sidebar.dart`:
   - Xóa bỏ hoàn toàn widget dropdown cha/con `_buildDropdownParent` và các chevron mở rộng.
   - Trải phẳng tất cả các tab menu thành danh sách trực tiếp, text-only.
2. `Travel_Planner/frontend/web/lib/features/layout/domain/admin_tab.dart`:
   - Bổ sung `routePath` và `AdminTab.fromRoute(String? rawRoute)`.
3. `Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart`:
   - Tích hợp đọc route từ trình duyệt khi khởi tạo và cập nhật browser URL qua `SystemNavigator.routeInformationUpdated`.
4. `Travel_Planner/frontend/web/lib/main.dart`:
   - Phân giải URL trình duyệt ban đầu và truyền làm `initialTab` cho `AdminShell`.
5. `Travel_Planner/frontend/web/test/admin_portal_layout_test.dart`:
   - Cập nhật test suite: kiểm tra flat text-only sidebar, kiểm tra phân giải `fromRoute` và `routePath`, kiểm tra các tab độc lập.
6. `Travel_Planner/docs/plan/24-admin-flat-sidebar-route-sync-report.md`: Báo cáo kỹ thuật này.
7. `Travel_Planner/docs/ai/09-development-log.md`: Cập nhật Development Log (tiếng Anh).

---

## 3. Kết quả Kiểm thử & Biên dịch

1. **Flutter Analyze:**
   ```text
   Analyzing web...
   No issues found! (ran in 5.1s)
   ```
   0 errors, 0 warnings, 0 linter issues.

2. **Test Suite (`flutter test`):**
   ```text
   00:13 +69: All tests passed!
   ```
   **69/69 tests passed** (100% pass rate).

3. **Web Production Build (`flutter build web`):**
   ```text
   Compiling lib\main.dart for the Web...                            114.5s
   √ Built build\web
   ```
   Biên dịch thành công gói Web Production với cấu hình API base URL thực tế.

4. **Git Safety Check:**
   Toàn bộ thay đổi nằm trong phạm vi frontend web và tài liệu liên quan, không commit hay push code lên Git remote.
