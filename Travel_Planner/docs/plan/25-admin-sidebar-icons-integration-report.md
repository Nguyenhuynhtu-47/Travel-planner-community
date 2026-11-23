# BÁO CÁO TOÀN DIỆN: TÍCH HỢP ICON ĐỒNG NHẤT CHO SIDEBAR ADMIN (PROFESSIONAL SAAS / ERP)

**Ngày thực hiện:** 23/11/2026  
**Chi nhánh làm việc:** `feature/admin-moderation-integration`  
**Mục tiêu:**
1. Bổ sung hệ thống icon chuẩn mực, dễ nhận diện và nhất quán ngữ nghĩa cho toàn bộ các tab hiện có trên Sidebar Admin của Travel Planner.
2. Giữ nguyên 100% tên tab, thứ tự, cách nhóm danh mục và cơ chế điều hướng phẳng (flat navigation, không dropdown).
3. Đảm bảo kích thước, màu sắc, khoảng cách và tỷ lệ hiển thị đồng nhất theo chuẩn Professional SaaS / ERP Admin Dashboard.
4. Hỗ trợ hiển thị tối ưu cho cả hai chế độ: mở rộng (expanded - 252px) và thu gọn (collapsed - 68px).
5. Không thay đổi giao diện hoặc chức năng ở các khu vực khác.

---

## 1. Hệ Thống Icon Được Tích Hợp

Các icon được lựa chọn từ bộ Material Icons tiêu chuẩn với phong cách `outlined` cho trạng thái bình thường (inactive) và `filled` cho trạng thái kích hoạt (active), đảm bảo độ tương phản cao và tính thẩm mỹ công thái học:

| Nhóm danh mục | Tên Tab (`shortTitle`) | Route Path | Inactive Icon | Active Icon | Ý nghĩa ngữ nghĩa SaaS |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TỔNG QUAN** | Dashboard | `/dashboard` | `Icons.dashboard_outlined` | `Icons.dashboard` | Bảng điều khiển số liệu tổng quan |
| **QUẢN LÝ CỘNG ĐỒNG** | Kiểm duyệt bài viết | `/posts` | `Icons.article_outlined` | `Icons.article` | Quản lý bài đăng, văn bản và hình ảnh |
| | Quản lý báo cáo | `/reports` | `Icons.report_problem_outlined` | `Icons.report_problem` | Báo cáo vi phạm, cờ cảnh báo (kèm badge pending) |
| | Quản lý người dùng | `/users` | `Icons.people_outline` | `Icons.people` | Danh sách tài khoản người dùng và phân quyền |
| **QUẢN LÝ DU LỊCH** | Quản lý địa điểm | `/places` | `Icons.place_outlined` | `Icons.place` | Địa điểm chuẩn hóa trên bản đồ |
| | Quản lý lịch trình | `/itineraries` | `Icons.map_outlined` | `Icons.map` | Lịch trình và lộ trình du lịch cộng đồng |
| **QUẢN LÝ NỘI DUNG** | Quản lý Media | `/media` | `Icons.perm_media_outlined` | `Icons.perm_media` | Tài nguyên ảnh/video trên Cloudinary |
| | Khu vực hành chính | `/administrative-areas` | `Icons.location_city_outlined` | `Icons.location_city` | Tỉnh/thành phố, quận/huyện |
| **HỆ THỐNG** | Nhật ký hoạt động | `/audit-logs` | `Icons.receipt_long_outlined` | `Icons.receipt_long` | Lịch sử thao tác, audit trail |
| | Cài đặt | `/settings` | `Icons.settings_outlined` | `Icons.settings` | Cấu hình tham số hệ thống |

---

## 2. Quy Chuẩn Thiết Kế & Trình Bày (Design Specifications)

