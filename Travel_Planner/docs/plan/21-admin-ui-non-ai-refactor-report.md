# BÁO CÁO REFACTOR GIAO DIỆN WEB ADMIN: PROFESSIONAL NON-AI SAAS / ERP DASHBOARD

**Ngày thực hiện:** 23/11/2026  
**Chi nhánh làm việc:** `feature/admin-moderation-integration`  
**Mục tiêu:** Chuyển đổi toàn diện giao diện Web Admin từ phong cách AI-generated (nhiều card bo tròn, khoảng trắng thừa, icon rực rỡ, thành phần trang trí không cần thiết) sang chuẩn **Professional SaaS / ERP Admin Dashboard** (thực dụng, tập trung dữ liệu, phân cấp rõ nét, đường kẻ hairline tinh tế, mật độ thông tin cao).

---

## 1. Nguyên tắc triển khai và Ràng buộc cốt lõi

1. **Phạm vi thuần UI (UI-Only Refactor):**
   - Không thay đổi bất kỳ logic nghiệp vụ, backend endpoint, database, entity, repository, hay API contract nào.
   - Giữ nguyên toàn bộ 11 tab điều hướng theo đúng thứ tự phân nhóm:
     - **TỔNG QUAN:** Dashboard
     - **QUẢN LÝ CỘNG ĐỒNG:** Kiểm duyệt bài viết, Quản lý báo cáo, Quản lý người dùng
     - **QUẢN LÝ DU LỊCH:** Quản lý địa điểm, Quản lý lịch trình
     - **QUẢN LÝ NỘI DUNG:** Quản lý Media, Đơn vị hành chính
     - **HỆ THỐNG:** Nhật ký kiểm toán, Cấu hình hệ thống
   - Giữ nguyên cơ chế RBAC (`ADMIN` role check), phân quyền, token refresh, và JWT session maintenance.

2. **Các thành phần cụ thể đã loại bỏ theo yêu cầu:**
   - **Footer thông tin người dùng ở đáy `AdminSidebar`:**
     - Loại bỏ Avatar / ký tự đầu, tên tài khoản, badge `ADMIN`, nút đăng xuất khỏi đáy Sidebar.
     - Giữ lại duy nhất nút điều khiển thu gọn / mở rộng menu (collapse/expand toggle button: `chevron_left` / `chevron_right`).
   - **Khu vực Quick Actions ("Lối tắt thao tác nhanh") trên `AdminDashboardScreen`:**
     - Loại bỏ hoàn toàn khối action chips / shortcut buttons để tránh trùng lặp thao tác với Sidebar và Metric cards.
   - **Card Connection & System Status ("Thông tin kết nối & Trạng thái Hệ thống") trên `AdminDashboardScreen`:**
     - Loại bỏ hoàn toàn card này khỏi nội dung Dashboard. Trạng thái backend health (`UP` / `Hệ thống: Trực tuyến`) đã được hiển thị tinh gọn ngay trên `AdminHeader`.

---

## 2. Chi tiết các thành phần giao diện đã refactor

