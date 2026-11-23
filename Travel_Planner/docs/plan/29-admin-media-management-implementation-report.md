# Báo cáo Triển khai Design System – Phase 4: Media Management

**Dự án:** Travel Planner – Nền tảng lập kế hoạch và chia sẻ lịch trình du lịch  
**Phân hệ:** Flutter Web Admin (`Travel_Planner/frontend/web`)  
**Ngày thực hiện:** 23/11/2026  
**Tài liệu tham chiếu:**  
- `AGENTS.md`  
- `docs/plan/admin-design-system.md`  
- `docs/plan/27-admin-shell-dashboard-implementation-report.md`  
- `docs/plan/28-admin-moderation-reports-implementation-report.md`  
- `docs/ai/09-development-log.md`  

---

## 1. Tổng quan mục tiêu & Kiến trúc giao diện Phase 4

Phase 4 hoàn thiện việc chuyển đổi phân hệ **Media Management (Quản lý tài nguyên media)** sang ngôn ngữ thiết kế **Professional Enterprise SaaS / ERP Admin (Minimalism & Swiss Style)**, đồng thời chuẩn hóa dữ liệu, phân trang máy chủ và tối ưu hóa quy trình quản trị tài nguyên Cloudinary.

- **Vị trí màn hình:** `Travel_Planner/frontend/web/lib/features/moderation/presentation/screens/admin_media_screen.dart`
- **Ánh xạ điều hướng:** Sidebar mục `Tài nguyên Media` (`AdminTab.media`), route `/media`.
- **Triết lý thiết kế:**
  - Nền trắng tinh khiết canvas `#FFFFFF`, viền mỏng hairline 1px `#E2E8F0`, bo góc vi mô 4px (`AppRadius.sm`).
  - Phân cấp thông tin rõ ràng theo nhịp lưới 4px, kiểu chữ Inter sắc nét, mật độ dữ liệu cao (data-dense).
  - Không trang trí thừa thãi, không gradient, không shadow nổi khối, màu Teal `#0F766E` định vị hành động chính và cam đậm `#C2410C`/`#EA580C` cho cảnh báo đạt chuẩn tương phản WCAG 2.1 AA.

---

## 2. Khảo sát & Năng lực API Backend thực tế

### A. Khảo sát API Backend (`AdminCommunityController.java`)
1. **API Liệt kê tài nguyên Media (`GET /api/admin/media-assets`):**
   - **Tham số hỗ trợ:**
     - `@RequestParam(required = false) MediaAssetStatus status`: Hỗ trợ lọc theo trạng thái (`UNATTACHED`, `ATTACHED`, `DELETING`, `DELETED`).
     - `@RequestParam(defaultValue = "false") boolean deadLetterOnly`: Hỗ trợ lọc chỉ các tài nguyên bị đưa vào hàng đợi dead-letter (vượt quá ngưỡng retry).
     - `@RequestParam(defaultValue = "0") int page`: Chỉ số trang (bắt đầu từ 0).
     - `@RequestParam(defaultValue = "20") int size`: Số lượng bản ghi mỗi trang.
   - **Cấu trúc DTO trả về (`MediaAssetResponse`):**
     `mediaAssetId`, `uploadedByUserId`, `uploadedByUsername`, `cloudinaryPublicId`, `secureUrl`, `mediaType`, `status`, `claimToken`, `lockedAt`, `lockedBy`, `retryCount`, `nextRetryAt`, `deadLetteredAt`, `lastError`, `createdAt`, `updatedAt`.
2. **API Thử lại dọn dẹp (`POST /api/admin/media-assets/{id}/retry`):**
   - Kích hoạt lại tiến trình xóa nền trên Cloudinary cho tài nguyên đang ở trạng thái `DELETING` hoặc bị kẹt trong hàng đợi `dead-letter`.
3. **Giới hạn API Backend & Giải pháp Frontend:**
   - **Không có API tìm kiếm toàn cục:** Backend không nhận tham số `?q=` hay `?search=`. Frontend xây dựng tính năng tìm kiếm tức thì (instant client filter) trên tập dữ liệu của trang hiện tại theo ID tài nguyên, tên người tải lên, Cloudinary Public ID, định dạng ảnh hoặc trạng thái.
   - **Không có API xóa độc lập (`DELETE /api/admin/media-assets/{id}`):** Backend thiết kế dọn dẹp media tự động bất đồng bộ: tài nguyên được kích hoạt xóa khi bài viết bị xóa vĩnh viễn (purge) hoặc qua tác vụ quét tài nguyên mồ côi (unattached sweeper). Frontend **tuyệt đối không bịa đặt API xóa**, mà cung cấp hành động `Retry xóa` (`POST /retry`) để phục vụ quản trị viên xử lý các lỗi dọn dẹp và dead-letter, kèm theo thông báo kỹ thuật (callout note) hướng dẫn rõ ràng.

---

## 3. Chi tiết triển khai Giao diện & Chức năng

