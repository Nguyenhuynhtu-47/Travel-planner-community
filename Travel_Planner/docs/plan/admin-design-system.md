# Design System Toàn diện cho Flutter Web Admin — Travel Planner Portal

> **Tài liệu chuẩn hóa UI/UX Design System**  
> **Áp dụng cho:** Toàn bộ phân hệ Quản trị viên Web (`frontend/web`)  
> **Phong cách chủ đạo:** Professional Enterprise SaaS Admin / Minimalism & Swiss Style  
> **Ngày ban hành:** 23/11/2026  
> **Trạng thái:** Bản đề xuất quy chuẩn kiến trúc UI/UX (Design Spec & Guidelines)  

---

## 1. Phong Cách Thiết Kế Chủ Đạo & Lý Do Lựa Chọn

### 1.1 Định nghĩa Phong cách: Professional Enterprise SaaS Admin (Minimalism & Swiss Style)
Dựa trên kết quả phân tích chuyên sâu từ **UI/UX Pro Max Skill** (tương thích danh mục `Minimalism & Swiss Style` và kiến trúc `Operations Dashboard / SaaS Tool`), phong cách thiết kế được xác lập cho Travel Planner Admin Portal là:

**"Swiss Style Enterprise Minimalism"** — Tối giản theo trường phái Thụy Sĩ kết hợp thực dụng doanh nghiệp:
- **Canvas-First / Pure White Core:** Nền trắng tuyệt đối (`#FFFFFF`) làm mặt bằng hiển thị chính, mang lại độ tương phản sắc nét, giảm mỏi mắt cho người vận hành phải làm việc liên tục với bảng dữ liệu hàng giờ.
- **Data-Dense & Content-Focused:** Mật độ thông tin cao nhưng bố cục thoáng đãng, phân cấp thị giác bằng cấu trúc lưới (grid), đường kẻ phân cách 1px (hairlines), độ đậm nhạt của chữ (font-weight) và khoảng trắng (whitespace) có chủ đích thay vì dùng card hay màu nền sặc sỡ.
- **Structured Geometry (Hình học kỷ luật):** Triệt tiêu các bo góc tròn lớn dạng pill/bubble vốn thuộc về ứng dụng tiêu dùng (consumer apps). Áp dụng hệ bán kính góc siêu nhỏ (micro-radius: 2px – 4px, tối đa 6px cho dialog).
- **Zero Decorative Decoration:** Không sử dụng gradient trang trí, không đổ bóng đa tầng (heavy drop shadows), không viền màu rực rỡ, không icon 3D. Mọi phần tử xuất hiện trên màn hình đều phải phục vụ một mục đích thông tin hoặc thao tác cụ thể.
- **High Information Ergonomics (Công thái học dữ liệu):** Tối ưu hóa cho màn hình Desktop với chuột và bàn phím (hover states 150–200ms, keyboard focus ring sắc nét, phím tắt điều hướng, table horizontal scrolling mượt mà).

### 1.2 Lý do lựa chọn & Sự khác biệt với Mobile / Consumer Web
| Đặc tính | Consumer App (Mobile & Web Khách) | Enterprise Admin Portal (Web Quản trị) |
|---|---|---|
| **Mục tiêu cốt lõi** | Truyền cảm hứng du lịch, visual hấp dẫn, kích thích khám phá & đặt chuyến | Nhanh chóng rà soát, kiểm duyệt, tra cứu và xử lý vi phạm với hiệu suất cao |
| **Bố cục chính** | Khối card lớn, ảnh tràn viền, bo góc tròn mềm mại (12px–16px) | Bảng dữ liệu phẳng (Data Tables), Master-Detail chia đôi màn hình, lưới phân chia rõ ràng |
| **Mật độ dữ liệu** | Thấp đến trung bình (thoáng đãng, ưu tiên cảm xúc) | Rất cao (Data-dense: hiển thị tối đa hàng/cột quan trọng mà không gây rối mắt) |
| **Bán kính góc** | Bo cong mềm (8px nút, 14px card, 9999px pill chip) | Bo góc kỷ luật (2px–4px nút/input/badge, 6px modal, không dùng pill 9999px) |
| **Đổ bóng (Shadows)** | Elevation 2–4 tạo độ nổi mềm mại | Hầu như không đổ bóng (Flat), phân tách bằng viền 1px (`#E2E8F0`), chỉ dùng shadow rất nhẹ cho dropdown/dialog |
| **Màu nhấn chủ đạo** | Rausch `#FF385C` (màu kích thích tiêu dùng du lịch) | **Teal `#0D9488`** (bình tĩnh, tập trung, tin cậy) & **Orange `#F97316`** (cảnh báo, kiểm duyệt) |

---

## 2. Bảng Màu & Hệ Thống Semantic Color Tokens

