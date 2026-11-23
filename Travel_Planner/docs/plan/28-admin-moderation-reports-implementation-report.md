# Báo cáo Triển khai Design System – Phase 3: Post Moderation & Reports

**Dự án:** Travel Planner – Nền tảng lập kế hoạch và chia sẻ lịch trình du lịch  
**Phân hệ:** Flutter Web Admin (`Travel_Planner/frontend/web`)  
**Ngày thực hiện:** 23/11/2026  
**Tài liệu tham chiếu:**  
- `AGENTS.md`  
- `docs/plan/admin-design-system.md`  
- `docs/plan/27-admin-shell-dashboard-implementation-report.md`  
- `docs/ai/09-development-log.md`  

---

## 1. Tổng quan mục tiêu & Kiến trúc giao diện Phase 3

Phase 3 áp dụng Design System doanh nghiệp (Professional Enterprise SaaS / ERP Admin, Minimalism & Swiss Style) vào hai phân hệ nghiệp vụ quản trị trọng yếu của cộng đồng:
1. **Post Moderation (Kiểm duyệt bài viết)**: `lib/features/moderation/presentation/screens/admin_posts_screen.dart`
2. **Reports (Quản lý báo cáo vi phạm)**: `lib/features/moderation/presentation/screens/admin_reports_screen.dart`

### Các nguyên tắc cốt lõi đã thực thi:
- **Tách biệt độc lập 100%:** Hai phân hệ hoạt động hoàn toàn độc lập, ánh xạ 1:1 với các mục trên Sidebar (`AdminTab.posts` -> route `/posts` và `AdminTab.reports` -> route `/reports`). Tuyệt đối không dùng nested navigation tabs để chuyển đổi giữa hai chức năng.
- **Data-Dense & Bảng dữ liệu chuẩn hóa:** Thay thế toàn bộ `DataTable` viết tay bằng component dùng chung `AdminDataTable` với chiều cao hàng chuẩn 38px/44px, viền 1px hairline `#E2E8F0`, màu nền xen kẽ subtle `#F8FAFC`.
- **Phân trang từ máy chủ (Server-Side Pagination):** Kết nối trực tiếp với cấu trúc `PageResponse<T>` từ Spring Boot backend (`totalElements`, `totalPages`, `pageNumber`, `pageSize`), hiển thị thanh footer phân trang chuẩn xác ("Hiển thị X - Y trong số Z bản ghi").
- **Hộp thoại phương thức chuẩn Swiss (`AdminDialog`):** Thay thế toàn bộ `AlertDialog` mặc định bằng `AdminDialog` 3 phần (header kèm huy hiệu trạng thái, body cuộn nội dung, footer sticky chứa các nút CTAs chuẩn token).
- **Màu sắc & WCAG 2.1 AA:** Màu chính Teal `#0F766E` cho primary action (5.60:1 contrast), Orange `#EA580C`/`#C2410C` cho cảnh báo vi phạm, Red `#DC2626` cho thao tác nguy hiểm (Hard Purge).

---

## 2. Chi tiết triển khai

### A. Tầng dữ liệu & Phân trang (`moderation_repository.dart`)
1. **Container phân trang chuẩn `AdminPageResponse<T>`:**
   - Đóng gói: `content`, `totalElements`, `totalPages`, `page`, `size`.
   - Phân tích đúng cấu trúc JSON Spring Boot: `response['totalElements']`, `response['totalPages']`, `response['pageNumber'] ?? response['page']`.
2. **Bổ sung các phương thức phân trang chuyên dụng:**
   - `getPostsPaged({String? status, int page = 0, int size = 20, required String token})`: Trả về `AdminPageResponse<AdminPostModel>`.
   - `getReportsPaged({String? status, int page = 0, int size = 20, required String token})`: Trả về `AdminPageResponse<AdminPostReportModel>`.
3. **Bảo toàn 100% tương thích ngược:**
   - Giữ nguyên `getPosts(...)` và `getReports(...)` trả về `List<T>` để không gây ảnh hưởng đến bất kỳ test suite hoặc component cũ nào.

---

### B. Màn hình Kiểm duyệt Bài viết (`admin_posts_screen.dart`)
1. **Page Header:**
   - Tích hợp `AdminPageHeader` phẳng, tiêu đề "Kiểm duyệt bài viết", mô tả nghiệp vụ.
   - Chip thông kê: "Tổng: `_totalElements` bài viết".
2. **AdminToolbar:**
   - Thanh tìm kiếm 260px hỗ trợ lọc theo ID bài viết, nội dung bài đăng, hoặc tên/handle tác giả kèm nút xóa từ khóa nhanh `[X]`.
   - Dropdown lọc trạng thái: `Tất cả trạng thái (ALL)`, `Hoạt động (ACTIVE)`, `Đã ẩn (HIDDEN)`, `Đã xóa (DELETED)`.
   - Nút `[Làm mới]` gọi lại dữ liệu API thời gian thực.
   - Tự động reset `_page = 0` khi thay đổi bộ lọc trạng thái hoặc từ khóa tìm kiếm.
