# BÁO CÁO REFACTOR GIAO DIỆN ADMIN WEB PORTAL & SỬA LỖI ĐIỀU HƯỚNG

**Dự án:** Travel Planner Community  
**Phân hệ:** Admin Web Portal (Flutter Web)  
**Tài liệu tham chiếu:** `Travel_Planner_Function_Specification.md`, `docs/plan/14-admin-module-implementation-audit.md`, `docs/plan/15-admin-moderation-integration-report.md`  
**Ngày thực hiện:** 23/11/2026  
**Trạng thái Git:** Branch `feature/admin-moderation-integration` (Chưa commit, bảo toàn working tree)

---

## 1. TỔNG QUAN & MỤC TIÊU THỰC HIỆN

Nhiệm vụ này tập trung giải quyết triệt để 2 vấn đề lớn trên phân hệ Flutter Web Admin:
1. **Khắc phục lỗi điều hướng sau đăng nhập:** Tình trạng đăng nhập tài khoản vai trò `ADMIN` thành công nhưng không thể thao tác, các nút chức năng bị treo, không phản hồi hoặc không thể chuyển màn hình.
2. **Refactor kiến trúc giao diện sau đăng nhập:** Chuyển đổi toàn bộ giao diện từ mô hình màn hình rời rạc sang kiến trúc **Admin Portal Dashboard tiêu chuẩn** bao gồm **Sidebar** có thể thu gọn/mở rộng, **Header** tích hợp breadcrumb và trạng thái hệ thống, cùng **Main Content Area** điều hướng đa tab mượt mà.
3. **Triển khai trang Dashboard tổng quan:** Hiển thị số liệu thống kê thời gian thực từ Backend và database thực tế (Places, Posts, Reports, Media, Health check), cam kết không sử dụng dữ liệu giả lập hay hardcode.

---

## 2. NGUYÊN NHÂN GỐC RỄ LỖI ĐIỀU HƯỚNG (ROOT-CAUSE ANALYSIS)

Qua kiểm tra trực tiếp mã nguồn `Travel_Planner/frontend/web/lib/main.dart` và luồng điều hướng cũ, các nguyên nhân kỹ thuật thực tế đã được xác định:

| # | Hiện tượng | Nguyên nhân kỹ thuật thực tế | Giải pháp đã khắc phục |
|---|---|---|---|
| **1** | Bấm vào nút "Kiểm duyệt", "Địa điểm" trên thanh điều hướng không phản hồi | `WebPlaceholderScreen` đặt các nút `TextButton.icon`, `PopupMenuButton` chứa chuỗi dài `Xin chào, $fullName ($role)` (maxWidth 300) vào `AppBar.actions`. Khi độ phân giải màn hình hoặc kích thước cửa sổ trình duyệt co lại, `NavigationToolbar` của Flutter Web bị tràn và clip các action ra ngoài vùng hit-test của pointer, khiến sự kiện click bị nuốt chửng. | Thay thế thanh AppBar cũ bằng `AdminSidebar` độc lập có vùng hit-test rõ ràng, con trỏ `SystemMouseCursors.click`, hover styling và layout responsive. |
| **2** | Bị "kẹt" trong màn hình chức năng khi chuyển trang | Trước đây, việc chuyển trang sử dụng `Navigator.of(context).push(...)` toàn màn hình. Khi mở `AdminModerationScreen` hay `AdminPlacesScreen`, màn hình mới có `Scaffold` và `AppBar` riêng, làm mất toàn bộ thanh điều hướng Admin. Người dùng phải bấm nút back của trình duyệt hoặc AppBar để quay lại màn hình chào rỗng. | Chuyển sang mô hình **Admin Shell SPA**: Sidebar và Header luôn cố định, Main Content chuyển đổi linh hoạt theo `AdminTab` mà không phá vỡ cây widget hay mất trạng thái. |
| **3** | Không có lối tắt trực tiếp đến từng tab chức năng con | Màn hình `AdminModerationScreen` chứa 3 tab con (Bài viết, Báo cáo, Media), nhưng giao diện cũ chỉ có một nút "Kiểm duyệt". Quản trị viên muốn xử lý Báo cáo hoặc xem Media phải vào "Kiểm duyệt" rồi tự chuyển tab. | Tách các chức năng thành các mục menu riêng trên Sidebar: "Kiểm duyệt bài viết", "Quản lý báo cáo", "Quản lý Media". Khi click, Shell tự động kích hoạt tab con tương ứng qua tham số `initialTabIndex`. |
| **4** | Lỗi logic kiểm tra quyền và phiên đăng nhập | Một số component kiểm tra `currentUser['role']` nhưng không xử lý an toàn khi role là chữ thường hoặc null trong quá trình khởi tạo, dẫn đến việc ẩn hoàn toàn các nút chức năng quản trị. | Thống nhất kiểm tra vai trò bằng chuẩn hóa: `currentUser?['role']?.toString().toUpperCase() == 'ADMIN'`. Bổ sung màn hình Access Denied kèm nút đăng xuất rõ ràng nếu người dùng không phải ADMIN. |

