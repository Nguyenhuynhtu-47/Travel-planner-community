# Technical Report: Flutter Web Admin Subtle Hover Movement Refinement

> **Project:** Travel Planner Community – Admin Web Portal (`Travel_Planner/frontend/web`)  
> **Related Documents:** `AGENTS.md`, `docs/plan/admin-design-system.md`, `docs/plan/34-admin-ui-refinement-and-layout-fix-report.md`, `docs/plan/35-admin-final-visual-polish-and-vietnamese-localization-report.md`, `docs/ai/09-development-log.md`  
> **Execution Date:** 2026-11-23 / 2026-11-24  
> **Status:** Completed Successfully (132/132 tests passed, 0 analyzer issues, clean production web build)

---

## 1. Executive Summary & Objective

In previous iterations, mouse hover interactions on Flutter Web Admin relied primarily on color changes, background tinting (`#FFF7F8`), or text color darkening. While functional, color shifts alone can appear flat or rigid.

The objective of this refinement is to introduce **Subtle Movement** micro-interactions across interactive elements. By incorporating slight translational micro-animations (1.0–2.0px) with smooth 150ms transitions (`Curves.easeOut`), the interface gains responsive, modern tactile depth while maintaining zero layout shifts, zero jitter, and strictly preserving the Airbnb Rausch design tokens (`#FF385C`, `#D90740`, `#FFF7F8`, `#FFD1DA`).

---

## 2. Motion Rules & Specifications

All hover animations adhere to the following strict parameters:
- **Duration:** 150ms (or `Duration.zero` when `MediaQuery.disableAnimations` is requested).
- **Easing Curve:** `Curves.easeOut` (snappy entrance, decelerating smoothly to a rest).
- **Return Motion:** Smooth deceleration back to initial state `(0.0, 0.0, 0.0)` upon mouse departure.
- **Affine Transformation:** Implemented via `Matrix4.translationValues(dx, dy, 0.0)` in `AnimatedContainer` or `HoverMovement`, rendering during the paint stage without mutating layout dimensions or causing layout reflow / RenderFlex overflow.
- **Brand Consistency:** 100% preservation of Rausch color tokens. No darkening or color mutation is used to replace movement.

---

## 3. Component Refinement Matrix

| Target Component | Previous Hover Effect | Refined Subtle Motion Effect | Motion Parameters | Implementation Mechanism |
|---|---|---|---|---|
| **Buttons (`AppPrimaryButton`, action TextButtons, OutlinedButtons, Header CTAs)** | Flat background tint or text color change only | **Subtle Upward Lift (-1.5px)**. Button lifts gently when hovered, providing crisp tactile feedback. | `dx: 0.0`, `dy: -1.5px`, `duration: 150ms`, `Curves.easeOut` | `HoverMovement.button(child: ...)` and `AppPrimaryButton` wrapper |
| **Statistic & Metric Cards (`_MetricCellWidget` on Dashboard)** | Background tint `#FFF7F8` without spatial movement | **Subtle Card Lift (-2.0px)**. Metric cards elevate gently upward along the vertical axis. | `dx: 0.0`, `dy: -2.0px`, `duration: 150ms`, `Curves.easeOut` | `transform: Matrix4.translationValues(0, isHovered ? -2.0 : 0, 0)` in `_MetricCellWidget` |
| **Media Gallery Cards (Media grid view)** | Static border without spatial motion | **Subtle Card Lift (-2.0px)**. Gallery cards elevate on hover with image and metadata intact. | `dx: 0.0`, `dy: -2.0px`, `duration: 150ms`, `Curves.easeOut` | `HoverMovement.card(child: ...)` inside `_buildGalleryGridView` |
| **Sidebar Menu Items (`_SidebarMenuItem` & Collapse Toggle)** | Background `#FFF7F8` and border without movement | **Subtle Horizontal Slide (+2.0px)**. Menu item smoothly nudges rightwards toward the content area. | `dx: 2.0px`, `dy: 0.0`, `duration: 150ms`, `Curves.easeOut` | `transform: Matrix4.translationValues(isHovered ? 2.0 : 0, 0, 0)` & `HoverMovement.slide` |
| **Data Table Rows (`AdminDataTable` rows in Posts, Places, Media, Reports)** | Row highlight without content movement | **Subtle Synchronized Shift (+1.5px)**. All cells in the hovered row subtly shift horizontally together. | `dx: 1.5px`, `dy: 0.0`, `duration: 150ms`, `Curves.easeOut` | `RowHoverTracker` + `_RowCellHoverWrapper` with 35ms exit debounce |

---

## 4. Reusable Motion Architecture: `HoverMovement`

To maintain clean code architecture and avoid code duplication across screens, a dedicated reusable motion widget `HoverMovement` was engineered in `shared/widgets/hover_movement.dart`:

