# Báo cáo Triển khai Design System – Phase 2: Admin Shell & Dashboard

**Dự án:** Travel Planner – Nền tảng lập kế hoạch và chia sẻ lịch trình du lịch  
**Phân hệ:** Flutter Web Admin (`Travel_Planner/frontend/web`)  
**Ngày thực hiện:** 23/11/2026  
**Tài liệu tham chiếu:**  
- `docs/plan/admin-design-system.md`  
- `docs/plan/26-admin-design-system-shared-components-report.md`  
- `docs/ai/09-development-log.md`  
- `AGENTS.md`  

---

## 1. Tổng quan mục tiêu & Định hướng thiết kế

Giai đoạn 2 tập trung đưa Design System đã chuẩn hóa từ tài liệu và bộ shared components (Phase 1) vào **giao diện thực tế của phân hệ quản trị Web Admin**, với trọng tâm là **Admin Shell** (bộ khung điều hướng) và **Dashboard** (bảng điều khiển vận hành thời gian thực).

### Triết lý thiết kế: Professional Enterprise SaaS / ERP Admin (Minimalism & Swiss Style)
- **Data-Dense & Pragmatic:** Loại bỏ hoàn toàn các thẻ card nổi khối, gradient trang trí, shadow đa tầng và hình minh họa không mang giá trị vận hành.
- **Canvas phẳng & Khung viền sắc nét:** Nền trắng `#FFFFFF`, bề mặt phụ `#F8FAFC`, phân tách không gian bằng đường hairline 1px `#E2E8F0` và lưới 4px có kỷ luật.
- **Màu sắc thương hiệu & WCAG 2.1 AA:** Giữ vững nhận diện Teal `#0F766E` (tỷ lệ tương phản 5.60:1 trên chữ trắng) và Orange `#EA580C`/`#C2410C` làm điểm nhấn cảnh báo (tương phản 6.3:1 trên nền `#FFF7ED`).
- **Nói KHÔNG với số liệu giả:** Chỉ hiển thị các số liệu, bài viết và báo cáo thực tế từ API Backend hiện có (`/api/health`, `/api/admin/places`, `/api/admin/community/posts`, `/api/admin/community/reports`, `/api/admin/media-assets`). Tuyệt đối không tạo biểu đồ giả tưởng hay mockup hardcode khi Backend chưa cung cấp time-series API.

---

## 2. Kết quả triển khai chi tiết

### A. Admin Shell (Khung điều hướng tổng thể)

1. **AdminSidebar (`lib/features/layout/presentation/widgets/admin_sidebar.dart`):**
   - **Bảo toàn 100% cấu trúc menu:** Giữ nguyên toàn bộ 10 mục điều hướng, 5 nhóm chức năng, thứ tự và icon chuyên dụng:
     - `TỔNG QUAN`: Tổng quan (Dashboard)
     - `QUẢN LÝ CỘNG ĐỒNG`: Kiểm duyệt bài viết, Quản lý báo cáo, Người dùng
     - `QUẢN LÝ DU LỊCH`: Quản lý địa điểm, Lịch trình du lịch
     - `QUẢN LÝ NỘI DUNG`: Quản lý Media, Địa giới hành chính
     - `HỆ THỐNG`: Nhật ký kiểm toán, Cài đặt hệ thống
   - **Tối ưu hóa trạng thái Active:** Thay thế viền dày hoặc card nổi bằng thanh chỉ báo 3px Teal (`#0F766E`) ở mép trái, kèm lớp phủ màu nền siêu nhẹ `#F0FDFA` và chữ đậm vừa (`FontWeight.w600`).
   - **Huy hiệu số lượng (Badge):** Hiển thị số báo cáo chờ xử lý bằng màu Orange `#EA580C` trên nền `#FFF7ED`, bo góc 4px.
   - **Thu gọn / Mở rộng (Collapse/Expand) mượt mà:** Sử dụng `OverflowBox` kết hợp `ClipRect` bên trong `AnimatedContainer`, loại bỏ hoàn toàn hiện tượng tràn pixel (overflow) trong suốt 180ms chuyển đổi kích thước giữa 68px và 240px.