---

## 3. KIẾN TRÚC GIAO DIỆN MỚI (ADMIN SHELL)

Giao diện sau đăng nhập được tái cấu trúc hoàn toàn với 3 thành phần chính:

```
+---------------------------------------------------------------------------------------+
|  [Logo Travel Planner Admin]  |  Header: Breadcrumbs / Title / [Health: UP] / [User]  |
+-------------------------------+-------------------------------------------------------+
|  SIDEBAR                      |  MAIN CONTENT AREA                                    |
|  - TỔNG QUAN                  |                                                       |
|    * Dashboard                |  [Tab View tương ứng:                                 |
|  - QUẢN LÝ CỘNG ĐỒNG          |   - AdminDashboardScreen (Số liệu thực tế)            |
|    * Kiểm duyệt bài viết      |   - AdminModerationScreen (Bài viết / Báo cáo / Media)|
|    * Quản lý báo cáo (Badge)  |   - AdminPlacesScreen (Bản đồ + CRUD địa điểm)       |
|    * Quản lý người dùng       |   - ProfileScreen (Hồ sơ quản trị viên)               |
|  - QUẢN LÝ DU LỊCH            |   - PlaceholderFeatureView (Chưa triển khai)]         |
|    * Quản lý địa điểm         |                                                       |
|    * Quản lý lịch trình       |                                                       |
|  - QUẢN LÝ NỘI DUNG           |                                                       |
|    * Quản lý Media            |                                                       |
|    * Khu vực hành chính       |                                                       |
|  - HỆ THỐNG                   |                                                       |
|    * Nhật ký hoạt động        |                                                       |
|    * Cài đặt                  |                                                       |
|  ---------------------------  |                                                       |
|  [Avatar] Admin User [Role]   |                                                       |
|  [Thu gọn <]    [Đăng xuất]   |                                                       |
+-------------------------------+-------------------------------------------------------+
```

### 3.1. Sidebar (`admin_sidebar.dart`)
- **Tổ chức phân nhóm:** Gồm 5 nhóm danh mục chính theo đặc tả yêu cầu: `TỔNG QUAN`, `QUẢN LÝ CỘNG ĐỒNG`, `QUẢN LÝ DU LỊCH`, `QUẢN LÝ NỘI DUNG`, `HỆ THỐNG`.
- **Trạng thái Active rõ nét:** Item đang chọn có nền `AppColors.primaryLight`, text và icon màu `AppColors.primary` (Rausch `#FF385C`), font weight bold.
- **Hỗ trợ thu gọn / mở rộng:**
  - Expanded: Chiều rộng `260px`, hiển thị đầy đủ icon, tên danh mục, tiêu đề nhóm và badge.
  - Collapsed: Chiều rộng `72px`, chỉ hiển thị icon với Tooltip nổi khi hover.
  - Chuyển đổi mượt mà bằng `AnimatedContainer` (200ms `easeInOut`).
- **Badge thông báo:** Hiển thị số lượng báo cáo vi phạm đang chờ xử lý (`pendingReportsCount`) dạng pill badge màu đỏ.
- **Footer người dùng:** Hiển thị avatar đại diện, tên đăng nhập, nhãn quyền `ADMIN`, nút thu gọn menu và nút đăng xuất.