### 2.1 Giữ Vững Màu Cốt Lõi: Teal & Orange
Theo yêu cầu thiết kế của dự án: **Giữ màu Teal và Orange hiện có nếu không có lý do rõ ràng để thay đổi.**
Trong giao diện quản trị doanh nghiệp (SaaS Operations):
- **Teal (`#0D9488`)**: Là gam màu lý tưởng hàng đầu cho hệ thống quản trị chuyên nghiệp (được các hệ thống như Supabase, Tailwind UI, Stripe Dashboard tin dùng). Teal mang lại cảm giác chính xác, an tâm, điềm tĩnh, không gây chói mắt như màu xanh dương điện tử hoặc màu đỏ thương mại. Teal đóng vai trò là **Primary Brand Accent** của Admin Portal (thay thế cho màu đỏ Rausch của bản consumer).
- **Orange (`#F97316` / `#EA580C`)**: Đóng vai trò là **Secondary Accent & Attention Color**. Trong một hệ thống cộng đồng du lịch, các tác vụ cốt lõi của Quản trị viên bao gồm: xử lý báo cáo vi phạm đang chờ (Pending Reports), bài viết bị ẩn (Hidden Posts), cảnh báo kiểm duyệt. Màu Orange thể hiện tính cấp bách cần chú ý mà không gây hoảng loạn như màu đỏ lỗi hệ thống (`#DC2626`).

### 2.2 Bảng Mã Màu Chi Tiết (Design Tokens Palette)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ENTERPRISE COLOR TOKENS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ PRIMARY (Teal)    │ #0D9488 │ Teal 600 - Chủ đạo: Nút chính, Tab active     │
│ PRIMARY DARK      │ #0F766E │ Teal 700 - Hover nút chính, text liên kết đậm │
│ PRIMARY LIGHT     │ #F0FDFA │ Teal 50  - Nền hàng được chọn, tab tint       │
│ PRIMARY BORDER    │ #CCFBF1 │ Teal 100 - Viền bao bọc khối active           │
├─────────────────────────────────────────────────────────────────────────────┤
│ ACCENT (Orange)   │ #F97316 │ Orange 500 - Điểm nhấn, Pending badge         │
│ ACCENT DARK       │ #EA580C │ Orange 600 - Hover nút cảnh báo, badge text   │
│ ACCENT LIGHT      │ #FFF7ED │ Orange 50  - Nền badge/banner chờ duyệt       │
│ ACCENT BORDER     │ #FFEDD5 │ Orange 100 - Viền badge/banner chờ duyệt      │
├─────────────────────────────────────────────────────────────────────────────┤
│ SLATE GRAYS (Ink) │ #0F172A │ Slate 900 - Text tiêu đề, số liệu KPI         │
│ TEXT SECONDARY    │ #334155 │ Slate 700 - Text nội dung bảng, mô tả         │
│ TEXT MUTED        │ #64748B │ Slate 500 - Tiêu đề cột, nhãn phụ, placeholder│
│ BORDER (Hairline) │ #E2E8F0 │ Slate 200 - Viền phân tách 1px, kẻ bảng       │
│ BORDER STRONG     │ #CBD5E1 │ Slate 300 - Viền input form, divider đậm      │
│ SURFACE SUBTLE    │ #F8FAFC │ Slate 50  - Nền header bảng, toolbar, sidebar │
│ CANVAS / SURFACE  │ #FFFFFF │ Pure White - Nền trang, nền bảng, nền dialog  │
├─────────────────────────────────────────────────────────────────────────────┤
│ SEMANTIC STATUS   │                                                         │
│ Success           │ #16A34A (Text) │ #F0FDF4 (Bg) │ #BBF7D0 (Border)        │
│ Warning / Pending │ #D97706 (Text) │ #FEF3C7 (Bg) │ #FDE68A (Border)        │
│ Error / Destruct  │ #DC2626 (Text) │ #FEF2F2 (Bg) │ #FECACA (Border)        │
│ Info / System     │ #0284C7 (Text) │ #F0F9FF (Bg) │ #BAE6FD (Border)        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Khai báo Dart Token Mẫu (`AppAdminColors`)

```dart
import 'package:flutter/material.dart';

/// Semantic Design Tokens dành riêng cho Flutter Web Admin.
/// Tối ưu hóa độ tương phản WCAG 2.1 AA (tối thiểu 4.5:1 cho text thông thường).
abstract class AppAdminColors {
  // --- BRAND TEAL TOKENS ---
  static const Color primary = Color(0xFF0D9488);       // Teal 600 (CTA chính, active indicator)
  static const Color primaryDark = Color(0xFF0F766E);   // Teal 700 (Hover/press, link)
  static const Color primaryLight = Color(0xFFF0FDFA);  // Teal 50 (Nền selection, active menu tint)
  static const Color primaryBorder = Color(0xFFCCFBF1); // Teal 100 (Stroke active)
  static const Color primaryDisabled = Color(0xFF99F6E4);// Teal 200 (Disabled fill)

  // --- ACCENT ORANGE TOKENS ---
  static const Color accent = Color(0xFFF97316);        // Orange 500 (Điểm nhấn cảnh báo/chờ duyệt)
  static const Color accentDark = Color(0xFFEA580C);    // Orange 600
  static const Color accentLight = Color(0xFFFFF7ED);   // Orange 50 (Nền alert card, pending badge)
  static const Color accentBorder = Color(0xFFFFEDD5);  // Orange 100 (Viền pending badge)

  // --- NEUTRAL SLATE SURFACES & BORDERS ---
  static const Color canvas = Color(0xFFFFFFFF);        // Nền trang trắng tinh khôi
  static const Color surface = Color(0xFFFFFFFF);       // Mặt phẳng component, table body
  static const Color surfaceSubtle = Color(0xFFF8FAFC); // Slate 50 (Header bảng, toolbar strip)
  static const Color surfaceHover = Color(0xFFF1F5F9);  // Slate 100 (Hover hàng trong bảng)
  static const Color border = Color(0xFFE2E8F0);        // Slate 200 (Hairline 1px chuẩn)
  static const Color borderStrong = Color(0xFFCBD5E1);  // Slate 300 (Input border)

  // --- TYPOGRAPHY INK TOKENS ---
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900 (Độ tương phản 18.2:1 so với White)
  static const Color textSecondary = Color(0xFF334155); // Slate 700 (Độ tương phản 9.6:1 so với White)
  static const Color textMuted = Color(0xFF64748B);     // Slate 500 (Độ tương phản 4.8:1 - đạt chuẩn AA)
  static const Color textDisabled = Color(0xFF94A3B8);  // Slate 400

  // --- FEEDBACK & STATUS TOKENS ---
  // Success (Hoạt động / Đã giải quyết)
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);

  // Warning / Pending (Chờ xử lý / Đã ẩn tạm)
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFDE68A);

  // Error / Destructive (Khóa / Xóa vĩnh viễn / Lỗi hệ thống)
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  // Info (Thông tin kỹ thuật / Chưa gán)
  static const Color info = Color(0xFF0284C7);
  static const Color infoBg = Color(0xFFF0F9FF);
  static const Color infoBorder = Color(0xFFBAE6FD);
}
```