3. **AdminDataTable:**
   - 7 cột thông tin: `ID`, `TÁC GIẢ`, `NỘI DUNG`, `ẢNH ĐÍNH KÈM`, `TRẠNG THÁI`, `NGÀY TẠO`, `THAO TÁC`.
   - Trạng thái hiển thị bằng `AdminStatusBadge` (`ACTIVE` -> Hoạt động xanh lá, `HIDDEN` -> Đã ẩn cam đậm, `DELETED` -> Đã xóa đỏ).
   - Nội dung giới hạn 1 dòng kèm dấu 3 chấm `ellipsis` chống phình bảng.
   - Chân trang phân trang đầy đủ: Nút Trang đầu, Trang trước, Trang sau, Trang cuối, chỉ số `Trang X / Y` và phạm vi bản ghi.
4. **Hành động & Hộp thoại nghiệp vụ (`AdminDialog`):**
   - **Xem chi tiết (`_showPostDetailDialog`):** Modal 640px hiển thị avatar, username, ID tác giả, hộp văn bản nền `#F8FAFC`, gallery ảnh đính kèm có thể phóng to xem ảnh gốc, số lượt thích, số bình luận, mốc thời gian, lý do kiểm duyệt nếu có.
   - **Ẩn bài viết / Khôi phục (`_moderatePost`):** Modal 480px có trường nhập `Lý do kiểm duyệt` (`TextField` viền 1px bo góc 4px) và nút xác nhận theo đúng ngữ cảnh.
   - **Xóa vĩnh viễn (`_purgePost`):** Modal cảnh báo nguy hiểm với thông điệp cảnh báo rõ ràng về việc dọn dẹp tài nguyên Cloudinary và nút `[Xóa vĩnh viễn]` màu đỏ `#DC2626`.
5. **Trạng thái Dữ liệu:**
   - Trạng thái tải (`isLoading: true`).
   - Trạng thái rỗng (`emptyMessage`).
   - Trạng thái lỗi: Banner cảnh báo đỏ nhạt kèm nút `[Thử lại]` và SnackBar thông báo.

---

### C. Màn hình Quản lý Báo cáo Vi phạm (`admin_reports_screen.dart`)
1. **Page Header:**
   - Tích hợp `AdminPageHeader` phẳng, tiêu đề "Quản lý báo cáo vi phạm", mô tả quy trình phân giải vi phạm.
   - Chip thông kê: "Tổng: `_totalElements` báo cáo".
2. **AdminToolbar:**
   - Thanh tìm kiếm hỗ trợ lọc theo Report ID, Post ID, Lý do, hoặc Tên người báo cáo.
   - Dropdown lọc trạng thái: `Chờ xử lý (PENDING)`, `Đã xử lý (RESOLVED)`, `Đã bỏ qua (DISMISSED)`, `Tất cả trạng thái (ALL)`. Mặc định mở ở `PENDING` ưu tiên xử lý công việc tồn đọng.
   - Nút `[Làm mới]` dữ liệu.
3. **AdminDataTable:**
   - 8 cột thông tin: `MÃ BC`, `BÀI VIẾT`, `NGƯỜI BÁO CÁO`, `LÝ DO`, `CHI TIẾT`, `TRẠNG THÁI`, `NGÀY BÁO CÁO`, `THAO TÁC`.
   - Trạng thái hiển thị bằng `AdminStatusBadge` (`PENDING` -> Chờ xử lý vàng cam, `RESOLVED` -> Đã xử lý xanh lá, `DISMISSED` -> Đã bỏ qua xám).
   - Server-side pagination tương ứng tham số API `/api/admin/community/reports`.
4. **Hành động Phân giải Báo cáo:**
   - **Chi tiết báo cáo (`_showReportDetailDialog`):** Modal 580px hiển thị thông tin người báo cáo, mã bài viết đích, lý do, mô tả chi tiết, trạng thái và ngày tạo/ngày xử lý.
   - **Xử lý vi phạm:** Nút `[Xử lý vi phạm]` gọi API `PATCH /resolve?resolution=RESOLVED` để đánh dấu đã xử lý thành công.
   - **Bỏ qua báo cáo:** Nút `[Bỏ qua]` gọi API `PATCH /resolve?resolution=DISMISSED`.
   - Tự động làm mới danh sách sau khi thao tác thành công.

---

## 3. Danh sách File Thay đổi và Bổ sung