### 2.1. Ở chế độ mở rộng (Expanded Mode - Width 252px)
- **Kích thước Icon:** Chuẩn 18px (`size: 18`), vừa vặn với kích thước chữ 13px của tiêu đề tab.
- **Khoảng cách (Spacing):** Khoảng cách cố định 10px (`const SizedBox(width: 10)`) giữa icon và text, đảm bảo thẳng hàng theo trục dọc trên toàn bộ chiều dài sidebar.
- **Màu sắc trạng thái (Semantic Colors):**
  - **Trạng thái Active (đang chọn):**
    - Icon color: `AppColors.primary` (đỏ thương hiệu).
    - Text color: `AppColors.primary`, `fontWeight: FontWeight.w600`.
    - Item background: `AppColors.primaryLight` (`0xFFFEE2E2`).
  - **Trạng thái Inactive (bình thường):**
    - Icon color: `AppColors.textSecondary` (`0xFF6B7280`).
    - Text color: `AppColors.textPrimary` (`0xFF111827`), `fontWeight: FontWeight.w400`.
    - Item background: `Colors.transparent`.
    - Hover color: `AppColors.surfaceSoft` (`0xFFF9FAFB`).
- **Phần phụ trợ:** Giữ nguyên huy hiệu số lượng báo cáo chờ xử lý (`badgeCount > 0`) màu đỏ và nhãn 'Sắp có' màu xám mềm cho các tab placeholder.

### 2.2. Ở chế độ thu gọn (Collapsed Mode - Width 68px)
- **Căn giữa trực quan:** Icon được căn giữa chính xác với kích thước 20px (`size: 20`).
- **Tooltip thông minh:** Bọc trong widget `Tooltip` hiển thị tên đầy đủ của tab (`tab.title`) khi rê chuột.
- **Badge thông báo nổi:** Nếu tab có badge (như báo cáo chờ xử lý), số lượng được hiển thị bằng một badge đỏ nhỏ đặt ở góc trên bên phải icon (`Positioned(top: 0, right: 4)`).

### 2.3. Khu vực Branding & Chân trang
- **Logo Header:** Duy trì icon nhận diện thương hiệu `Icons.travel_explore` kích thước 20px đặt trong khung vuông bo góc nhẹ `AppColors.primaryLight` (32x32px), đi kèm nhãn text `Travel Planner` và `Admin Portal`.
- **Collapse Toggle Control:** Nút thu gọn / mở rộng menu hiển thị chevron chỉ báo `Icons.chevron_left` khi mở rộng và `Icons.chevron_right` khi thu gọn.

---

## 3. Danh Sách Files Thay Đổi

1. `Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_sidebar.dart`:
   - Bổ sung `tab.icon` và `tab.activeIcon` cho từng mục menu trong `_buildMenuItem`.
   - Chuẩn hóa layout `Row` (icon 18px + khoảng cách 10px + text 13px + badges).
   - Tối ưu hóa chế độ thu gọn (icon 20px căn giữa kèm badge thông báo).
2. `Travel_Planner/frontend/web/test/admin_portal_layout_test.dart`:
   - Cập nhật test suite xác minh sự hiện diện của icon ở cả chế độ mở rộng và chế độ thu gọn.
3. `Travel_Planner/docs/plan/25-admin-sidebar-icons-integration-report.md`: Báo cáo kỹ thuật chi tiết.
4. `Travel_Planner/docs/ai/09-development-log.md`: Cập nhật nhật ký phát triển (tiếng Anh).

---

## 4. Kết Quả Kiểm Thử & Nghiệm Thu

1. **Phân tích tĩnh (`flutter analyze`):**
   ```text
   Analyzing web...
   No issues found! (ran in 3.4s)
   ```
   Hoàn toàn không có lỗi (0 errors), không có cảnh báo (0 warnings).

2. **Kiểm thử tự động (`flutter test`):**
   ```text
   00:09 +69: All tests passed!
   ```
   **69/69 tests passed** (100% pass rate).

3. **Biên dịch Production Web (`flutter build web`):**
   ```text
   Compiling lib\main.dart for the Web...                             78.9s
   √ Built build\web
   ```
   Biên dịch thành công gói Web Production với API Base URL thực tế.

4. **Git Safety Check:**
   Không có file backend nào bị thay đổi ngoài ý muốn, không commit hay push code lên Git.