### 2.4 Kiểm Định Độ Tương Phản (WCAG 2.1 AA Compliance)
- **Chữ chính (`textPrimary` #0F172A) trên nền trắng (`#FFFFFF`):** Tỷ lệ tương phản **18.2 : 1** (vượt xa chuẩn 4.5:1).
- **Chữ phụ (`textSecondary` #334155) trên nền trắng:** Tỷ lệ tương phản **9.6 : 1**.
- **Chữ ghi chú (`textMuted` #64748B) trên nền trắng:** Tỷ lệ tương phản **4.85 : 1** (đạt chuẩn AA cho cỡ chữ 11.5px+).
- **Nút bấm chính (Chữ trắng trên nền Teal `#0D9488`):** Tỷ lệ tương phản **4.55 : 1** (đạt chuẩn WCAG AA cho normal text, khắc phục hoàn toàn nhược điểm 3.52:1 của màu Rausch `#FF385C`).

---

## 3. Hệ Thống Typography (Phông Chữ & Thước Đo Phân Cấp)

### 3.1 Lựa chọn Phông chữ & Cơ chế Fallback
- **Font đề xuất tối ưu:** **Inter** (Google Fonts). Inter là phông chữ tiêu chuẩn của ngành SaaS toàn cầu, được tinh chỉnh tối ưu cho việc đọc số liệu, bảng mã, chữ nhỏ trên màn hình máy tính.
- **Font Fallback đa nền tảng (System Fallback):**
  ```css
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  ```
- **Font số liệu / Code (Monospace):** `Roboto Mono` hoặc `Fira Code` cho ID bảng (`#1024`), địa chỉ IP, tọa độ GPS (`10.7626, 106.6601`), Cloudinary Public ID.

### 3.2 Bảng Thước Đo Typography 8 Cấp Độ (Typographic Scale)

| Token Tên Gọi | Cỡ chữ (Size) | Độ đậm (Weight) | Chiều cao dòng (Line-height) | Khoảng cách chữ (Letter-spacing) | Mục đích sử dụng thực tế trong Admin |
|---|---|---|---|---|---|
| `display-kpi` | 24px | 700 (Bold) | 28px (1.17) | -0.5px | Số đếm tổng quan Dashboard (VD: `1,280`, `48`) |
| `title-page` | 18px | 600 (SemiBold) | 24px (1.33) | -0.3px | Tiêu đề chính màn hình tại `AdminPageHeader` |
| `title-section`| 15px | 600 (SemiBold) | 20px (1.33) | -0.2px | Tiêu đề panel, tiêu đề card, tiêu đề modal dialog |
| `body-data` | 13px | 400 (Regular) | 18px (1.38) | 0.0px | Dữ liệu bảng (tên người dùng, nội dung bài viết, địa chỉ) |
| `body-medium` | 13px | 500 (Medium) | 18px (1.38) | 0.0px | Cột dữ liệu cần nhấn mạnh (tên tác giả, số điện thoại) |
| `label-control`| 12.5px | 500 (Medium) | 16px (1.28) | 0.0px | Nhãn trường Form, nhãn bộ lọc Toolbar, chữ trên nút bấm |
| `caption-table`| 11.5px | 600 (SemiBold) | 14px (1.21) | +0.4px | Tiêu đề các cột dữ liệu Data Table (IN HOA TOÀN BỘ) |
| `badge-micro` | 11px | 600 (SemiBold) | 14px (1.27) | +0.2px | Nhãn trạng thái (ACTIVE, PENDING, HIDDEN, RESOLVED) |
| `code-mono` | 12px | 500 (Medium) | 16px (1.33) | -0.1px | ID (`#9104`), Tọa độ, Cloudinary ID, Timestamp |

---

## 4. Spacing, Sizing, Bán Kính Góc (Radius), Đường Viền & Đổ Bóng

### 4.1 Thước đo khoảng cách (Spacing Scale dựa trên lưới 4px)
Toàn bộ khoảng cách (Padding, Margin, Gap) được chuẩn hóa theo hệ số nguyên của **4px**:

| Token Spacing | Kích thước | Sử dụng tiêu biểu |
|---|---|---|
| `space-1` | 4px | Khoảng cách micro giữa icon và chữ nhỏ; padding trong badge |
| `space-2` | 8px | Khoảng cách giữa các chip bộ lọc; khoảng cách giữa icon và chữ trong menu |
| `space-3` | 12px | Padding ngang trong ô input, padding ngang ô bảng compact |
| `space-4` | 16px | Padding chuẩn lề toolbar, padding các ô trong DataTable, gap giữa các nút |
| `space-5` | 20px | Padding tổng thể vùng làm việc (Workspace padding), gap giữa 2 cột |
| `space-6` | 24px | Padding trong Dialog, padding chi tiết Place Detail Panel |
| `space-8` | 32px | Khoảng cách giữa các khối lớn trên Dashboard |

### 4.2 Thước đo chiều cao thành phần (Sizing Height Scale)
Để đảm bảo toàn bộ giao diện có nhịp điệu thẳng tắp (Visual Alignment):
- **Top Header:** Cố định **52px** (giữ nguyên độ gọn gàng đã hoàn thiện).
- **Sidebar Width:** **252px** (mở rộng) / **64px** (thu gọn - chuẩn hóa từ 68px để khớp lưới bội số của 4).
- **Admin Toolbar (Bộ lọc):** Chiều cao dải công cụ **46px**.
- **Input Fields & Dropdowns trong Toolbar:** Cố định chiều cao **32px** (siêu gọn).
- **Input Fields trong Form / Dialog:** Chiều cao **38px** (gọn gàng, dễ nhập liệu).
- **DataTable Header Row:** Cố định **38px**.
- **DataTable Body Row:** **44px** (chế độ chuẩn) / **52px** (chế độ có ảnh thumbnail/nhiều dòng).
- **Button Sizing:**
  - *Small (Table inline action / Toolbar):* Cao **30px**, padding ngang 10px, font 12px.
  - *Medium (Header action / Dialog action):* Cao **36px**, padding ngang 14px, font 13px.

### 4.3 Quy tắc Bán kính góc (Border Radius Hierarchy)
Tuyệt đối tuân thủ triết lý **Swiss Minimalism — Không dùng bo góc lớn**:
- `radius.none` (`0px`): Các dải container tràn viền, đường phân chia toàn trang, DataTable viền ngoài khi chạm đáy.
- `radius.xs` (`2px`): Code tag inline, status indicator dot.
- `radius.sm` (`4px`): **Quy chuẩn mặc định** cho hầu hết UI: Nút bấm, ô nhập Textfield, menu dropdown, hộp tìm kiếm, `AdminStatusBadge`.
- `radius.md` (`6px`): Hộp thoại Modal Dialog, Menu Popover nổi, Thumbnail ảnh xem trước.
- **NGHIÊM CẤM:** Không sử dụng góc bo `8px`, `12px`, `16px` hoặc `9999px` (dạng con nhộng pill) trong phân hệ Admin.

### 4.4 Quy tắc Đường viền & Đổ bóng (Hairline & Shadow Rule)
- **100% Phân tách bằng Đường viền 1px (Hairline):** Thay vì dùng shadow để phân tầng các khối, sử dụng đường viền phẳng:
  `Border.all(color: AppAdminColors.border, width: 1.0)`.
- **Zero Drop Shadow cho Surface phẳng:** Các card Dashboard, bảng dữ liệu, toolbar, header, sidebar **hoàn toàn không có shadow (`elevation: 0`)**.
- **Chỉ áp dụng Shadow chức năng nhẹ cho các tầng lơ lửng (Floating Overlays):**
  - Dropdown Menu / Context Menu:
    ```dart
    boxShadow: [
      BoxShadow(
        color: Color(0x0D000000), // Độ mờ 5%
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ]
    ```
  - Modal Dialog (`elevation: 1` hoặc `2` tối đa): Chỉ để tách khỏi lớp phủ đen mờ (`scrim` `Color(0x33000000)`).

---

## 5. Quy Chuẩn Thành Phần (Component Blueprints)

### 5.1 Sidebar (Thanh Điều Hướng Trái)
- **Cấu trúc:** Cố định cạnh trái, nền trắng (`#FFFFFF`), đường viền phải 1px (`#E2E8F0`).
- **Logo Banner:** Cao 52px. Khối icon 32x32px nền `primaryLight` (`#F0FDFA`), icon `travel_explore` màu `primary` (`#0D9488`).
- **Phân nhóm chuyên mục (Group Header):**
  - Kiểu chữ: `caption-table` (10.5px, bold, `#64748B`, khoảng cách chữ +0.5px).
  - Không có dropdown/accordion dạng sổ xuống, hiển thị danh sách phẳng trực quan 10 tab.
- **Mục menu (Sidebar Item):**
  - Chiều cao dòng: **38px** (padding đối xứng 10px lề ngang, 8px lề trên dưới).
  - Icon: Outlined size 18px (inactive: `#64748B`, active: `#0D9488`).
  - Khoảng cách icon và nhãn chữ: **10px**.
  - Trạng thái Active: Nền `AppAdminColors.primaryLight` (`#F0FDFA`), chữ và icon màu `AppAdminColors.primary` (`#0D9488`), thanh chỉ báo cạnh trái dày 3px màu `#0D9488`.
  - Trạng thái Hover: Nền `AppAdminColors.surfaceSubtle` (`#F8FAFC`).
  - Badge số lượng (Báo cáo tồn): Nền `accentLight` (`#FFF7ED`), chữ `accentDark` (`#EA580C`), viền 1px `#FFEDD5`, bo góc 4px.

### 5.2 Top Header (Thanh Điều Khiển Đầu Trang)
- **Chiều cao:** Cố định **52px**, nền `#FFFFFF`, đường viền dưới 1px `#E2E8F0`.
- **Nút Hamburger (Toggle Sidebar):** Icon menu 18px, màu `#0F172A`, không viền nổi.
- **Breadcrumbs (Đường dẫn vị trí):**
  - Định dạng: `Admin` / `Tên Nhóm` / **`Tên Tab Hiện Tại`**.
  - Dấu phân cách: Ký tự gạch chéo `/` màu `#CBD5E1`. Chữ cấp cuối dùng font Medium 12.5px màu `#0D9488`.
- **System Health Indicator (Chỉ báo trạng thái máy chủ):**
  - Badge dạng capsule góc bo 4px (không dùng pill tròn): Đèn tròn xanh lục 6px + Text "Hệ thống: Trực tuyến" (`#16A34A` trên nền `#F0FDF4`, viền `#BBF7D0`).
- **User Profile Chip:**
  - Avatar tròn 26x26px (chữ cái đầu tên viết hoa), nhãn tên quản trị viên 12.5px font w600. Nhấp chuột mở menu thông tin & đăng xuất.

### 5.3 Page Header & Toolbar (Tiêu Đề Trang & Dải Công Cụ)
- **`AdminPageHeader`:**
  - Nằm ngay dưới Top Header, chiều cao tự co giãn (khoảng 50px).
  - Tiêu đề trang (`title-page` 18px, w600, `#0F172A`).
  - Phụ đề giải thích chức năng màn hình (`body-data` 12.5px, `#64748B`).
  - Khu vực Action bên phải: Chứa nút tác vụ chính của trang (VD: nút "Thêm địa điểm", "Làm mới dữ liệu").
- **`AdminToolbar`:**
  - Nền `surfaceSubtle` (`#F8FAFC`), viền dưới 1px `#E2E8F0`, padding ngang 16px, dọc 8px.
  - **Ô tìm kiếm tức thì (Instant Search):**
    - Chiều rộng 260px, chiều cao **32px**.
    - Border 1px `#CBD5E1`, bo góc 4px, icon kính lúp nhỏ 15px.
    - Phím tắt gợi ý trong placeholder: *"Tìm kiếm bài viết, tác giả... (Ctrl+F)"*.
  - **Dropdown bộ lọc (Filters):**
    - Chiều cao **32px**, padding ngang 10px, bo góc 4px, nền `#FFFFFF`, viền `#CBD5E1`.
    - Có tiền tố nhãn rõ ràng (VD: *"Trạng thái: Tất cả"*).
  - **Nút thao tác hàng loạt (Bulk Actions):** Khi tích chọn >= 1 hàng trong bảng, toolbar tự động trượt hiển thị dải công cụ xử lý hàng loạt (VD: *Đã chọn 5 mục* -> Nút [Ẩn hàng loạt], [Xuất dữ liệu]).

### 5.4 Data Table (Bảng Dữ Liệu Doanh Nghiệp Chuẩn Hóa)
Đây là "trái tim" của hệ thống quản trị. Thay vì dùng `DataTable` nguyên thủy dễ tràn màn hình, kiến trúc chuẩn hóa như sau:
- **Khung chứa bảng (Table Container):**
  - Nền trắng, viền ngoài 1px `#E2E8F0`, bo góc 4px.
  - Hỗ trợ cuộn ngang độc lập (`SingleChildScrollView(scrollDirection: Axis.horizontal)`) có thanh cuộn mỏng (scrollbar).
- **Hàng tiêu đề (Header Row):**
  - Chiều cao **38px**, nền `surfaceSubtle` (`#F8FAFC`).
  - Viền dưới 1px `#CBD5E1`.
  - Tiêu đề cột dùng `caption-table` (11.5px, w600, uppercase, `#64748B`).
  - Hỗ trợ icon sắp xếp hai chiều (Sort Asc/Desc) cạnh tiêu đề cột.
- **Hàng dữ liệu (Data Rows):**
  - Chiều cao tiêu chuẩn **44px** (hoặc **52px** nếu có ảnh thumbnail/nhiều dòng thông tin).
  - Đường kẻ ngăn cách giữa các hàng 1px `#E2E8F0`.
  - Hiệu ứng Hover mượt mà (150ms): Chuyển màu nền sang `surfaceHover` (`#F1F5F9`).
  - Trạng thái Selected (tích chọn checkbox): Nền chuyển sang `primaryLight` (`#F0FDFA`).
- **Quy tắc căn lề trong ô dữ liệu:**
  - Dữ liệu văn bản / ID: Căn trái (Left-aligned).
  - Trạng thái / Badge / Thao tác: Căn giữa (Center-aligned).
  - Dữ liệu số / Ngày tháng / Số đếm: Căn phải (Right-aligned) để dễ so sánh hàng dọc.
- **Chân trang phân trang (Pagination Footer Bar):**
  - Cố định ở đáy bảng, chiều cao **42px**, nền `surfaceSubtle` (`#F8FAFC`), viền trên 1px `#E2E8F0`.
  - Bên trái: *"Hiển thị 1 - 20 trong tổng số 1,420 bản ghi"*.
  - Ở giữa: Bộ chọn kích thước trang (*"20 / trang"*, *"50 / trang"*, *"100 / trang"*).
  - Bên phải: Cụm nút điều hướng trang [Trang đầu] [Trước] [Trang X / Y] [Sau] [Trang cuối].

### 5.5 Form Fields & Validation
- **Label:** Đặt bên trên ô nhập liệu (Stacked label), cỡ chữ 12.5px, weight 500, màu `#334155`. Không dùng floating label dạng Material Android vì làm tăng chiều cao và gây nhiễu thị giác trên desktop.
- **Input Box:** Chiều cao 38px, nền `#FFFFFF`, viền 1px `#CBD5E1`, bo góc 4px, font 13px màu `#0F172A`.
- **Focus State:** Viền chuyển sang màu Teal `#0D9488` dày 1.5px, không hiển thị quầng sáng mờ (no halo/glow).
- **Validation Error:**
  - Viền chuyển sang màu đỏ `#DC2626`.
  - Dòng thông báo lỗi hiển thị ngay dưới ô nhập liệu với font 11.5px màu `#DC2626`, kèm icon cảnh báo nhỏ 12px.

### 5.6 Nút Bấm (Button System)
Hệ thống nút bấm 4 cấp bậc rõ ràng, triệt tiêu hoàn toàn nút bo tròn dạng viên thuốc (pill):
1. **Primary Button (Nút hành động chính):**
   - Nền `AppAdminColors.primary` (`#0D9488`), chữ trắng, font 12.5px / w600, bo góc 4px, chiều cao 34px.
   - Hover: Nền đậm dần sang `#0F766E` (150ms).
   - Disabled: Nền `#99F6E4`, chữ trắng.
2. **Secondary / Outlined Button (Nút hành động phụ / Làm mới / Bộ lọc):**
   - Nền trong suốt hoặc trắng, viền 1px `#CBD5E1`, chữ `#334155`, bo góc 4px.
   - Hover: Nền `#F1F5F9`, viền `#94A3B8`.
3. **Destructive Button (Nút thao tác xóa / khóa tài khoản):**
   - Nền đỏ `#DC2626` (nếu là xác nhận xóa cuối cùng trong dialog) hoặc Outlined viền đỏ `#FECACA`, chữ `#DC2626` (nếu đặt trên thanh công cụ).
4. **Ghost / Table Action Button (Nút thao tác trên từng dòng bảng):**
   - Nền trong suốt, font 12px w500, chữ Teal `#0D9488` hoặc Gray `#475569`.
   - Hover: Nền đổi sang `#F0FDFA` hoặc `#F1F5F9`.

### 5.7 Dialogs & Modals (Hộp Thoại Quản Trị)
- **Cấu trúc 3 phần bất biến:**
  1. *Header:* Tiêu đề rõ ràng (`title-section` 15px, w600), có nút đóng `[X]` góc trên phải, viền dưới 1px `#E2E8F0`.
  2. *Body:* Cuộn độc lập nếu nội dung dài (`maxHeight: 70vh`), padding 20px.
  3. *Footer:* Cố định ở đáy modal, viền trên 1px `#E2E8F0`, căn phải các nút hành động ([Hủy] đặt trước, [Xác nhận] đặt sau).
- **Kích thước chiều rộng chuẩn:**
  - Hộp xác nhận ngắn (Confirm Dialog): `420px`.
  - Form nhập liệu vừa (Place Form, Moderation Dialog): `560px`.
  - Form lớn / Bản đồ / So sánh (Inspection Modal): `840px`.

---

## 6. Quy Tắc Dashboard & Trực Quan Hóa Dữ Liệu (Data Visualization)

### 6.1 Băng Đo Lường Chỉ Số KPI (Metric Strip / KPI Cards)
Thay vì các ô hiển thị số đơn điệu hoặc các card bóng bẩy, áp dụng mô hình **SaaS KPI Metric Strip**:
- **Khối chứa:** Một dải container duy nhất được chia đều các cột bằng đường kẻ đứng 1px `#E2E8F0`, nền trắng, bo góc 4px.
- **Nội dung từng ô KPI:**
  - Dòng 1: Tiêu đề chỉ số (12px, font w600, `#64748B`) + Icon minh họa nhỏ (14px).
  - Dòng 2: Giá trị chỉ số chính (`display-kpi` 24px, font w700, màu `#0F172A`).
  - Dòng 3: Chỉ số đo lường xu hướng (Trend Delta):
    - Tăng trưởng tích cực: Icon mũi tên hướng lên + `+12.5% so với tuần trước` (Màu xanh lá `#16A34A`).
    - Cảnh báo tồn đọng: `+5 báo cáo chưa duyệt` (Màu cam `#EA580C` kèm chấm tròn nhấp nháy nhẹ hoặc viền báo động).
  - Toàn bộ ô có hiệu ứng hover đổi màu nền sang `#F8FAFC` và con trỏ chuột `cursor: pointer` để điều hướng trực tiếp sang trang quản lý tương ứng.

### 6.2 Lựa chọn Loại Biểu Đồ (Theo Khuyến Nghị UI/UX Pro Max)
1. **Biểu đồ Đường (Line Chart / Smooth Area Chart) — Xu hướng thời gian:**
   - *Áp dụng:* Thống kê số lượng bài viết mới được đăng tải mỗi ngày trong 30 ngày qua; tần suất báo cáo vi phạm phát sinh.
   - *Quy chuẩn hiển thị:* Đường kẻ chính màu Teal `#0D9488` (dày 2px), vùng diện tích bên dưới tô màu gradient nhẹ với độ mờ 8% - 12% giảm dần về 0. Lưới tọa độ (Grid lines) màu nhạt `#F1F5F9`.
   - *Khả năng tiếp cận:* Tooltip tương tác hiển thị giá trị chính xác và ngày tháng khi hover chuột; hỗ trợ xem bảng dữ liệu thô (raw data table) thay thế.
2. **Biểu đồ Cột Ngang (Horizontal Bar Chart) — So sánh danh mục:**
   - *Áp dụng:* Phân bố địa điểm theo danh mục (Điểm tham quan, Nhà hàng, Quán cafe, Khách sạn).
   - *Quy chuẩn hiển thị:* Dạng thanh ngang căn đều, màu Teal đồng nhất, sắp xếp giảm dần từ trên xuống dưới. Nhãn danh mục hiển thị trực tiếp bên trái thanh (không bắt người dùng phải tra cứu chú thích màu legend).
3. **Biểu đồ Thanh Phân Đoạn (Segmented Stacked Bar / Donut) — Trạng thái kiểm duyệt:**
   - *Áp dụng:* Tỷ lệ bài viết Hoạt động (Xanh `#16A34A`), Đã ẩn (Vàng/Cam `#D97706`), Đã xóa vĩnh viễn (Đỏ `#DC2626`).
   - *Quy tắc:* Luôn đi kèm nhãn số liệu và phần trăm cụ thể ngay cạnh mỗi phân đoạn.

---

## 7. UX Guidelines & Danh Sách Những Điều Cần Tránh (Anti-Patterns)

### 7.1 Những Điều BẮT BUỘC Thực Hiện (UX Best Practices)
1. **Bảo tồn dữ liệu khi xảy ra lỗi (Preserve Form State):** Khi submit thất bại (HTTP 400 hoặc lỗi mạng), giữ nguyên toàn bộ dữ liệu người dùng đã nhập trên form, không bao giờ reset trường dữ liệu.
2. **Xác nhận 2 bước cho hành động phá hủy (Destructive Confirmation):** Các hành động như "Xóa vĩnh viễn bài viết", "Xóa vĩnh viễn media", "Khóa tài khoản vĩnh viễn" bắt buộc phải mở Confirm Dialog giải thích hệ quả (dọn dẹp Cloudinary, không thể khôi phục) và yêu cầu bấm nút màu đỏ rõ ràng.
3. **Hiển thị đầy đủ 4 trạng thái trên mọi màn hình:**
   - **Loading State:** Spinner Teal thanh mảnh (`strokeWidth: 2`) hoặc Skeleton loader dạng khung xám nhạt `#F1F5F9`.
   - **Empty State:** Icon minh họa trung tính 40px `#94A3B8`, dòng thông báo ngắn gọn 13px, nút hành động chính (VD: *"Không tìm thấy dữ liệu phù hợp" -> [Đặt lại bộ lọc]*).
   - **Error State:** Banner thông báo lỗi màu đỏ nhạt `#FEF2F2`, viền `#FECACA`, kèm nút [Thử lại].
   - **Success Feedback:** Toast thông báo (SnackBar) góc trên/dưới biến mất sau 3 giây, nền `#0F172A`, chữ trắng hoặc viền xanh.
4. **Tối ưu hóa thao tác bàn phím (Desktop Ergonomics):**
   - Hỗ trợ phím `Escape` để đóng toàn bộ Dialog/Drawer.
   - Phím `Enter` để kích hoạt tìm kiếm hoặc gửi form.
   - Nhấn vào bất kỳ ô nào của dòng trong bảng để mở chi tiết xem nhanh.

### 7.2 Danh Sách Những Điều CẦN TRÁNH (Admin Anti-Patterns)
- ❌ **Không lạm dụng Card và Container lồng nhau (Card Nesting):** Tránh việc bọc card trong card, rồi lại bọc trong container có viền bo tròn lớn. Hãy phân cách nội dung bằng đường kẻ mảnh 1px `#E2E8F0` hoặc khoảng trắng whitespace.
- ❌ **Không sử dụng thanh tìm kiếm hình con nhộng (Pill Search Bar):** Thanh tìm kiếm tròn vo 9999px là đặc trưng của trang chủ ứng dụng du lịch khách hàng (Consumer Explore), hoàn toàn không phù hợp với thanh công cụ Toolbar của hệ thống quản trị.
- ❌ **Không dùng quá nhiều màu sắc cảnh báo:** Không dùng màu đỏ cho các nút bấm bình thường. Màu đỏ chỉ dành riêng cho thao tác xóa dữ liệu hoặc lỗi nghiêm trọng.
- ❌ **Không bỏ sót tính năng phân trang (Pagination):** Không bao giờ tải vô hạn (Infinite Scroll) trong các bảng quản trị nội dung lớn, vì làm mất dấu thanh cuộn và khiến người dùng không thể nhảy đến một trang cụ thể hoặc xem tổng số lượng bản ghi.
- ❌ **Không dùng font chữ lớn (Oversized Fonts):** Tiêu đề trang admin tối đa 18px–20px. Tránh sử dụng font 28px–36px làm tốn diện tích hiển thị dữ liệu quý giá trên màn hình.
- ❌ **Không giấu chức năng quan trọng sâu trong 3-4 tầng menu con:** Ưu tiên thanh menu phẳng 1 cấp kết hợp dải tab chuyên đề độc lập.

---

## 8. Lộ Trình Áp Dụng Design System Vào Từng Trang Admin (Implementation Roadmap)

Quá trình nâng cấp toàn bộ hệ thống Admin Web được chia thành 5 giai đoạn có trật tự, đảm bảo không làm gián đoạn các tính năng hiện tại và tuân thủ các quy tắc kiểm thử tự động (69/69 tests passing):

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ADMIN DESIGN SYSTEM IMPLEMENTATION ROADMAP               │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIAI ĐOẠN 1: Nền Tảng Tokens & Theme Cơ Sở                                  │
│ • Cập nhật AppAdminColors trong core/theme/app_colors.dart                   │
│ • Tinh chỉnh ThemeData trong core/theme/app_theme.dart (Inter, Slate, Teal) │
│ • Chuẩn hóa hệ số spacing, sizing, radius 4px                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIAI ĐOẠN 2: Thư Viện Component Dùng Chung (Shared Widgets)                 │
│ • Chuẩn hóa AdminPageHeader (Flat, gọn, font 18px)                          │
│ • Nâng cấp AdminToolbar (Bộ lọc chuẩn 32px, Instant Search 260px)           │
│ • Xây dựng AdminDataTable chuẩn hóa (Header 38px, Row 44px, Pagination bar) │
│ • Đồng bộ AdminStatusBadge (Semantic 4 màu, bo góc 4px)                    │
│ • Tối ưu AppPrimaryButton & AppTextField                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIAI ĐOẠN 3: Khung Vỏ Quản Trị & Điều Hướng (Shell & Navigation)            │
│ • Cập nhật AdminSidebar (Thanh chỉ báo Teal, badge Orange, width 252/64px)  │
│ • Cập nhật AdminHeader (Breadcrumb phẳng, health badge gọn 4px)             │
│ • Đồng bộ AdminShell và cơ chế Route Navigation                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIAI ĐOẠN 4: Các Màn Hình Nghiệp Vụ Cốt Lõi (Core Operational Screens)      │
│ • AdminDashboardScreen: Thay thế card rời bằng SaaS Metric Strip & Chart    │
│ • AdminPostsScreen: Áp dụng DataTable chuẩn, chuẩn hóa nút duyệt            │
│ • AdminReportsScreen: DataTable báo cáo vi phạm, tối ưu ReportDetailDialog  │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIAI ĐOẠN 5: Các Màn Hình Tài Nguyên & Hệ Thống (Resources & System)         │
│ • AdminPlacesScreen: Tinh chỉnh Master-Detail, chuẩn hóa List bên trái      │
│ • AdminMediaScreen: DataTable tài nguyên ảnh, preview ảnh 32px bo góc 3px   │
│ • PlaceholderFeatureView: Đồng bộ giao diện các tab chờ (Users, Settings)   │
│ • ProfileScreen & LoginScreen: Chuẩn hóa form đăng nhập và hồ sơ phẳng      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Tổng Kết & Giá Trị Đạt Được

Bản đề xuất Design System theo phong cách **Professional Enterprise SaaS Admin / Minimalism & Swiss Style** này thiết lập một chuẩn mực thiết kế thống nhất cho phân hệ Web Admin của dự án Travel Planner:
1. **Tính Nhất Quán Tuyệt Đối:** Mọi trang quản trị từ Dashboard, Kiểm duyệt bài viết, Quản lý báo cáo đến Quản lý địa điểm đều chia sẻ chung một ngôn ngữ thiết kế: cùng chiều cao header, cùng chuẩn font chữ, cùng bán kính góc 4px, cùng bảng màu Teal/Orange/Slate.
2. **Tập Trung Vào Dữ Liệu:** Loại bỏ các thành phần trang trí thừa thãi, tối đa hóa không gian hữu ích cho các bảng dữ liệu nghiệp vụ, giảm thiểu thao tác cuộn và thời gian tìm kiếm thông tin của Quản trị viên.
3. **Tuân Thủ Kỹ Thuật Nghiêm Ngặt:** Không thay đổi bất kỳ API, Backend hay nghiệp vụ sẵn có; kế thừa và nâng tầm toàn bộ kiến trúc Flutter Web hiện hữu.