### A. Tầng dữ liệu & Kho lưu trữ (`ModerationRepository`)
- Bổ sung hàm `getMediaAssetsPaged`:
  ```dart
  Future<AdminPageResponse<AdminMediaAssetModel>> getMediaAssetsPaged({
    String? status,
    bool deadLetterOnly = false,
    int page = 0,
    int size = 20,
    required String token,
  });
  ```
- Tự động bóc tách và fallback an toàn đối với các trường phân trang `totalElements`, `totalPages`, `pageNumber`, `size`.
- Bảo toàn tương thích ngược 100% với hàm `getMediaAssets` hiện hành.

### B. Header & Thanh công cụ (`AdminPageHeader` & `AdminToolbar`)
1. **AdminPageHeader:**
   - Tiêu đề chuẩn: `"Quản lý tài nguyên Media"`.
   - Mô tả ngắn: `"Giám sát tài nguyên tải lên Cloudinary, xử lý dead-letter và retry dọn dẹp file rác."`.
   - Chip thống kê tổng số lượng: `"Tổng: X tài nguyên"` phản ánh chính xác số liệu từ máy chủ.
2. **AdminToolbar:**
   - **Ô tìm kiếm nhanh:** Độ rộng 250px, icon kính lúp, hỗ trợ tìm theo ID, uploader, Cloudinary public ID kèm nút xóa từ khóa `[X]`.
   - **Dropdown lọc trạng thái:** `Tất cả trạng thái (ALL)`, `Chưa gán (UNATTACHED)`, `Đã gán (ATTACHED)`, `Đang xóa (DELETING)`, `Đã xóa (DELETED)`. Khi đổi bộ lọc, tự động reset về trang 0 và fetch dữ liệu mới.
   - **Checkbox Dead-letter:** `"Chỉ hiện Dead-lettered (Lỗi quá số lần retry)"` cho phép quản trị viên tập trung xử lý các tài nguyên lỗi nghiêm trọng.
   - **Bộ chuyển đổi chế độ xem kép (Dual View Toggle):**
     - Nút icon xem dạng Bảng (`Icons.table_rows_outlined`).
     - Nút icon xem dạng Lưới ảnh Gallery (`Icons.grid_view_outlined`).
   - **Nút làm mới:** `[Làm mới]` cập nhật dữ liệu tức thì.
3. **Thanh thông báo kỹ thuật (Operational Note):**
   - Thông báo tinh tế giải thích quy chế dọn dẹp bất đồng bộ và mục đích của nút "Retry xóa", nâng cao độ minh bạch nghiệp vụ.

### C. Chế độ xem Bảng dữ liệu Chuẩn mực (`AdminDataTable`)
- Bảng hiển thị 9 cột chuẩn:
  1. `ASSET ID` (Căn phải số liệu, in đậm)
  2. `NGƯỜI TẢI LÊN` (Tên người dùng)
  3. `XEM TRƯỚC` (Thumbnail 34x34px bo tròn micro 4px kèm fallback icon ảnh hỏng)
  4. `CLOUDINARY PUBLIC ID` (Font monospace, cắt ngắn an toàn)
  5. `TRẠNG THÁI` (Sử dụng `AdminStatusBadge`: UNATTACHED -> Chưa gán xanh dương; ATTACHED -> Đã gắn bài xanh lá; DELETING -> Đang xóa cam đậm; DELETED -> Đã xóa đỏ)
  6. `RETRY` (Số lần thử lại)
  7. `DEAD-LETTER` (Huy hiệu đỏ nếu đạt ngưỡng lỗi)
  8. `LỖI GẦN NHẤT` (Dòng chữ đỏ tóm tắt lỗi nếu có)
  9. `THAO TÁC` (Nút `[Chi tiết]` và nút `[Retry xóa]` cho tài nguyên DELETING / Dead-letter)
- Tích hợp thanh phân trang footer tích hợp sẵn của `AdminDataTable` (`Trang trước`, `Trang sau`, `Trang đầu`, `Trang cuối`, chỉ số bản ghi).

### D. Chế độ xem Lưới Thư viện Ảnh (`Gallery Grid View`)
- Bố cục responsive dạng thẻ ảnh sử dụng `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, childAspectRatio: 0.82)`.
- **Thẻ media:**
  - Khu vực hiển thị ảnh (chiều cao linh hoạt ~140px) với `fit: BoxFit.cover`, hiệu ứng loading và broken image fallback.
  - Huy hiệu ID `#id` và `AdminStatusBadge` gắn trực tiếp góc trên ảnh.
  - Vùng thông tin: Public ID monospace, Icon người dùng kèm tên uploader, cờ cảnh báo DEAD-LETTER đỏ nếu vi phạm.
  - Hàng hành động: Nút `[Chi tiết]` và `[Retry xóa]`.
- Thanh phân trang gắn chân trang đồng bộ chỉ số trang và điều hướng.