### 2.1. AdminSidebar (`admin_sidebar.dart`)
- **Kích thước & Bố cục:**
  - Chiều rộng: 248px khi mở rộng, 68px khi thu gọn.
  - Border bên phải: 1px hairline (`AppColors.border` #E5E7EB), không dùng shadow.
- **Logo Section:** Chiều cao chuẩn 52px, biểu tượng compact 32x32px với nền `AppColors.primaryLight`, text Travel Planner / Admin Portal tinh giản.
- **Group Headers:** 10.5px, chữ in hoa, màu `AppColors.muted`, khoảng cách gọn gàng (14px top, 4px bottom).
- **Navigation Items:** Chiều cao compact ~36px, bo góc nhẹ 6px, icon 18px. Trạng thái active sử dụng nền `AppColors.primaryLight` và chữ `AppColors.primary` (#FF385C). Không dùng màu sắc sặc sỡ cho từng icon.
- **Collapse Toggle Footer:** Chỉ chứa nút thu gọn / mở rộng menu (nhãn "Thu gọn" với icon chevron ở dạng mở rộng; icon button với tooltip ở dạng thu gọn).

### 2.2. AdminHeader (`admin_header.dart`)
- **Kích thước:** Chiều cao 52px (thay vì 64px), border-bottom 1px hairline sắc nét.
- **Cấu trúc Trái - Phải:**
  - **Trái:** Nút hamburger menu để toggle sidebar.
  - **Giữa:** Breadcrumb phân cấp tinh gọn `Admin / {Nhóm} / {Tab}`, kèm đường phân cách dọc 1px và tiêu đề trang hiện tại.
  - **Phải:**
    - Pill trạng thái hệ thống: Chấm xanh/vàng nhỏ và nhãn `Hệ thống: Trực tuyến`.
    - Profile chip: Avatar tròn nhỏ (radius 13px) kèm tên quản trị viên, click mở nhanh trang Hồ sơ cá nhân.
    - Nút Đăng xuất (`IconButton` với icon logout và tooltip `'Đăng xuất'`).

### 2.3. AdminDashboardScreen (`admin_dashboard_screen.dart`)
- **Header Row:**
  - Chuyển thành một thanh tiêu đề phẳng (flat) với viền 1px, bo góc 8px.
  - Lời chào `Xin chào, {fullName}!` kèm badge `ADMIN` và mô tả ngắn gọn.
  - Nút `Làm mới` (`OutlinedButton.icon`) tích hợp trực tiếp góc phải.
- **Stat Cards (SaaS Metric Tiles):**
  - 4 thẻ metric dạng lưới (Địa điểm chuẩn hóa, Bài viết cộng đồng, Báo cáo chờ xử lý, Tài nguyên Media).
  - Viền 1px hairline, không đổ bóng nổi AI.
  - Con số metric to rõ (24px bold), nhãn xúc tích, subtitle phụ trợ.
  - Giữ nguyên callback `onTap` chuyển hướng trực tiếp sang tab tương ứng khi click.
- **Dữ liệu thời gian thực (Data Sections):**
  - Chia 2 cột cân đối: Báo cáo vi phạm đang chờ duyệt & Bài viết cộng đồng gần đây.
  - Container phẳng viền 1px, đường kẻ phân cách tinh tế, status chips gọn gàng, nút xem tất cả dẫn tới tab chức năng.

### 2.4. PlaceholderFeatureView (`placeholder_feature_view.dart`)
- Chuyển từ card lớn nhiều khoảng trắng sang container chuẩn mực 640px max-width, viền 1px, bo góc 8px.
- Badge "Chưa triển khai" phẳng và tinh tế.
- Danh sách lộ trình chức năng với icon dấu tích gọn gàng, giải thích ngắn gọn về lộ trình API Backend.
- Nút "Quay lại Dashboard" tiêu chuẩn.

### 2.5. ProfileScreen (`profile_screen.dart`)
- Loại bỏ đổ bóng nổi (`0x0A000000`), chuyển toàn bộ card thông tin và form chỉnh sửa sang viền 1px sắc nét với bán kính bo góc 8px/6px.
- Thu gọn avatar kích thước 80px, căn chỉnh form nhập liệu chuyên nghiệp theo phong cách cài đặt tài khoản ERP/SaaS.

---

## 3. Danh sách tệp thay đổi

| STT | Đường dẫn tệp | Mục đích thay đổi |
|---|---|---|
| 1 | `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_sidebar.dart` | Refactor thanh menu bên: bỏ footer user info/badge/logout, giữ toggle collapse, chuẩn hóa style SaaS |
| 2 | `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_header.dart` | Tinh gọn header (52px), breadcrumb thẳng hàng, tích hợp health status, user chip và logout button |
| 3 | `Travel_Planner/frontend/web/lib/features/dashboard/presentation/screens/admin_dashboard_screen.dart` | Loại bỏ Quick Actions & System Status Card, refactor header flat, 4 metric tiles phẳng, data list gọn |
| 4 | `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/placeholder_feature_view.dart` | Refactor view placeholder sang giao diện container gọn, viền 1px, typography chuyên nghiệp |
| 5 | `Travel_Planner/frontend/web/lib/features/profile/presentation/screens/profile_screen.dart` | Tinh giản view & form hồ sơ quản trị viên, loại bỏ shadow, bo góc 8px |
| 6 | `Travel_Planner/frontend/web/test/admin_portal_layout_test.dart` | Điều chỉnh assertion phù hợp với việc bỏ Quick Actions và footer logout ở sidebar |

---

## 4. Kết quả Kiểm thử & Biên dịch

1. **Flutter Tests (`flutter test`):**
   - Chạy toàn bộ 67/67 unit & widget tests của Web Admin.
   - **Kết quả:** `00:20 +67: All tests passed!`.
2. **Flutter Static Analysis (`flutter analyze`):**
   - Phân tích toàn bộ mã nguồn `frontend/web`.
   - **Kết quả:** `No issues found! (ran in 2.7s)`.
3. **Flutter Web Build (`flutter build web`):**
   - Biên dịch web với cờ `API_BASE_URL`:
   - **Kết quả:** `√ Built build\web (80.2s)`.
