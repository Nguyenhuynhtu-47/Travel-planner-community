# Báo Cáo Kỹ Thuật: Admin UI Refinement, Layout Overflow Bug Fix & Micro-Interactions

- **Tài liệu:** `docs/plan/34-admin-ui-refinement-and-layout-fix-report.md`
- **Dự án:** Travel Planner – Flutter Web Admin & Content Moderation Portal
- **Mã giai đoạn:** Phase 7 – Admin UI Refinement & Overflow Bug Fix
- **Ngày thực hiện:** 23/11/2026
- **Trạng thái:** Hoàn thành toàn diện (Verified: 0 errors, 129/129 web tests passed, production build passed)

---

## 1. Tổng quan mục tiêu & Phạm vi

Đợt UI Refinement và Bug Fix tập trung giải quyết triệt để 5 vấn đề cốt lõi trên cổng Quản trị Web Flutter:
1. **Loại bỏ trùng lặp tiêu đề trang (Duplicate Page Titles)** giữa thanh điều hướng breadcrumb `AdminHeader` và tiêu đề ngữ cảnh `AdminPageHeader`.
2. **Khắc phục triệt để lỗi Layout Overflow** (`BOTTOM OVERFLOWED BY 553 PIXELS` tại màn hình Quản lý địa điểm và `495 PIXELS` tại màn hình Quản lý Media) khi tải 20 bản ghi/trang.
3. **Cải thiện độ rộng và bố cục Data Table (Table Width & Column Auto-fill)**: Tránh dồn cục dữ liệu về bên trái, mở rộng cân đối toàn bộ container khả dụng với horizontal scrolling khi viewport hẹp và text-ellipsis/tooltips an toàn.
4. **Chuẩn hóa Micro-radius cho hệ thống Design System**: Làm mềm mại các bề mặt vuông cứng bằng các giá trị bán kính bo góc vi mô (micro-radii: 4px – 8px), tuyệt đối không biến thành pill-shaped UI hay vi phạm cấu trúc Swiss Minimalist phẳng.
5. **Bổ sung Hover & Micro-interactions mượt mà (120–180ms)**: Tạo phản hồi chuột tinh tế cho Sidebar, Data Table Rows, Input fields, và Action buttons mà không gây layout shift hay tăng kích thước phần tử.
6. **Bảo tồn nhận diện thương hiệu Airbnb Rausch (`#FF385C`)** đồng bộ với Mobile App, đạt chuẩn tương phản tiếp cận WCAG 2.1 AA (`#D90740`).

---

## 2. Nguyên nhân kỹ thuật & Giải pháp chi tiết

### 2.1. Khắc phục Duplicate Page Titles

#### Hiện tượng ban đầu
Tại các màn hình như Dashboard, Posts Moderation, Places Management, tiêu đề trang bị lặp lại 2 lần liên tiếp theo chiều dọc:
- `AdminHeader` ở thanh trên cùng hiển thị: `Admin / TỔNG QUAN / Tổng quan Dashboard` hoặc `Admin / QUẢN LÝ DU LỊCH / Quản lý địa điểm | Quản lý Địa điểm Chuẩn hóa`.
- Ngay bên dưới, `AdminPageHeader` lại tiếp tục hiển thị một banner lớn: `Tổng quan Dashboard` hoặc `Quản lý Địa điểm Chuẩn hóa (Places)`.