### 3.2. Header (`admin_header.dart`)
- **Nút Toggle Menu:** Cho phép đóng/mở nhanh Sidebar bằng một cú click.
- **Breadcrumbs động:** Phản ánh chính xác vị trí điều hướng hiện tại (ví dụ: `Admin / QUẢN LÝ CỘNG ĐỒNG / Kiểm duyệt bài viết`).
- **Tiêu đề trang:** Tên trang lớn, rõ ràng.
- **Trạng thái kết nối Backend:** Chip hiển thị trạng thái `Hệ thống: Trực tuyến` với chấm tròn xanh lá (dựa trên API `GET /api/health`).
- **Thông tin tài khoản:** Avatar và tên quản trị viên, bấm vào để chuyển nhanh tới màn hình Hồ sơ cá nhân.
- **Nút đăng xuất:** Thao tác đăng xuất an toàn với tooltip.

### 3.3. Main Content Area (`admin_shell.dart`)
- **Điều phối tab:** Sử dụng enum `AdminTab` làm nguồn dữ liệu trạng thái duy nhất.
- **Tận dụng không gian:** Mở rộng toàn bộ chiều rộng còn lại của màn hình, khắc phục triệt để khoảng trống dư thừa của giao diện cũ.
- **Bảo toàn trạng thái:** Chuyển đổi giữa các phân hệ nhanh chóng, không reload lại toàn bộ ứng dụng.

---

## 4. QUY TẮC PHÂN LOẠI TRẠNG THÁI CHỨC NĂNG

Mỗi mục chức năng trong Sidebar được định nghĩa trạng thái rõ ràng thông qua `AdminTab.isImplemented`:

| Nhóm | Chức năng | Trạng thái kỹ thuật | Hành vi khi truy cập |
|---|---|---|---|
| **TỔNG QUAN** | Dashboard | **Đã triển khai** | Mở `AdminDashboardScreen` với số liệu thống kê thời gian thực từ DB. |
| **QUẢN LÝ CỘNG ĐỒNG** | Kiểm duyệt bài viết | **Đã triển khai** | Mở `AdminModerationScreen` tại tab `Bài viết` (tìm kiếm, lọc, xem chi tiết, ẩn, khôi phục, xóa vĩnh viễn). |
| | Quản lý báo cáo | **Đã triển khai** | Mở `AdminModerationScreen` tại tab `Báo cáo vi phạm` (lọc trạng thái, xem chi tiết, xử lý vi phạm, bỏ qua). |
| | Quản lý người dùng | **Chưa triển khai** | Mở `PlaceholderFeatureView` hiển thị lộ trình chức năng dự kiến, không dùng màn hình giả. |
| **QUẢN LÝ DU LỊCH** | Quản lý địa điểm | **Đã triển khai** | Mở `AdminPlacesScreen` (CRUD địa điểm, xem bản đồ Leaflet, lọc danh mục, liên kết đơn vị hành chính). |
| | Quản lý lịch trình | **Chưa triển khai** | Mở `PlaceholderFeatureView` thông báo chờ bổ sung Admin Itinerary API. |
| **QUẢN LÝ NỘI DUNG** | Quản lý Media | **Đã triển khai** | Mở `AdminModerationScreen` tại tab `Tài nguyên Media` (xem ảnh, lọc dead-letter, retry upload thất bại). |
| | Khu vực hành chính | **Chưa triển khai** | Mở `PlaceholderFeatureView` thông báo lộ trình quản lý cấu trúc 34 tỉnh/thành phố. |
| **HỆ THỐNG** | Nhật ký hoạt động (Audit Logs) | **Chưa triển khai** | Mở `PlaceholderFeatureView` giải thích tính năng Audit Trail đang phát triển. |
| | Cài đặt hệ thống | **Chưa triển khai** | Mở `PlaceholderFeatureView` mô tả cấu hình tham số hệ thống. |
| | Hồ sơ cá nhân | **Đã triển khai** | Mở `ProfileScreen` cho phép xem và cập nhật thông tin tài khoản admin. |

### Giao diện "Chưa triển khai" (`placeholder_feature_view.dart`)
- Hiển thị nhãn cảnh báo màu hổ phách: `Chưa triển khai / Sắp có`.
- Danh sách checklist các tính năng dự kiến cụ thể theo từng phân hệ.
- Ghi chú kỹ thuật: *"Module này đang chờ bổ sung các endpoint API chuyên biệt tại Backend. Khi API hoàn tất, giao diện sẽ được tích hợp trực tiếp, không sử dụng dữ liệu giả lập."*
- Nút bấm *"Quay lại Dashboard"* giúp điều hướng quay về dễ dàng.