2. **AdminHeader (`lib/features/layout/presentation/widgets/admin_header.dart`):**
   - **Chiều cao chuẩn mực:** Cố định 52px (`AppHeights.header`), nền trắng viền dưới 1px `#E2E8F0`.
   - **Breadcrumbs phẳng & Chống tràn:** Hiển thị đường dẫn phẳng (`Admin / NHÓM / Mục con | Tiêu đề trang`) kèm cơ chế trượt ngang chống tràn trên màn hình hẹp.
   - **Trạng thái hệ thống (Telemetry Badge):** Chip hiển thị trạng thái Backend (`Hệ thống: Trực tuyến` hoặc `Hệ thống: UNAVAILABLE`) sử dụng semantic tokens (xanh lá `#16A34A` / cam `#EA580C`), bo góc 4px, không lạm dụng shadow.
   - **Khu vực người dùng:** Chip hồ sơ tài khoản và nút đăng xuất đồng bộ với Theme, giữ nguyên các hành vi tương tác trước đây.

3. **AdminShell Container (`lib/features/layout/presentation/screens/admin_shell.dart`):**
   - **Phản hồi linh hoạt (Responsive):** Tự động thu gọn Sidebar sang chế độ icon trên màn hình `< 960px` và giữ nguyên trạng thái mở rộng trên Desktop lớn (`>= 960px`).
   - **Đồng bộ URL 2 chiều:** Giữ nguyên cơ chế đồng bộ hash fragment và pathname (`AdminTab.fromRoute` / `AdminTab.routePath`), đảm bảo điều hướng trực tiếp bằng URL, Reload, Back/Forward không bị mất trạng thái.
   - **Màn hình Từ chối truy cập (Access Denied):** Tái thiết kế container cảnh báo quyền hạn với viền hairline 1px `#E2E8F0`, bo góc 6px, nút Đăng xuất màu đỏ semantic `#DC2626`.

4. **PlaceholderFeatureView (`lib/features/layout/presentation/widgets/placeholder_feature_view.dart`):**
   - Chuẩn hóa màn hình chờ của 5 tính năng trong lộ trình (Người dùng, Lịch trình, Địa giới, Nhật ký, Cài đặt) theo Swiss Minimalism.
   - Thay thế toàn bộ mã màu hardcode màu cam bằng semantic tokens (`AppColors.warningLight`, `AppColors.warningBorder`, `AppColors.warning`).
   - Sử dụng `AppPrimaryButton` cho thao tác "Quay lại Dashboard".

---

### B. Dashboard Vận hành (Operations Dashboard)

Tái cấu trúc toàn bộ `lib/features/dashboard/presentation/screens/admin_dashboard_screen.dart` thành **Bảng điều khiển Vận hành Thời gian thực**:

1. **Page Header:**
   - Sử dụng `AdminPageHeader` phẳng, tiêu đề "Tổng quan Dashboard" kèm mô tả ngữ cảnh.
   - Hiển thị lời chào cá nhân hóa "Xin chào, <tên quản trị viên>!".
   - Chip hiển thị thời gian cập nhật dữ liệu gần nhất dạng `Cập nhật: HH:mm:ss`.
   - Nút hành động `[Làm mới]` cho phép tải lại dữ liệu tức thời qua `RefreshIndicator`.
   - Tự động chuyển đổi thành layout xếp dọc (stacked Wrap) trên màn hình `< 960px`, ngăn ngừa tràn viền.