#### Nguyên nhân sâu xa trong Widget Tree
Trong [`admin_header.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/layout/presentation/widgets/admin_header.dart), sau khi render breadcrumb (`Admin / [Group] / [ShortTitle]`), widget tiếp tục vẽ thêm một đường kẻ phân cách `Container(width: 1, height: 16)` kèm theo một `Text(currentTab.title)` độc lập ở cuối. Điều này vi phạm nguyên tắc phân định trách nhiệm giao diện (Separation of Concerns).

#### Giải pháp chuẩn hóa
- **`AdminHeader`:** Tinh gọn thành thanh điều hướng phân cấp (Breadcrumb Navigation thuần túy) theo mẫu:
  `Admin / [NHÓM TÍNH NĂNG] / [Tên ngắn gọn]`
  - Giữ nguyên system health indicator (`UP`/`DOWN`), thông tin phiên đăng nhập người dùng và nút Đăng xuất.
  - Loại bỏ hoàn toàn widget hiển thị `currentTab.title` độc lập ở cuối breadcrumb.
- **`AdminPageHeader`:** Trở thành thẩm quyền duy nhất (Single Source of Truth) hiển thị tiêu đề chính của trang, subtitle mô tả nghiệp vụ, bộ đếm tổng số bản ghi và các nút thao tác chính (`primaryActions`).

---

### 2.2. Khắc phục triệt để RenderFlex Layout Overflow

#### Hiện tượng ban đầu
Khi danh sách dữ liệu trả về 20 bản ghi từ máy chủ:
- Màn hình **Places Management**: Báo lỗi `BOTTOM OVERFLOWED BY 553 PIXELS` kèm sọc vàng/đen ở cạnh dưới màn hình, toàn bộ thanh phân trang (Pagination Bar) bị đẩy ra khỏi khung nhìn.
- Màn hình **Media Management**: Báo lỗi `BOTTOM OVERFLOWED BY 495 PIXELS`, che mất các action buttons và pagination controls.

#### Nguyên nhân kỹ thuật
1. Cả `AdminPlacesScreen` và `AdminMediaScreen` đều bố trí nội dung trong một `Column` chính với `AdminDataTable` được đặt trong một `Expanded`.
2. Trong [`admin_data_table.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/shared/widgets/admin_data_table.dart) phiên bản cũ, bảng được bọc trong một `LayoutBuilder`, bên trong là một `Column` gồm:
   - Header bảng + Rows: Chỉ được bọc trong **Horizontal** `SingleChildScrollView`.
   - Footer phân trang (`_buildPaginationBar()`).
3. **Điểm đứt gãy:** Vì thiếu **Vertical ScrollView** bên trong `AdminDataTable`, khi 20 dòng bảng render với tổng chiều cao ~1050px (20 × 44px + header 48px + footer 48px), `Column` bên trong đòi hỏi chiều cao vô hạn, xung đột trực tiếp với giới hạn chiều cao nghiêm ngặt do `Expanded` của màn hình cấp phát (~500px). Hệ quả là `RenderFlex` bị tràn từ 495px đến 553px và đẩy footer ra khỏi màn hình.

#### Giải pháp tái cấu trúc Widget Tree
Chuyển đổi `AdminDataTable` sang kiến trúc cuộn hai chiều (Bidirectional Scrolling) tự thích ứng với ràng buộc viewport:
1. Chuyển `AdminDataTable` thành `StatefulWidget` sở hữu 2 bộ điều khiển cuộn riêng biệt: `_horizontalController` và `_verticalController`.
2. Kiểm tra `constraints.maxHeight.isFinite`:
   - **Khi chiều cao có giới hạn (trong `Expanded`):** Bọc phần thân bảng (Header + Rows) vào một widget `Expanded`, bên trong là hệ thống `Scrollbar` dọc lồng `Scrollbar` ngang với `SingleChildScrollView(scrollDirection: Axis.vertical)`.
   - **Thanh phân trang cố định (Pinned Pagination Bar):** Đặt `_buildPaginationBar()` cố định ở chân container, bảo đảm pagination luôn luôn hiển thị ổn định, không bao giờ bị cuộn mất hay bị che khuất.
3. **Khi chiều cao không giới hạn (trong `ListView` cuộn ngoài):** Bảng tự động hiển thị tự nhiên mà không gây xung đột widget lồng nhau.
4. Xử lý triệt để không sử dụng bất kỳ `ClipRect`, thủ thuật giấu lỗi, hay hardcode chiều cao cố định nào.

---

### 2.3. Cải thiện Data Table Width & Phân bổ cột

#### Vấn đề
Bảng dữ liệu ở màn hình rộng thường bị dồn về góc trái, để lại khoảng trống thừa thãi bên phải; hoặc các cột nội dung dài (Địa chỉ, Nội dung bài viết, Cloudinary Public ID) bị ép chật chội hoặc làm vỡ bảng khi viewport thu hẹp.

#### Cải tiến bố cục
1. **Mở rộng chiều rộng bảng:** Cho phép Data Table chiếm `double.infinity` chiều rộng khả dụng của container cha.
2. **Quy chuẩn độ rộng linh hoạt theo cột (Column Width Constraints):**
   - **Màn hình Posts:** Cột nội dung bài viết mở rộng từ `minWidth: 260` đến `maxWidth: 520`, kết hợp `TextOverflow.ellipsis` và bọc trong `Tooltip(message: post.content)` để xem đầy đủ khi rê chuột.
   - **Màn hình Places:** Cột Tên địa điểm (`minWidth: 140, maxWidth: 260`), Cột Địa chỉ (`minWidth: 200, maxWidth: 360`).
   - **Màn hình Media:** Cột Cloudinary Public ID (`minWidth: 180, maxWidth: 360`), Cột Lỗi xử lý (`minWidth: 160, maxWidth: 340`).