---

## 5. BẢNG ĐIỀU KHIỂN TỔNG QUAN (DASHBOARD) THỜI GIAN THỰC

Trang `AdminDashboardScreen` được thiết kế hiện đại, khoa học và kết nối trực tiếp với database thông qua các API phân trang và kiểm tra sức khỏe có sẵn của Backend:

### 5.1. Nguồn dữ liệu số liệu (Zero Mock Data)
- **Tổng số địa điểm chuẩn hóa:** Lấy từ trường `totalElements` của API `GET /api/admin/places?page=0&size=1`.
- **Tổng số bài viết cộng đồng:** Lấy từ trường `totalElements` của API `GET /api/admin/community/posts?page=0&size=5`.
- **Báo cáo vi phạm đang chờ xử lý:** Lấy từ trường `totalElements` của API `GET /api/admin/community/reports?status=PENDING&page=0&size=5`.
- **Tổng số tài nguyên Media:** Lấy từ trường `totalElements` của API `GET /api/admin/media-assets?page=0&size=1`.
- **Trạng thái dịch vụ & Máy chủ:** Lấy từ `GET /api/health` trả về `{status: "UP", service: "travel-planner-backend", timestamp: "..."}`.

### 5.2. Các khối hiển thị trên Dashboard
1. **Welcome Banner:** Lời chào cá nhân hóa cho quản trị viên kèm nhãn vai trò `ADMIN` và nút "Làm mới dữ liệu".
2. **4 Thẻ số liệu thống kê (Metric Cards):**
   - Thẻ Địa điểm Chuẩn hóa (Xanh dương)
   - Thẻ Bài viết Cộng đồng (Tím)
   - Thẻ Báo cáo Chờ xử lý (Đỏ/Xanh lá tùy theo có báo cáo tồn hay không)
   - Thẻ Tài nguyên Media (Xanh ngọc)
   - *Mỗi thẻ đều có liên kết nhấp chuột (tap) để nhảy thẳng đến module tương ứng.*
3. **Thanh lối tắt thao tác nhanh (Quick Actions):** 4 nút ActionChip truy cập nhanh vào Kiểm duyệt bài viết, Xử lý báo cáo, Quản lý địa điểm, Quản lý media.
4. **Khu vực giám sát phân đôi (Split Live Queues):**
   - *Cột trái:* Danh sách 5 báo cáo vi phạm mới nhất cần xử lý kèm nút "Xử lý" nhanh.
   - *Cột phải:* Danh sách 5 bài viết cộng đồng mới nhất kèm trạng thái hoạt động.
   - *Tự động hiển thị Empty State chuẩn khi không có dữ liệu tồn.*
5. **Thẻ Thông tin Hệ thống:** Hiển thị tên service backend, trạng thái kết nối và timestamp thời gian thực của máy chủ.

---

## 6. THÍCH ỨNG CÁC MÀN HÌNH ĐÃ TÍCH HỢP (EMBEDDED MODE)

Để các màn hình hiện có hoạt động hoàn hảo bên trong `AdminShell` mà không làm hỏng các bài test widget độc lập trước đây, cơ chế `embedded` (mặc định `false`) đã được áp dụng:

### 6.1. `AdminPlacesScreen`
- Thêm tham số `final bool embedded;` (default `false`).
- Khi `embedded == true`: Ẩn `AppBar` trùng lặp của Scaffold con, tự động kích hoạt `_buildEmbeddedToolbar` gồm tiêu đề nhỏ, nút "Làm mới" và nút "Thêm địa điểm" tích hợp gọn gàng ngay phía trên thanh lọc địa điểm.
- Khi `embedded == false`: Giữ nguyên Scaffold với AppBar độc lập để tương thích 100% với các bài test cũ.