2. **Dải chỉ số Vận hành (SaaS Metric Strip):**
   - 4 chỉ số cốt lõi tương ứng dữ liệu thực từ Backend:
     1. **Địa điểm chuẩn hóa:** Tổng số địa điểm du lịch trong cơ sở dữ liệu (`/api/admin/places`).
     2. **Bài viết cộng đồng:** Tổng số bài đăng được chia sẻ (`/api/admin/community/posts`).
     3. **Báo cáo chờ xử lý:** Số lượng vi phạm cần kiểm duyệt ngay (`/api/admin/community/reports?status=PENDING`). Sử dụng màu cảnh báo Orange `#C2410C` khi có báo cáo tồn đọng.
     4. **Tài nguyên Media:** Tổng số tài nguyên ảnh lưu trữ Cloudinary (`/api/admin/media-assets`).
   - Thiết kế dạng dải phân cách liền mạch (border-divided strip) trên màn hình `>= 900px` và lưới 2x2 gọn gàng trên màn hình nhỏ. Mỗi ô chỉ số là một nút điều hướng nhanh trực tiếp đến trang quản trị tương ứng.

3. **Khu vực Làm việc Hai Cột (Operational Workspaces):**
   - **Cột Trái – Báo cáo vi phạm chờ xử lý:**
     - Danh sách các báo cáo vi phạm mới nhất lấy từ API thực tế.
     - Hiển thị mã định danh `#reportId`, lý do tố cáo, mã bài viết `#postId`, tài khoản người báo cáo `@reporter`.
     - Nút hành động trực tiếp `[Xử lý]` điều hướng ngay lập tức đến tab Quản lý Báo cáo (`AdminTab.reports`).
   - **Cột Phải – Bài viết cộng đồng gần đây:**
     - Danh sách bài đăng du lịch mới nhất.
     - Avatar ký tự viết tắt của tác giả, username `@handle`, trích đoạn nội dung, số lượng ảnh đính kèm và huy hiệu `AdminStatusBadge` (`ACTIVE`).
     - Nút hành động `[Xem tất cả →]` điều hướng sang tab Kiểm duyệt Bài viết (`AdminTab.posts`).

4. **Thanh Viễn thám Hệ thống (System Telemetry Strip):**
   - Nằm ở chân trang Dashboard, kết nối trực tiếp đến endpoint `/api/health`.
   - Hiển thị tên dịch vụ backend (`travel-planner-backend`), trạng thái vận hành (`UP`) kèm chấm trạng thái xanh lá, và mốc thời gian máy chủ thời gian thực.

5. **Trạng thái Dữ liệu Đầy đủ (Data States):**
   - **Loading State:** Con quay `CircularProgressIndicator` màu Teal `#0F766E` thanh mảnh trên nền trắng.
   - **Empty State:** Thông báo rõ ràng, trang nhã khi chưa có báo cáo hoặc bài viết nào cần xử lý.
   - **Error State & Retry:** Banner lỗi ngữ cảnh đỏ nhạt `#FEF2F2` kèm thông điệp lỗi cụ thể và nút `[Thử lại]` gọi lại hàm tải dữ liệu.

---

## 3. Danh sách File Thay đổi và Bổ sung

| File | Hành động | Mục đích |
|---|---|---|
| `frontend/web/lib/features/layout/presentation/screens/admin_shell.dart` | Refactor | Cập nhật layout container, auto-collapse <960px, chuẩn hóa màn hình Access Denied |
| `frontend/web/lib/features/layout/presentation/widgets/admin_sidebar.dart` | Refactor | Đồng bộ 10 mục menu, chỉ báo active 3px Teal, badge báo cáo, chống tràn subpixel |
| `frontend/web/lib/features/layout/presentation/widgets/admin_header.dart` | Refactor | Đồng bộ breadcrumbs cuộn ngang, telemetry badge, layout 52px chuẩn |
| `frontend/web/lib/features/layout/presentation/widgets/placeholder_feature_view.dart` | Refactor | Thay thế hardcode amber bằng design tokens warning, 4px radius |
| `frontend/web/lib/features/dashboard/presentation/screens/admin_dashboard_screen.dart` | Refactor | Tái thiết kế toàn bộ Dashboard theo Swiss Minimalism, metric strip, telemetry |
| `frontend/web/lib/shared/widgets/admin_page_header.dart` | Refactor | Bổ sung chế độ responsive compact stacking (<960px) chống overflow |
| `frontend/web/test/admin_dashboard_phase2_test.dart` | Mới | Bổ sung bộ kiểm thử tự động cho Dashboard Phase 2 và responsive viewport |
| `docs/ai/09-development-log.md` | Cập nhật | Bổ sung nhật ký phát triển Phase 2 bằng tiếng Anh |
| `docs/plan/27-admin-shell-dashboard-implementation-report.md` | Mới | Tài liệu báo cáo hoàn thành Phase 2 |