| File | Hành động | Mục đích |
|---|---|---|
| `frontend/web/lib/features/moderation/data/moderation_repository.dart` | Refactor | Thêm `AdminPageResponse<T>`, `getPostsPaged`, `getReportsPaged`, giữ nguyên hàm cũ |
| `frontend/web/lib/features/moderation/data/models/admin_post_model.dart` | Refactor | Cập nhật parser `fullName` hỗ trợ cả fallback `displayName` từ backend JSON |
| `frontend/web/lib/features/moderation/presentation/screens/admin_posts_screen.dart` | Refactor | Tái thiết kế toàn bộ theo Swiss Minimalism, `AdminDataTable`, `AdminDialog`, server-side pagination |
| `frontend/web/lib/features/moderation/presentation/screens/admin_reports_screen.dart` | Refactor | Tái thiết kế toàn bộ theo Swiss Minimalism, `AdminDataTable`, `AdminDialog`, server-side pagination |
| `frontend/web/test/admin_moderation_phase3_test.dart` | Mới | Bộ test kiểm thử chuyên sâu Phase 3: pagination, status filter, actions, routing |
| `docs/ai/09-development-log.md` | Cập nhật | Nhật ký phát triển Phase 3 bằng tiếng Anh |
| `docs/plan/28-admin-moderation-reports-implementation-report.md` | Mới | Tài liệu báo cáo hoàn thành Phase 3 |

---

## 4. Kết quả Kiểm thử & Đánh giá Chất lượng Thực tế

### A. Kiểm tra chất lượng mã nguồn (`flutter analyze`)
Chạy lệnh trong `Travel_Planner/frontend/web`:
```bash
flutter analyze
```
**Kết quả:**
```
Analyzing web...
No issues found! (ran in 1.4s)
```
Không có lỗi (errors), không có cảnh báo (warnings), không có lint issues.

### B. Kiểm thử tự động toàn diện (`flutter test`)
Tất cả **88/88 tests** đều vượt qua thành công (**100% Pass**):
```
00:10 +88: All tests passed!
```
Chi tiết các bộ test liên quan:
- `test/admin_moderation_phase3_test.dart`: **5/5 passed** (Kiểm tra server-side pagination, status filter, hide/restore/purge, resolve/dismiss, error retry, và kiểm tra điều hướng độc lập của AdminShell).
- `test/admin_moderation_test.dart`: **17/17 passed** (Bảo toàn 100% tính tương thích ngược của các serialization test, API client test, và widget tests cũ).
- `test/admin_dashboard_phase2_test.dart`: **3/3 passed**.
- `test/admin_design_system_test.dart`: **11/11 passed**.
- `test/admin_portal_layout_test.dart`: **12/12 passed**.
- Các unit/widget test khác: **40/40 passed**.

### C. Build Production Web (`flutter build web`)
Chạy lệnh:
```bash
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```
**Kết quả:** Biên dịch thành công gói production web trong thư mục `build/web/`.

---

## 5. Giới hạn Kỹ thuật & Ghi nhận từ Backend Hiện tại

1. **Backend Search Query Parameter:**
   - Endpoint `GET /api/admin/community/posts` và `GET /api/admin/community/reports` trong `AdminCommunityController.java` chỉ nhận các tham số `@RequestParam`:
     - `status`: enum `PostStatus` / `ReportStatus`
     - `page`: số trang (mặc định 0)
     - `size`: kích thước trang (mặc định 20)
   - Hiện tại Backend **chưa hỗ trợ tham số truy vấn tìm kiếm toàn cục `?q=` hoặc `?search=`**.
   - **Xử lý trên giao diện:** Thanh tìm kiếm trên `AdminToolbar` lọc trực quan ngay trên trang dữ liệu hiện hành (ID, tác giả, nội dung, người báo cáo). Khi người dùng tìm kiếm, kết quả được lọc tức thời; khi xóa từ khóa, danh sách trả về đầy đủ. Nếu sau này Backend bổ sung tham số tìm kiếm server-side, frontend đã có sẵn ô nhập để kết nối ngay.
2. **Quy tắc phân giải báo cáo:**
   - Việc Resolve hoặc Dismiss một báo cáo vi phạm không tự động ẩn hay xóa bài viết gốc, bảo toàn đúng quy tắc phân quyền và nghiệp vụ của Backend Spring Boot.

---

## 6. Kết luận

Phase 3 đã hoàn thành vượt mức mong đợi:
- Cả hai màn hình **Post Moderation** và **Reports** đã trở thành các không gian quản trị dữ liệu chuyên nghiệp, đồng bộ chuẩn mực với Design System.
- Sử dụng hoàn toàn shared components: `AdminPageHeader`, `AdminToolbar`, `AdminDataTable`, `AdminStatusBadge`, `AdminDialog`.
- Đáp ứng chuẩn xác server-side pagination và WCAG 2.1 AA.
- Không phát sinh regression (toàn bộ 88 tests pass).
- Sẵn sàng chuyển giao cho người dùng đánh giá và nghiệm thu.