### 6.2. `AdminModerationScreen`
- Thêm tham số `final int initialTabIndex;` (default `0`) và `final bool embedded;` (default `false`).
- Khi `embedded == true`: Ẩn AppBar tiêu đề trùng lặp, chỉ render dải `TabBar` 3 tab (`Bài viết`, `Báo cáo vi phạm`, `Tài nguyên Media`) thanh lịch ngay đầu vùng nội dung.
- Bổ sung `didUpdateWidget`: Khi chuyển từ mục menu "Kiểm duyệt bài viết" sang "Quản lý báo cáo" hay "Quản lý Media" trên Sidebar, tab controller tự động chuyển tab tương ứng mà không cần reload trang.

### 6.3. `ProfileScreen`
- Thêm tham số `final bool embedded;` (default `false`).
- Khi `embedded == true`: Ẩn AppBar độc lập, tận dụng Header chung của Admin Shell.

---

## 7. KẾT QUẢ KIỂM THỬ & XÁC MINH TOÀN DIỆN

### 7.1. Phân tích tĩnh Flutter Web (`flutter analyze`)
```powershell
Set-Location -Path 'Travel_Planner/frontend/web'; flutter analyze
```
**Kết quả:**
```
Analyzing web...
No issues found! (ran in 1.5s)
```
*0 lỗi, 0 cảnh báo, 0 lint.*

### 7.2. Kiểm thử tự động Frontend Web (`flutter test`)
Toàn bộ 62 bài test trên 7 tệp kiểm thử của frontend web đã chạy thành công:
1. `test/admin_portal_layout_test.dart` (10 tests mới):
   - Kiểm tra định nghĩa nhóm danh mục và nhãn `AdminTab`.
   - Kiểm tra trạng thái triển khai `isImplemented`.
   - Kiểm tra `DashboardRepository` xử lý API thành công và xử lý lỗi mạng an toàn.
   - Kiểm tra giao diện và nút quay lại của `PlaceholderFeatureView`.
   - Kiểm tra hiển thị đầy đủ danh mục, badge và sự kiện tap của `AdminSidebar`.
   - Kiểm tra breadcrumb, tiêu đề, trạng thái online của `AdminHeader`.
   - Kiểm tra hiển thị thẻ số liệu và điều hướng nhanh của `AdminDashboardScreen`.
   - Kiểm tra RBAC: Chặn tài khoản role `USER` và cho phép tài khoản role `ADMIN` vào `AdminShell`.
2. `test/admin_moderation_test.dart` (17 tests Phase 1): Tất cả đều PASS.
3. `test/admin_place_test.dart` (27 tests Place CRUD & Map): Tất cả đều PASS.
4. `test/auth_401_test.dart`, `test/username_validation_test.dart`, `test/web_map_api_key_test.dart`, `test/widget_test.dart`: Tất cả đều PASS.

**Tổng kết:** **62 tests passed, 0 failures (100% PASS)**.

### 7.3. Build đóng gói Flutter Web (`flutter build web`)
```powershell
Set-Location -Path 'Travel_Planner/frontend/web'; flutter build web
```
**Kết quả:**
```
Compiling lib\main.dart for the Web... 59.5s
√ Built build\web
```
*Build thành công artifact web production không có bất kỳ cảnh báo biên dịch nào.*