---

## 4. Kết quả Kiểm thử & Đánh giá Thực tế

### A. Kiểm tra chất lượng mã nguồn (`flutter analyze`)
Chạy lệnh trong thư mục `Travel_Planner/frontend/web`:
```bash
flutter analyze
```
**Kết quả:**
```
Analyzing web...
No issues found! (ran in 2.5s)
```
Hoàn toàn sạch sẽ, không có bất kỳ error hay warning nào.

### B. Kiểm thử tự động toàn diện (`flutter test`)
Tất cả **83/83 unit tests và widget tests** đều vượt qua thành công:
```
00:09 +82: test/widget_test.dart: Web LoginScreen renders portal title, inputs and buttons
00:09 +83: All tests passed!
```
Bao gồm:
- 11/11 tests trong `test/admin_design_system_test.dart` (Kiểm tra Tokens, WCAG contrast, Shared Components).
- 3/3 tests trong `test/admin_dashboard_phase2_test.dart` (Kiểm tra hiển thị dữ liệu thực, banner lỗi & retry, hành vi responsive <960px).
- 12/12 tests trong `test/admin_portal_layout_test.dart` (Sidebar, Header, Routing, Placeholder).
- Toàn bộ các test của màn hình Places, Moderation, Media, Auth.

### C. Build Production Web (`flutter build web`)
Chạy lệnh:
```bash
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```
**Kết quả:** Build thành công gói production web trong thư mục `build/web/` sẵn sàng triển khai.

---

## 5. Giới hạn Kỹ thuật & Ghi nhận từ Backend Hiện tại

1. **Thiếu API Thống kê Chuỗi Thời gian (Time-series / Analytics API):**
   - Qua khảo sát toàn bộ mã nguồn Backend Spring Boot và tài liệu `docs/ai/03-api-contract.md`, Backend hiện chỉ cung cấp các API lấy danh sách phân trang kèm tổng số bản ghi (`totalElements`) và API kiểm tra sức khỏe (`/api/health`).
   - Hệ thống **chưa có** các endpoint trả về dữ liệu biểu đồ phân tích theo ngày/tháng (ví dụ: lượng người dùng đăng ký mới theo tuần, lưu lượng bài viết theo tháng).
   - **Quyết định tuân thủ:** Nhóm triển khai kiên quyết **không hardcode biểu đồ hoặc sinh dữ liệu giả** để làm giao diện bắt mắt. Thay vào đó, thiết kế tập trung vào **Dải chỉ số vận hành (Metric Strip) và Danh sách công việc cần xử lý ngay (Actionable Lists)**.
   - **Khuyến nghị cho Phase tương lai:** Khi Backend bổ sung endpoint phân tích tổng hợp (e.g. `GET /api/admin/analytics/overview`), giao diện Dashboard đã có sẵn khung sẵn sàng tích hợp biểu đồ thời gian thực.

---

## 6. Kết luận & Lộ trình tiếp theo

Phase 2 đã hoàn thành trọn vẹn và chuẩn mực:
- **Admin Shell** đã trở thành khung điều hướng doanh nghiệp chuyên nghiệp, đồng bộ, linh hoạt trên cả Desktop và màn hình nhỏ, bảo toàn 100% mục lục chức năng và routing.
- **Dashboard** đã lột xác thành Trung tâm Vận hành chuẩn mực, loại bỏ cảm giác landing page / AI prototype, trực quan hóa dữ liệu thực từ hệ thống.
- Tuyệt đối không thay đổi backend, database hay nghiệp vụ. Không commit hay push git ngoài phạm vi yêu cầu.
- Sẵn sàng chuyển giao sang **Phase 3: Áp dụng Design System vào các màn hình nghiệp vụ chuyên sâu (Places, Posts, Reports, Media Assets)**.
