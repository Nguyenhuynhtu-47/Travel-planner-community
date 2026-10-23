# UX Guidelines

## 1. Core Principles

The user experience for Travel Planner connects community discovery with practical travel planning, adhering to the design patterns established in [`DESIGN.md`](../../DESIGN.md) and [`docs/ai/04-ui-design-system.md`](04-ui-design-system.md):
- **Content & Photo-First:** Give prominence to real community photos, itineraries, and experiences before dense UI controls.
- **Warm & Trustworthy:** Use modest typography, solid ink ratings (`#222222`), and generous whitespace to establish credibility and reduce visual fatigue.
- **Predictable Navigation:** Maintain clear orientation across screens, obvious back navigation, and consistent tab structures.
- **Prevent Mistakes:** Preserve user input during validation errors, avoid unnecessary confirmation dialogs for safe operations, and confirm only destructive actions.
- **Ergonomic by Platform:** On mobile, place primary actions within thumb reach (sticky bottom action bars and bottom navigation); on desktop web, leverage wider viewports with sticky side rails and multi-column card grids.

---

## 2. Key User Journeys & Interaction Patterns

### 2.1 Discovering Travel Itineraries
- **Home & Explore Feed:** Display itineraries in a photo-first grid (`property-card`). Each card features an image with 14px rounded corners (`rounded.md`), a "Guest favorite" badge top-left when applicable, a favorite heart icon top-right, and 4–5 lines of meta (title, duration, dates/season, estimated budget).
- **Category Browsing:** Horizontal category strip below top navigation allows users to quickly filter by trip style (e.g., Phượt, Nghỉ dưỡng, Ẩm thực, Khám phá thiên nhiên). Active category uses an ink text indicator; inactive items use muted gray.
- **Visual Rhythm:** High card density (16px grid gap) gives immediate discovery value without requiring excessive scrolling.

### 2.2 Search, Filter, and Sort
- **Desktop Search:** A signature pill-shaped search bar (`search-bar-pill`, 64px height, 9999px radius) positioned prominently. Segments partition search by:
  - **Điểm đến (Where):** Autocomplete destination suggestions with location icons.
  - **Thời gian (When):** Date range selection.
  - **Ngân sách / Người đi (Who/Budget):** Steppers for travel party size or budget brackets.
  - **Search Orb:** Circular Rausch (`#FF385C`) button triggers search.
- **Mobile Search:** Collapses into a single compact pill at the top of the feed. Tapping it opens a clean, full-screen search overlay with segmented tabs for Where, When, and Filter options.
- **Filter & Sort Feedback:** Active filters appear as dismissible pill chips. When no itineraries match, present an `AppEmptyState` with a clear "Đặt lại bộ lọc" (Reset filters) button.

### 2.3 Viewing Itinerary & Destination Details
- **Photo Showcase:** Listing detail starts with an edge-rounded photo banner or carousel displaying key destination highlights.
- **Rating Trust Signal:** Feature a prominent `rating-display` (64px / w700 rating score in Ink `#222222`) accompanied by review count and community badges. Ratings avoid gaudy yellow stars to maintain an authentic, high-trust consumer feel.
- **Two-Column Desktop Layout:**
  - Left Column (~64% width): Comprehensive itinerary overview, author profile card, day-by-day activity timeline with route details, amenity highlights, and community reviews.
  - Right Column (~32% width): Sticky action rail (`itinerary-action-card`, derived from `reservation-card`) displaying estimated total trip budget, duration, date details, and prominent primary CTAs: "Lưu vào chuyến đi của tôi" and "Sao chép lịch trình".
- **Mobile Detail Adaptation:** The action rail collapses into a persistent sticky bottom bar (56–64px height) above the thumb navigation area, displaying the estimated cost and a primary action button ("Lưu" / "Sao chép").

### 2.4 Creating and Editing Itineraries
- **Structured Steps:** Group itinerary creation into logical steps: General Info (title, cover photo, estimated budget, duration) -> Day Schedule -> Activity Details (time, destination, cost, notes).
- **Input Fields:** Form inputs follow the 56px white surface specification (`text-input`) with 8px radius and stacked labels. Focus changes border stroke to 2px solid ink (`#222222`) without distracting colored halos.
- **Schedule Management:** Allow easy addition, reordering, and removal of days and activities. Confirm before discarding unsaved edits.
- **Preserve Drafts:** Prevent accidental data loss if the user switches tabs or navigates backwards.