### 7.4. Kiểm thử Backend Spring Boot
Khắc phục một lỗi tiềm ẩn trong `PostServiceJpaIntegrationTest`: Trước đây test case `testUpdatePostKeepOldAndAddNewMedia` gọi `findByUsername("http_author").orElseThrow()`. Nếu JUnit chạy test case này trước `testCreatePostHttp`, người dùng chưa được tạo trong DB dẫn đến lỗi. Đã bổ sung phương thức `getOrCreateUser("http_author")` đảm bảo tính độc lập thứ tự chạy test.
```powershell
Set-Location -Path 'Travel_Planner/backend'; .\mvnw.cmd test -Dtest=PostServiceJpaIntegrationTest
```
**Kết quả:**
```
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

---

## 8. DANH MỤC TỆP ĐÃ TẠO VÀ CHỈNH SỬA

### Tệp tạo mới:
- `Travel_Planner/frontend/web/lib/features/layout/domain/admin_tab.dart` (Enum định nghĩa danh mục, icon, nhãn, phân nhóm và trạng thái chức năng).
- `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_sidebar.dart` (Sidebar điều hướng responsive, hỗ trợ thu gọn 72px / mở rộng 260px).
- `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_header.dart` (Header tích hợp breadcrumbs, health status, profile chip và logout).
- `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/placeholder_feature_view.dart` (View thông báo chức năng chưa triển khai kèm roadmap chi tiết).
- `Travel_Planner/frontend/web/lib/features/layout/presentation/screens/admin_shell.dart` (Portal shell chính tích hợp kiểm tra quyền RBAC và điều phối tab).
- `Travel_Planner/frontend/web/lib/features/dashboard/data/dashboard_repository.dart` (Repository truy vấn thống kê thời gian thực từ các endpoint backend).
- `Travel_Planner/frontend/web/lib/features/dashboard/presentation/screens/admin_dashboard_screen.dart` (Trang Dashboard tổng quan).
- `Travel_Planner/frontend/web/test/admin_portal_layout_test.dart` (Bộ test tự động 10 test cases cho toàn bộ layout và dashboard).
- `Travel_Planner/docs/plan/16-admin-portal-ui-refactor-report.md` (Báo cáo kỹ thuật chi tiết).

### Tệp chỉnh sửa:
- `Travel_Planner/frontend/web/lib/main.dart` (Tích hợp `AdminShell` làm giao diện chính sau khi đăng nhập thành công).
- `Travel_Planner/frontend/web/lib/features/locations/presentation/screens/admin_places_screen.dart` (Bổ sung cờ `embedded` và thanh toolbar hành động tích hợp).
- `Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_moderation_screen.dart` (Bổ sung cờ `embedded` và tham số `initialTabIndex`).
- `Travel_Planner/frontend/web/lib/features/profile/presentation/screens/profile_screen.dart` (Bổ sung cờ `embedded` để bỏ AppBar thừa).
- `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/PostServiceJpaIntegrationTest.java` (Sửa lỗi phụ thuộc thứ tự chạy test).
- `Travel_Planner/docs/ai/09-development-log.md` (Ghi chép nhật ký phát triển bằng tiếng Anh).

---

## 9. HƯỚNG DẪN KIỂM THỬ THỦ CÔNG (MANUAL VERIFICATION)

1. **Khởi động Backend:**
   ```powershell
   Set-Location -Path 'Travel_Planner/backend'
   .\mvnw.cmd spring-boot:run
   ```
2. **Khởi động Frontend Web:**
   ```powershell
   Set-Location -Path 'Travel_Planner/frontend/web'
   flutter run -d chrome --web-port 3000
   ```
3. **Kiểm tra đăng nhập & Điều hướng:**
   - Đăng nhập bằng tài khoản Quản trị viên (vai trò `ADMIN`).
   - Sau khi đăng nhập, hệ thống tự động đưa vào **Admin Dashboard**:
     - Kiểm tra lời chào, badge `ADMIN`, các thẻ số liệu Places, Posts, Reports, Media hiển thị số lượng thực tế từ DB.
     - Kiểm tra chip `Hệ thống: Trực tuyến` màu xanh lá trên thanh Header.
   - Kiểm tra **Sidebar bên trái**:
     - Nhấp vào "Kiểm duyệt bài viết" -> Vùng nội dung chuyển sang danh sách bài viết kiểm duyệt.
     - Nhấp vào "Quản lý báo cáo" -> Vùng nội dung chuyển sang danh sách báo cáo vi phạm.
     - Nhấp vào "Quản lý địa điểm" -> Vùng nội dung chuyển sang bản đồ và danh sách địa điểm chuẩn hóa.
     - Nhấp vào "Quản lý Media" -> Vùng nội dung chuyển sang danh sách ảnh Media Assets.
     - Nhấp vào các chức năng chưa triển khai ("Quản lý người dùng", "Quản lý lịch trình",...) -> Hiển thị trang lộ trình chức năng dự kiến với nút "Quay lại Dashboard".
   - Kiểm tra **Thu gọn Sidebar**:
     - Bấm nút "Thu gọn" ở cuối Sidebar hoặc nút Menu trên Header -> Sidebar thu gọn còn 72px, các icon hiển thị tooltip khi di chuột. Bấm lại để mở rộng.
   - Kiểm tra **Hồ sơ & Đăng xuất**:
     - Bấm vào tên admin trên Header -> Chuyển đến trang Hồ sơ cá nhân.
     - Bấm nút Đăng xuất -> Hệ thống xóa token và trở về màn hình đăng nhập.