```dart
class HoverMovement extends StatefulWidget {
  final Widget child;
  final double dx;
  final double dy;
  final Duration duration;
  final Curve curve;
  final bool enabled;
  final MouseCursor? cursor;
  final ValueChanged<bool>? onHoverChanged;

  const HoverMovement({ ... });

  factory HoverMovement.button({ ... }) => HoverMovement(dx: 0.0, dy: -1.5, ...);
  factory HoverMovement.card({ ... }) => HoverMovement(dx: 0.0, dy: -2.0, ...);
  factory HoverMovement.slide({ ... }) => HoverMovement(dx: 2.0, dy: 0.0, ...);
  factory HoverMovement.row({ ... }) => HoverMovement(dx: 1.5, dy: 0.0, ...);
  ...
}
```

### 4.1. Row Hover Coordination via `RowHoverTracker`
In `AdminDataTable`, Flutter's `DataTable` renders `DataCell`s across individual table slots. To prevent flickering when the pointer traverses cell boundaries:
1. Each `AdminDataRow` is associated with a `RowHoverTracker`.
2. When the cursor enters any cell, `tracker.enter()` immediately activates `isHovered = true`.
3. When the cursor transitions between columns, `tracker.exit()` initiates a 35ms debounce timer. If adjacent cells are entered, the timer cancels, ensuring continuous smooth elevation.
4. When the cursor departs the row entirely, `isHovered = false` triggers, restoring all cells to `(0,0)` smoothly.

---

## 5. Screen-by-Screen Verification

### 5.1. Dashboard Screen (`AdminDashboardScreen`)
- **Metric Cards:** 4 SaaS KPI cells elevate by `-2.0px` on hover with pointer cursor.
- **Refresh Action:** Header "Làm mới" button lifts by `-1.5px`.
- **Triage Action Links:** "Tất cả báo cáo →", "Xem tất cả →", and row action buttons lift cleanly.

### 5.2. Post Moderation Screen (`AdminPostsScreen`)
- **Data Table Rows:** 1.5px synchronized horizontal shift when hovering rows.
- **Action Buttons:** TextButtons ("Chi tiết", "Ẩn", "Khôi phục", "Xóa vĩnh viễn") lift upward by `-1.5px`.

### 5.3. Places Management Screen (`AdminPlacesScreen`)
- **Header CTAs:** "Làm mới" and "Thêm địa điểm" elevate upward by `-1.5px`.
- **Data Table Rows:** 1.5px synchronized horizontal shift.
- **Action Buttons:** "Chi tiết", "Sửa", "Ẩn"/"Kích hoạt" elevate upward by `-1.5px`.

### 5.4. Media Management Screen (`AdminMediaScreen`)
- **Dual View Support:**
  - Table View: Row cells shift right by `1.5px`, action buttons lift by `-1.5px`.
  - Gallery Grid View: Full media asset cards elevate upward by `-2.0px`.

### 5.5. Reports Moderation Screen (`AdminReportsScreen`)
- **Data Table Rows:** Synchronized 1.5px horizontal shift.
- **Action Buttons:** "Chi tiết", "Xử lý vi phạm", "Bỏ qua" lift upward by `-1.5px`.

---

## 6. Files Changed & Added

```
Travel_Planner/frontend/web/
├── lib/
│   ├── features/
│   │   ├── dashboard/presentation/screens/admin_dashboard_screen.dart # KPI card -2.0px lift, button lifts
│   │   ├── layout/presentation/widgets/admin_sidebar.dart             # Menu items +2.0px slide, toggle slide
│   │   ├── locations/presentation/screens/admin_places_screen.dart   # Header CTAs and action button lifts
│   │   └── moderation/presentation/screens/
│   │       ├── admin_media_screen.dart                                # Table button lifts & gallery card lifts
│   │       ├── admin_posts_screen.dart                                # Table action button lifts
│   │       └── admin_reports_screen.dart                              # Table action button lifts
│   └── shared/widgets/
│       ├── admin_data_table.dart                                      # Synchronized row hover translation
│       ├── app_primary_button.dart                                    # -1.5px button lift
│       └── hover_movement.dart                                        # Reusable subtle motion framework
└── test/
    └── hover_movement_test.dart                                       # Unit & widget tests for subtle motion
```

---

## 7. Verification Results

1. **Static Analysis (`flutter analyze`):**
   ```
   Analyzing web...
   No issues found! (ran in 2.5s)
   ```
   - **0 errors, 0 warnings, 0 lints**.

2. **Automated Test Suite (`flutter test`):**
   ```
   00:47 +132: All tests passed!
   ```
   - **132/132 tests passed 100%** (including new `hover_movement_test.dart` and 12 existing test suites).
   - Zero RenderFlex layout overflow across viewports (1440×900, 1366×768, 1024×768, 768×1024).

3. **Production Web Compilation (`flutter build web`):**
   ```
   Compiling lib\main.dart for the Web...
   √ Built build\web
   ```
   - Compiled cleanly with exit code 0.

---

## 8. Conclusion

The subtle motion enhancement successfully replaces static color shifts with elegant, physics-based micro-movements (1.0–2.0px). The interface feels responsive, modern, and fluid without altering actual layout bounds or compromising visual hierarchy.