### 2.5 Saving and Reusing Itineraries
- **Saving / Favoriting:** Tapping the heart icon on any itinerary card instantly toggles bookmark status. Provide immediate visual feedback (heart fills with Rausch `#FF385C`) and a lightweight confirmation via `SnackBar`.
- **Reusing / Cloning:** Explicitly communicate the distinction between saving a reference and creating a cloned copy:
  - Reusing clones the itinerary structure into a new personal draft owned by the user.
  - The cloned itinerary retains original author attribution as required by business rules, while allowing the user to customize activities and budget independently.
  - Provide a clear success message with a direct link to "Chỉnh sửa bản sao" (Edit copy).

### 2.6 Community Interactions: Ratings, Comments, and Following
- **Rating Submission:** Only users eligible under backend business rules can rate. Use a 5-star rating selector rendered in `#222222` ink with clear score descriptions (1 = Rất tệ, 5 = Tuyệt vời).
- **Comments & Reviews:** Present reviews in a 2-column grid on desktop and single column on mobile. Each review card displays author avatar, name, trip date, and readable body copy (`body-md`), with a "Xem thêm" tertiary button for long text.
- **Following Members:** User profile pages provide an author bio card, verification badges, total published itineraries, and a secondary outline button ("Theo dõi" / "Đang theo dõi").

### 2.7 Authentication and Profile Management
- **Auth Flow:** Clean, distraction-free modal sheet or dedicated centered card (max width 480px). Standardized 56px text inputs with stacked labels, clear inline validation error text in `#C13515`, and a 48px full-width Rausch primary CTA.
- **Profile Screen:** Profile overview displaying avatar, contact info, bio, and segmented tabs: "Lịch trình đã tạo", "Lịch trình đã lưu", and "Lịch trình đã tái sử dụng".

---

## 3. Loading States

- **Page-Level Loading:** Centered spinner (`CircularProgressIndicator` in Rausch `#FF385C`) against the white canvas with an optional descriptive message (e.g., *"Đang tải lịch trình..."*).
- **Component-Level Loading:** Localized inline indicator inside the specific card or section being updated, avoiding blocking user interaction on the rest of the screen.
- **Button-Level Loading:** Disable the CTA immediately upon press and display an embedded spinner (18x18dp, white) to strictly prevent duplicate submissions during network dispatch.
- **Feed Loading:** Use skeleton placeholder cards matching the `property-card` aspect ratio with 14px rounded corners (`rounded.md`) to avoid layout jumps while fetching content.
- **Async Disposal:** Always cancel HTTP requests and dispose listeners when the user navigates away before completion.

---

## 4. Empty States (`AppEmptyState`)

Every list or content container must handle empty collections gracefully:
1. **Title:** Semi-bold 16px (`title-md`), concise summary (e.g., *"Chưa có lịch trình đã lưu"*).
2. **Description:** 14px muted text (`body-sm`, `#6A6A6A`) explaining the state and how to populate it (e.g., *"Khám phá các chuyến đi cộng đồng và nhấn biểu tượng trái tim để lưu lại tại đây"*).
3. **Primary Action Button:** A clear CTA using `button-primary` or `button-secondary` (e.g., *"Khám phá ngay"*, *"Tạo lịch trình mới"*, *"Đặt lại bộ lọc"*).
4. **Visual Indicator:** Neutral illustration or icon (48x48dp in muted `#6A6A6A`). Avoid bright colored graphics that distract from the message.

---

## 5. Error States and Safe Retries

- **No Technical Leaks:** Never display raw Java stack traces, database schema details, or SQL errors to users.
- **Categorized User Messages:**
  - *Network failure:* "Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng." + [Thử lại] button.
  - *Validation failure (HTTP 400):* Inline red text (`#C13515`) below each invalid field.
  - *Session expired (HTTP 401):* "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." Redirect to Login.
  - *Access denied (HTTP 403):* "Bạn không có quyền truy cập hoặc chỉnh sửa nội dung này."
  - *Not found (HTTP 404):* "Lịch trình không tồn tại hoặc đã bị xóa."
  - *Server error (HTTP 500):* "Hệ thống gặp sự cố tạm thời. Vui lòng thử lại sau."