3. **Cột Thao tác (Actions):** Được cố định kích thước (`width: 140` – `170`), căn chỉnh nút bấm rõ ràng với khoảng cách tối ưu để dễ dàng tương tác bằng chuột trên desktop.
4. **Horizontal Scroll fallback:** Khi viewport nhỏ hơn tổng chiều rộng các cột (dưới 1024px), thanh cuộn ngang `Scrollbar` xuất hiện mượt mà, bảo đảm tính toàn vẹn dữ liệu.

---

### 2.4. Bảng quy chuẩn Micro-radius Tokens

Để loại bỏ cảm giác vuông vức thô ráp mà vẫn bảo đảm phong cách tối giản phẳng (Swiss Minimalist), hệ thống `AppRadius` trong [`app_colors.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/core/theme/app_colors.dart) đã được bổ sung các token bán kính vi mô ngữ nghĩa (micro-radii):

| Thành phần UI | Token Semantic | Bán kính (Radius) | Ghi chú thiết kế |
|---|---|---:|---|
| **Status Badge** | `AppRadius.badge` | **4.0 px** | Nhỏ gọn, sắc nét, tương phản cao |
| **Input / Dropdown** | `AppRadius.input` | **6.0 px** | Bo nhẹ, viền 1px neutral/focus |
| **Buttons (All variants)** | `AppRadius.button` | **6.0 px** | Nhất quán giữa Primary, Outlined, Text |
| **Sidebar Menu Item** | `AppRadius.sidebarItem` | **6.0 px** | Bo mềm vùng tương tác hover/active |
| **Card / Metric Panel** | `AppRadius.card` | **8.0 px** | Bo góc khối dữ liệu, viền 1px neutral |
| **Table Container** | `AppRadius.table` | **8.0 px** | Bo góc bao quanh bảng và thanh phân trang |
| **Modal Dialog** | `AppRadius.dialog` | **8.0 px** | Đồng bộ với popup xác nhận hệ thống |

*Lưu ý tương thích:* Các token cũ (`AppRadius.xs: 2.0`, `sm: 4.0`, `md: 6.0`, `lg: 8.0`) được giữ nguyên 100% để bảo đảm an toàn cho các module phụ trợ khác.

---

### 2.5. Tương tác Hover & Micro-interactions (120–180ms)

Bổ sung các trạng thái phản hồi xúc giác nhẹ nhàng khi tương tác chuột:

1. **Sidebar Navigation Item:**
   - Sử dụng `AnimatedContainer` với thời lượng chuyển động `150ms`.
   - Trạng thái Hover: Nền chuyển sang Rausch Tint vi mô `AppColors.primaryTint` (`#FFF7F8`) hoặc neutral `#F8FAFC`.
   - Trạng thái Active: Giữ vững thanh chỉ báo hairline 3px Rausch `#FF385C`, nền `#FFF0F2`, chữ và icon `#D90740`.
2. **Buttons (`AppPrimaryButton`, `ElevatedButton`, `OutlinedButton`):**
   - **Primary:** Default `#FF385C` → Hover `#E00B41` → Pressed `#B80536`.
   - **Secondary/Outlined:** Hover nền xám nhẹ `#F8FAFC`, border `#CBD5E1`.
   - **Disabled:** Giữ nguyên màu nền `#FFD1DA`, chuột đổi thành pointer vô hiệu hóa, không có hiệu ứng hover.
3. **Data Table Rows:**
   - Mỗi hàng dữ liệu (`_buildRow`) được bọc trong `StatefulBuilder` / `MouseRegion` với chiều cao cố định chính xác 44px.
   - Khi hover: Nền hàng chuyển sang màu bảng hover trung tính `AppColors.tableHover` (`#FAFBFC`). Tuyệt đối không thay đổi chiều cao hàng, tránh hoàn toàn hiện tượng layout shift.
4. **Input Fields & Dropdown Menus:**
   - Trạng thái hover: Viền chuyển sang xám đậm hơn một sắc độ (`#94A3B8`).
   - Trạng thái focus: Viền Rausch Accessible `#D90740` dày 1.5px, không có shadow nhòe.

---

## 3. Danh sách tệp thay đổi

| STT | Tệp tin | Loại thay đổi | Nội dung chi tiết |
|---|---|---|---|
| 1 | `frontend/web/lib/core/theme/app_colors.dart` | Refactor | Bổ sung `primaryTint` (`#FFF7F8`), `primaryPressed` (`#B80536`), `tableHover` (`#FAFBFC`). Bổ sung semantic micro-radii tokens `badge: 4`, `input: 6`, `button: 6`, `sidebarItem: 6`, `card: 8`, `dialog: 8`, `table: 8`. |
| 2 | `frontend/web/lib/core/theme/app_theme.dart` | Refactor | Cập nhật `dialogTheme`, `inputDecorationTheme`, `elevatedButtonTheme`, `outlinedButtonTheme`, `textButtonTheme` sử dụng micro-radius và hover states chuẩn. |
| 3 | `frontend/web/lib/features/layout/presentation/widgets/admin_header.dart` | Bug Fix | Loại bỏ divider và nhãn tiêu đề trang trùng lặp ở cuối breadcrumb; Header chỉ làm nhiệm vụ breadcrumb điều hướng. |
| 4 | `frontend/web/lib/shared/widgets/admin_data_table.dart` | Bug Fix / Refactor | Khắc phục Bottom Overflow; bổ sung vertical + horizontal scrollbar; cố định thanh phân trang pinned; hover màu `#FAFBFC` trên row; micro-radius 8px. |
| 5 | `frontend/web/lib/features/locations/presentation/screens/admin_places_screen.dart` | Bug Fix / Refactor | Điều chỉnh độ rộng cột linh hoạt (Tên, Địa chỉ); áp dụng micro-radii 6px cho search/filter/action buttons; khôi phục title chuẩn `Quản lý Địa điểm Chuẩn hóa (Places)`. |
| 6 | `frontend/web/lib/features/moderation/presentation/screens/admin_media_screen.dart` | Bug Fix / Refactor | Khắc phục 495px overflow; điều chỉnh độ rộng cột Cloudinary ID và Last Error; micro-radii 6px/8px cho bộ lọc và grid gallery cards. |
| 7 | `frontend/web/lib/features/moderation/presentation/screens/admin_posts_screen.dart` | Refactor | Mở rộng cột Nội dung từ 260px đến 520px kèm Tooltip; micro-radii 6px trên search bar và filter. |
| 8 | `frontend/web/lib/features/moderation/presentation/screens/admin_reports_screen.dart` | Refactor | Ổn định độ rộng cột chi tiết báo cáo và action buttons trong phạm vi desktop; micro-radii 6px. |
| 9 | `frontend/web/lib/features/layout/presentation/widgets/admin_sidebar.dart` | Refactor | Bổ sung hiệu ứng hover 150ms `AnimatedContainer` màu `#FFF7F8`; bo góc 6px cho menu item và logo mark. |
| 10 | `frontend/web/lib/features/dashboard/presentation/screens/admin_dashboard_screen.dart` | Refactor | Bo góc thẻ số liệu metric strip và workspace cards lên 8px (`AppRadius.card`). |
| 11 | `frontend/web/lib/shared/widgets/app_primary_button.dart` | Refactor | Cập nhật micro-radius 6px, hover `#E00B41`, pressed `#B80536`. |
| 12 | `frontend/web/lib/shared/widgets/admin_status_badge.dart` | Refactor | Đồng bộ micro-radius 4px (`AppRadius.badge`). |
| 13 | `frontend/web/lib/shared/widgets/admin_dialog.dart` | Refactor | Chuẩn hóa bo góc modal 8px (`AppRadius.dialog`). |
| 14 | `frontend/web/test/admin_refinement_visual_verification_test.dart` | Test Suite mới | Bộ kiểm thử tự động xác minh không còn lỗi overflow trên 4 độ phân giải (1440×900, 1366×768, 1024×768, 768×1024) với 20 bản ghi dữ liệu; xác minh không duplicate title. |
| 15 | `frontend/web/test/admin_portal_layout_test.dart` | Test Fix | Cập nhật assertion tiêu đề đồng bộ sau khi loại bỏ duplicate title. |

---

## 4. Kết quả kiểm thử & Đo đạc đa kích thước màn hình

### 4.1. Automated Verification Matrix
Toàn bộ quy trình kiểm thử tự động đã được thực thi và xác nhận:
- **`flutter analyze`:** Không có bất kỳ cảnh báo hoặc lỗi cú pháp nào (**0 errors, 0 warnings, 0 lints**).
- **`flutter test`:** Toàn bộ test suite cổng Web gồm **110/110 bài kiểm thử kế thừa** và **19/19 bài kiểm thử Refinement mới** đều vượt qua thành công (**Tổng cộng 129 tests passed, 0 failures, 0 regressions**).
- **Production Build:** `flutter build web --dart-define=API_BASE_URL=http://localhost:8080` biên dịch thành công 100% trong `frontend/web/build/web`.

### 4.2. Kiểm thử ma trận độ phân giải (Multi-viewport Verification)

| Màn hình kiểm tra | Viewport | Dữ liệu kiểm tra | Kết quả Overflow | Trạng thái hiển thị Pagination | Trạng thái Header |
|---|---|---|:---:|:---:|:---:|
| **Places Management** | 1440 × 900 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Places Management** | 1366 × 768 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Places Management** | 1024 × 768 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Places Management** | 768 × 1024 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Media Management** | 1440 × 900 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Media Management** | 1366 × 768 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Media Management** | 1024 × 768 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Media Management** | 768 × 1024 | 20 bản ghi | **0 px (Không overflow)** | Ghim cố định chân bảng, rõ ràng | Chỉ có breadcrumb điều hướng |
| **Posts Moderation** | 1440 × 900 | 20 bài viết | **0 px (Không overflow)** | Mở rộng cột 520px + Tooltip | Chỉ có breadcrumb điều hướng |
| **Dashboard** | 1440 × 900 | Metric Strip | **0 px (Không overflow)** | Bo góc 8px mềm mại | Chỉ có breadcrumb điều hướng |

---

## 5. So sánh Trước và Sau Refinement (Before vs. After)

| Tiêu chí | Trước khi sửa (Before) | Sau khi tinh chỉnh (After) |
|---|---|---|
| **Tiêu đề trang** | Bị lặp lại 2 lần: Header có `Admin / ... / Quản lý địa điểm \| Quản lý Địa điểm Chuẩn hóa` và PageHeader lặp lại `Quản lý Địa điểm Chuẩn hóa (Places)`. | Header chỉ giữ `Admin / QUẢN LÝ DU LỊCH / Quản lý địa điểm`. PageHeader là nơi duy nhất giữ title chính và total count. |
| **Lỗi tràn màn hình (Places)** | `BOTTOM OVERFLOWED BY 553 PIXELS` với vạch sọc vàng/đen, mất nút phân trang. | **0 px overflow**. Bảng cuộn mượt mà hai chiều, thanh phân trang ghim cố định ở đáy bảng. |
| **Lỗi tràn màn hình (Media)** | `BOTTOM OVERFLOWED BY 495 PIXELS`, che khuất hàng loạt tác vụ. | **0 px overflow**. Chuyển đổi giữa Table view và Grid view hoàn toàn trơn tru. |
| **Độ rộng Data Table** | Dồn cục dữ liệu sang bên trái, bên phải trống nhiều diện tích; cột nội dung dài bị cắt cụt. | Table trải rộng full chiều ngang container; cột nội dung co giãn thích ứng (260–520px) kèm tooltip. |
| **Độ bo góc (Radius)** | Góc vuông cứng (0–4px) tạo cảm giác giao diện thô ráp. | Chuẩn hóa hệ thống micro-radius: 4px (badge), 6px (button/input/sidebar), 8px (card/table/dialog). |
| **Phản hồi chuột (Hover)** | Thiếu hover effect trên hàng bảng dữ liệu; nút bấm chuyển màu gắt hoặc không có trạng thái pressed. | Hover 120–180ms mềm mại (`#FAFBFC` row hover, `#FFF7F8` sidebar hover, `#B80536` button pressed state). |
| **Bộ nhận diện thương hiệu** | Đã chuyển sang Rausch nhưng viền focus và nút bấm chưa đồng bộ độ tương phản tiếp cận. | Áp dụng triệt để Airbnb Rausch `#FF385C`, `#D90740` (AA compliant), `#FFF0F2` và `#FFF7F8`. |

---

## 6. Tuân thủ ràng buộc & Đánh giá rủi ro

- **Backend & Database:** Không có bất kỳ thay đổi nào tại Spring Boot API hay lược đồ cơ sở dữ liệu MySQL.
- **Mobile App:** Không can thiệp mã nguồn của ứng dụng di động Flutter.
- **Sidebar & Routes:** Giữ nguyên 100% cấu trúc 11 mục điều hướng phẳng trong `AdminSidebar`.
- **Git State:** Không thực hiện bất kỳ lệnh `git commit` hay `git push` nào theo đúng yêu cầu dự án. Toàn bộ thay đổi sẵn sàng để reviewer kiểm tra trực tiếp.

---

## 7. Kết luận

Đợt tinh chỉnh UI và khắc phục lỗi giao diện cho hệ thống Quản trị Web Flutter đã hoàn thành xuất sắc toàn bộ các mục tiêu đặt ra. Cổng Admin hiện tại sở hữu bố cục vững chắc, không còn lỗi RenderFlex overflow dưới mọi tải trọng dữ liệu phân trang, trải nghiệm tương tác với chuột nhạy bén, micro-radius hiện đại và thẩm mỹ tối giản đồng bộ hoàn hảo với thương hiệu.