### E. Hộp thoại Xem trước & Kiểm tra Chi tiết (`AdminDialog`)
- **Header:** Tiêu đề `"Chi tiết Media #${asset.mediaAssetId}"` kèm huy hiệu trạng thái `AdminStatusBadge`.
- **Khu vực xem trước ảnh lớn:**
  - Khung ảnh tỷ lệ chuẩn (giới hạn chiều cao tối đa 260px) trên nền xám nhẹ `#F8FAFC`.
  - Giữ nguyên tỷ lệ ảnh gốc (`BoxFit.contain`), không bị méo hay vỡ layout.
  - Nút hành động nhanh `[Sao chép URL]` sao chép trực tiếp liên kết Cloudinary an toàn vào Clipboard kèm SnackBar thông báo.
- **Bảng dữ liệu kỹ thuật chi tiết:**
  - Người tải lên: `username (ID: userId)`
  - Cloudinary Public ID (cho phép chọn / copy)
  - URL an toàn (cho phép chọn / copy)
  - Định dạng: `image/jpeg`, `image/png`, v.v.
  - Số lần retry ghi nhận
  - Trạng thái Dead-letter & thời điểm ghi nhận lỗi quá hạn
  - Hộp thông báo lỗi gần nhất màu đỏ nhạt `#FEF2F2` (nếu có lỗi ghi nhận từ Cloudinary)
  - Thời gian tạo và cập nhật
- **Footer:**
  - Nút chính `[Thử lại xóa (Retry)]` kích hoạt API `POST /retry` (chỉ hiển thị khi tài nguyên đang xóa hoặc dead-letter).
  - Nút phụ `[Đóng]`.

---

## 4. Danh sách File Thay đổi và Bổ sung

| File | Hành động | Mục đích |
|---|---|---|
| `frontend/web/lib/features/moderation/data/moderation_repository.dart` | Refactor | Bổ sung hàm `getMediaAssetsPaged` trả về `AdminPageResponse<AdminMediaAssetModel>` |
| `frontend/web/lib/features/moderation/presentation/screens/admin_media_screen.dart` | Refactor | Tái thiết kế toàn bộ màn hình theo Swiss Minimalist, `AdminDataTable`, Gallery Grid, `AdminDialog`, server-side pagination |
| `frontend/web/lib/features/layout/presentation/screens/admin_shell.dart` | Refactor | Cung cấp đúng `ModerationRepository(apiClient: _apiClient)` cho các tab `posts`, `reports`, `media` |
| `frontend/web/test/admin_media_phase4_test.dart` | Mới | Bộ test kiểm thử chuyên sâu Phase 4: pagination, status filter, dead-letter toggle, search, retry action, grid view, RBAC, shell integration |
| `docs/plan/29-admin-media-management-implementation-report.md` | Mới | Báo cáo hoàn thành Phase 4 chi tiết |
| `docs/ai/09-development-log.md` | Cập nhật | Cập nhật nhật ký phát triển bằng tiếng Anh |

---

## 5. Kết quả Kiểm thử & Xác minh Nghiệp vụ

Toàn bộ các bước kiểm tra tự động đã hoàn thành với kết quả xuất sắc:

1. **Flutter Analyze:**
   ```
   Analyzing web...
   No issues found! (ran in 1.5s)
   ```
   - 0 errors, 0 warnings, 0 lints.
2. **Bộ test chuyên sâu Phase 4 (`test/admin_media_phase4_test.dart`):**
   - **6/6 passed!**
   - Kiểm tra phân trang server-side, cập nhật tổng số lượng và chuyển trang.
   - Kiểm tra bộ lọc trạng thái (`status`) và toggle cờ `deadLetterOnly`.
   - Kiểm tra mở hộp thoại chi tiết `AdminDialog`, sao chép URL và thực hiện `Retry xóa` (`POST /api/admin/media-assets/{id}/retry`).
   - Kiểm tra chuyển đổi mượt mà giữa chế độ Data Table và Gallery Grid.
   - Kiểm tra kiểm soát quyền truy cập (RBAC) chặn tài khoản không phải `ADMIN`.
   - Kiểm tra tích hợp hoàn hảo trong `AdminShell`.
3. **Bộ test tương thích ngược (`test/admin_moderation_test.dart`):**
   - **17/17 passed!** Bảo toàn 100% các hành vi kiểm duyệt, chuyển tab và retry trước đây.
4. **Bộ test cấu trúc layout và shell (`test/admin_portal_layout_test.dart`):**
   - **12/12 passed!** Xác nhận đúng các tiêu đề, subtitle, breadcrumbs và RBAC navigation.
5. **Toàn bộ Test Suite Web (`flutter test`):**
   - **94/94 passed!** (100% tests vượt qua thành công, không phát sinh bất kỳ lỗi hồi quy nào).
6. **Biên dịch Web Build (`flutter build web`):**
   - Biên dịch thành công mã nguồn web production (`build/web`).

---

## 6. Kế hoạch Giai đoạn Tiếp theo

- **Giai đoạn tiếp theo (Phase 5):** Triển khai Design System cho **Places / Locations Management (Quản lý Địa điểm du lịch)**:
  - Tái cấu trúc `AdminPlacesScreen` theo chuẩn `AdminDataTable` và `AdminToolbar`.
  - Tối ưu hóa bảng quản lý địa điểm, bản đồ tương tác, bộ lọc danh mục và kiểm duyệt địa điểm mới do cộng đồng đóng góp.