- **Safe Retry Rules:**
  - For **read-only operations** (GET queries), provide a prominent "Thử lại" (Retry) action.
  - For **mutating operations** (POST, PUT, DELETE), **never automatically retry** requests to prevent duplicate transactions. Require manual user re-submission.

---

## 6. Forms and Validation

- **Stacked Labels:** Labels sit above inputs in `caption` (14px / w500, `#6A6A6A`), keeping forms clean and scannable.
- **Immediate Inline Feedback:** Display field-specific validation errors beneath the input field in `#C13515` error text.
- **Preserve Valid Data:** Never wipe filled form fields when a network or validation error occurs.
- **Unsaved Changes Confirmation:** Prompt the user before leaving a dirty form with substantial edits.

---

## 7. Destructive Actions

- Explicitly confirm actions that cannot be reversed (deleting an itinerary, removing an activity, deleting an account).
- Display the item name clearly in the confirmation dialog.
- Destructive action button uses semantic error styling; cancel button uses `button-secondary` or `button-tertiary-text`.
- Do not show confirmation dialogs for safe, easily reversible actions (e.g., unsaving a bookmarked itinerary).

---

## 8. Accessibility and Touch Targets

- **Touch Targets:** All clickable controls (buttons, search orb, heart icon, date cells) must have an effective hit area of at least **48x48dp** on touch devices.
- **Contrast Targets (WCAG 2.1 AA Guidance):**
  - **Normal text** (< 24px regular, < 18.66px bold, including standard 14px and 16px button labels): Must target a minimum **4.5:1** contrast ratio against the background (fulfilled by `ink` `#222222` at **15.91:1** and `body` `#3F3F3F` at **10.53:1** on `#FFFFFF` canvas). Standard 16px button labels are normal text and must not be classified as large text.
  - **Large text** (>= 24px regular, or >= 18.66px bold at font weight 700+): Must target a minimum **3.0:1** contrast ratio.
  - **Non-text UI components and visual states:** Visual information necessary to identify user interface components and states (such as active control boundaries, search orb bounds, and focus indicators) must target a minimum **3.0:1** contrast against adjacent backgrounds, where applicable.
  - **Rausch (`#FF385C`) Contrast Reality & Adjustments:**
    - For resting primary CTAs, white text (`#FFFFFF`) on canonical brand Rausch (`#FF385C`) yields a contrast ratio of **3.52:1** (satisfying 3.0:1 for large text $\ge$ 18.66px bold or $\ge$ 24px regular and non-text component boundaries under SC 1.4.11, but falling short of 4.5:1 for normal text under SC 1.4.3).
    - `primary-active` (`#E00B41`): White text (`#FFFFFF`) on `#E00B41` yields a contrast ratio of **4.89:1**. It is documented in `DESIGN.md` strictly as the active press / pointer-down state (`button-primary-active`), not a hover state or default resting CTA replacement.
    - Where strict WCAG AA 4.5:1 compliance for normal text button labels is required at rest, the proposed alternative token `primary-accessible` (`#D90740`: white text `#FFFFFF` on `#D90740` yields **5.18:1**) is documented as a design proposal for high-contrast accessibility without replacing the canonical brand reference `#FF385C`. This token is a documented proposal and does not signify that a complete high-contrast mode is already implemented. Alternatively, pairing `#FF385C` background with dark `ink` text (`#222222`) satisfies the normal-text requirement at **4.52:1**. Both `#E00B41` and `#D90740` backgrounds are verified to meet the 4.5:1 requirement for white normal text.
  - *Testing & Verification Role:* Contrast rules are design specifications and testing targets, not evidence of already-certified compliance. Satisfying contrast criteria alone does not guarantee overall WCAG compliance; comprehensive evaluation of keyboard focus, touch targets, and semantics is required during implementation.
- **Keyboard Navigation:** Web interfaces must support Tab navigation, Enter/Space activation, and visible focus indicators (2px solid ink border).
- **Text Sizing:** Respect platform text scaling settings without clipping layout containers.
