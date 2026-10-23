# UI Design System

## 1. Design Direction and Philosophy

The Travel Planner UI design system is synchronized with the root visual design reference [`DESIGN.md`](../../DESIGN.md).

It embodies a **warm, generous, photography-led consumer marketplace** built on a clean white canvas, soft rounded geometry, and a single high-voltage brand accent, tailored specifically to travel itinerary sharing, discovery, and planning:
- **Canvas-first:** A pure white base (`#FFFFFF`) with deep near-black typography (`#222222`), prioritizing real destination photography, travel experiences, and generous whitespace over heavy decoration.
- **Single Brand Voltage:** **Rausch** (`#FF385C`) carries every primary Call-to-Action (CTA), search-button orb, saved favorite heart state, and active brand indicator. Mainline interfaces do not dilute Rausch with conflicting secondary brand colors.
- **Soft Shape Language:** Every interactive element is softened — buttons use an 8px radius (`rounded.sm`), itinerary cards use ~14px (`rounded.md`), and search inputs, category chips, and badges use pill/circular geometry (`rounded.full`). There are no harsh right angles on interactive surfaces.
- **Modest Typographic Weight:** Display headlines stay between 20px–28px at modest weights (w500–w700), trusting photography and whitespace to anchor visual hierarchy rather than oversized bold fonts. The only typographically dominant element is the rating trust display (64px / w700).
- **Single Elevation Tier:** Elevation relies on white-on-white surface separation and 1px hairlines. A single subtle shadow tier is reserved for card hover float, search bars at rest, and floating overlays/dropdowns.
- **Platform-Specific Ergonomics:** Provides unified visual tokens across Flutter Mobile and Flutter Web, while respecting platform differences:
  - **Mobile:** Thumb-friendly interactions, sticky bottom action bars, bottom navigation bar, and compact tap-to-expand search.
  - **Web:** Multi-column itinerary grids, sticky right-side action rail on details, and persistent side navigation rails for administrative and moderation workflows (`frontend/web`).

---

## 2. Color System

### 2.1 Brand & Accent Tokens (from `DESIGN.md`)
| Token Name | Hex Value | Purpose / Usage Rules |
|---|---|---|
| `primary` (Rausch) | `#FF385C` | The single primary brand color. Used for primary CTAs ("Lưu", "Tạo chuyến đi", "Tiếp tục"), the search orb, active favorite heart icon, and active brand links. Used selectively (~10% of surface accents). |
| `primary-active` | `#E00B41` | Press / pointer-down variant for primary buttons (`button-primary-active`). Strictly documented in `DESIGN.md` for the press state, not a hover state or default resting CTA replacement. |
| `primary-disabled` | `#FFD1DA` | Disabled primary button background fill (paired with white text). |
| `luxe` | `#460479` | Scoped sub-brand accent for luxury/premium itinerary showcases. Never used in general marketing or standard screens. |
| `plus` | `#92174D` | Scoped sub-brand accent for verified/curated premium itineraries. |

### 2.2 Surface & Background Tokens (from `DESIGN.md`)
| Token Name | Hex Value | Purpose / Usage Rules |
|---|---|---|
| `canvas` | `#FFFFFF` | Default page background floor across all public and user screens. The public interface uses a clean white background. |
| `surface-soft` | `#F7F7F7` | Lightest fill. Used for disabled text fields, sub-navigation hover backgrounds, and inline search filter bands. |
| `surface-card` | `#FFFFFF` | Card background fill. Relies on 1px hairline border or hover elevation. |
| `surface-strong` | `#F2F2F2` | Secondary fill for circular icon button backgrounds (e.g., toolbar back button, close button). |

### 2.3 Hairlines & Borders (from `DESIGN.md`)
| Token Name | Hex Value | Purpose / Usage Rules |
|---|---|---|
| `hairline` | `#DDDDDD` | Default 1px border tone: search bar segment dividers, card 1px borders, table separators, and header/footer dividing rules. |
| `hairline-soft` | `#EBEBEB` | Subtle 1px divider for long-scrolling editorial body sections and activity schedule lists. |
| `border-strong` | `#C1C1C1` | Heavier stroke used for disabled outline buttons and form input outlines upon focus. |

### 2.4 Text & Typography Tokens (from `DESIGN.md`)
| Token Name | Hex Value | Purpose / Usage Rules |
|---|---|---|
| `ink` | `#222222` | Dominant text color on light surfaces: headlines, body titles, primary nav links, and ratings. Never pure `#000000`. |
| `body` | `#3F3F3F` | Secondary running-text color for descriptions, long reviews, and itinerary details where ink is visually heavy. |
| `muted` | `#6A6A6A` | Sub-labels, inactive navigation tabs, date ranges, duration text, and helper labels. |
| `muted-soft` | `#929292` | Disabled links and placeholder text. Used sparingly. |
| `star-rating` | `#222222` | Rating star glyphs and rating numbers ("4.85"). Rendered in ink rather than yellow/gold to preserve credibility and trust. |
| `on-primary` | `#FFFFFF` | Text and icon color over Rausch (`primary`) backgrounds. |
| `on-dark` | `#FFFFFF` | Text and icon color over dark or media overlays. |

### 2.5 Semantic & Feedback Tokens
| Token Name | Hex Value | Source | Purpose / Usage Rules |
|---|---|---|---|
| `primary-error-text` | `#C13515` | `DESIGN.md` | Inline form validation error text and error highlights. Distinct from Rausch (darker, saturated red). |
| `primary-error-text-hover` | `#B32505` | `DESIGN.md` | Darkened error state on link hover. |
| `legal-link` | `#428BFF` | `DESIGN.md` | Inline links inside legal/terms copy. |
| `scrim` | `#000000` (50% opacity) | `DESIGN.md` | Modal backdrop overlay for dialogs, date pickers, and bottom sheets. |
| `success` | `#10B981` (Emerald 500) | Project-specific | Completed trips, positive status chips, published badges. |
| `warning` | `#F59E0B` (Amber 500) | Project-specific | Moderation alerts, draft itineraries, attention notices. |
| `info` | `#3B82F6` (Blue 500) | Project-specific | Informational tooltips, guide notes, system updates. |

> **Note on Codebase Theme Status**: The existing Flutter theme files in `frontend/mobile/lib/core/theme/app_colors.dart` and `frontend/web/lib/core/theme/app_colors.dart` currently contain legacy Teal (`#0D9488`) / Orange (`#F97316`) definitions. In accordance with task scope restrictions, application source code is not modified in this documentation task; updating the Dart theme implementation to match these canonical tokens is designated as a follow-up implementation task.

---

## 3. Typography and Font Strategy

### 3.1 Font Family Hierarchy & Fallback Strategy
- **Reference Typeface (Upstream):** `Airbnb Cereal VF` (Variable Font) with fallbacks `Circular, -apple-system, system-ui, Roboto, 'Helvetica Neue', sans-serif`. `Airbnb Cereal VF` is a proprietary licensed typeface referenced in `DESIGN.md` and is **not bundled** in this repository.
- **Proposed Open-Source Substitute:** **Inter** is the closest open-source substitute suggested by `DESIGN.md` (with display line-heights adjusted ~2% tighter). However, `Inter` is **not currently configured** in `pubspec.yaml` or bundled as an asset. Adopting `Inter` or adding `google_fonts` requires explicit project owner approval in a dedicated implementation task.
- **Current Active Codebase Fallback:** The active theme (`lib/core/theme/app_theme.dart`) currently configures `fontFamily: 'Roboto'` (or standard platform system defaults).
- **Approved Fallback Chain:**
  1. `Airbnb Cereal VF` / `Circular` (if present in host environment)
  2. `Inter` (proposed substitute upon future integration)
  3. `Roboto` / Platform System Default (active current fallback)
- *Scope Rule:* Do not download font assets, modify `pubspec.yaml`, or add font packages during documentation synchronization tasks.

### 3.2 Type Scale Hierarchy (from `DESIGN.md`)
| Token Name | Size | Weight | Line Height | Letter Spacing | Purpose in Travel Planner |
|---|---|---|---|---|---|
| `rating-display` | 64px | 700 (Bold) | 1.10 | -1.0px | Signature itinerary detail rating score ("4.85") |
| `display-xl` | 28px | 700 (Bold) | 1.43 | 0px | Major screen hero h1 ("Khám phá chuyến đi cộng đồng") |
| `display-lg` | 22px | 500 (Medium) | 1.18 | -0.44px | Itinerary detail title, destination header |
| `display-md` | 21px | 700 (Bold) | 1.43 | 0px | Section headers ("Lịch trình từng ngày", "Chi phí dự kiến") |
| `display-sm` | 20px | 600 (SemiBold)| 1.20 | -0.18px | Sub-section titles ("Thông tin cần biết", "Quy định") |
| `title-md` | 16px | 600 (SemiBold)| 1.25 | 0px | Card titles, destination card names, modal headings |
| `title-sm` | 16px | 500 (Medium) | 1.25 | 0px | Section sub-titles, web footer column headers |
| `body-md` | 16px | 400 (Regular) | 1.50 | 0px | Default body running text, amenity labels, activity descriptions |
| `body-sm` | 14px | 400 (Regular) | 1.43 | 0px | Card meta lines (dates, budget, duration, author) |
| `caption` | 14px | 500 (Medium) | 1.29 | 0px | Search field segment labels ("Điểm đến", "Thời gian") |
| `caption-sm` | 13px | 400 (Regular) | 1.23 | 0px | Timestamps, legal copy, copyright lines |
| `badge` | 11px | 600 (SemiBold)| 1.18 | 0px | "Được yêu thích" floating badge text, counter chips |
| `micro-label` | 12px | 700 (Bold) | 1.33 | 0px | Activity category chips, compact tags |
| `uppercase-tag` | 8px | 700 (Bold) | 1.25 | +0.32px | Uppercase "MỚI" / "NEW" badge on navigation items |
| `button-md` | 16px | 500 (Medium) | 1.25 | 0px | Standard CTA buttons (48px height) |
| `button-sm` | 14px | 500 (Medium) | 1.29 | 0px | Compact pill buttons, category strip chips |
| `link` | 14px | 400 (Regular) | 1.43 | 0px | Inline text links |
| `nav-link` | 16px | 600 (SemiBold)| 1.25 | 0px | Main navigation labels |

### 3.3 Typography and WCAG Contrast Guidelines

- **Modest Display Weights:** Avoid using heavy weights (w800/w900) for standard page titles. Rely on photography and whitespace for visual prominence.
- **Single Bold Accent:** The 64px `rating-display` is the primary typographic trust element on detail screens; do not introduce competing oversized numbers.
- **WCAG 2.1 AA Contrast Requirements:**
  - **Normal Text** (< 18pt / ~24px regular, or < 14pt / ~18.66px bold): Must target a minimum contrast ratio of **4.5:1** against the background (WCAG SC 1.4.3). Typical 16px button labels (`button-md`), 14px button labels (`button-sm`), form inputs, and running body text are normal text and must not be classified as large text.
  - **Large Text** (>= 18pt / ~24px regular, or >= 14pt / ~18.66px bold at font weight 700+): Must target a minimum contrast ratio of **3.0:1** (WCAG SC 1.4.3).
  - **Non-Text UI Components and Visual States** (WCAG SC 1.4.11): Visual information necessary to identify user interface components and states (such as active control boundaries, search orb bounds, and focus indicators) must target a minimum contrast ratio of **3.0:1** against adjacent backgrounds, where applicable.
- **Contrast Verification for Brand Rausch (`#FF385C`):**
  - Rausch `#FF385C` has a calculated relative luminance of $L \approx 0.24861$; white `#FFFFFF` has $L = 1.0$.
  - The contrast ratio between `#FF385C` and `#FFFFFF` is:
    $$\frac{1.0 + 0.05}{0.24861 + 0.05} = \frac{1.05}{0.29861} \approx \mathbf{3.52:1}$$
  - *Evaluation:*
    - Meets the 3.0:1 criterion for non-text UI components (e.g., search orb container against white canvas) and large text (>= 24px or >= 18.66px bold).
    - **Fails** the 4.5:1 criterion for normal text. Therefore, white text (`#FFFFFF`) on `#FF385C` (such as standard 16px or 14px CTA button labels) and `#FF385C` text on `#FFFFFF` (such as inline body links) do not achieve the 4.5:1 contrast required for normal text under WCAG AA.
- **Documented Adjustments for WCAG AA Contrast Criteria (SC 1.4.3 & SC 1.4.11):**
  - Rather than asserting compliance for normal-sized white-on-Rausch button labels, the design system clarifies token roles and specifies accessible alternatives:
    - **Token Roles & Distinctions:**
      - **`primary` (`#FF385C` - Rausch):** The canonical brand reference token from `DESIGN.md`. Used as the default resting background for `button-primary`, the search orb, active save heart icons, and brand accents. White text (`#FFFFFF`) on resting `#FF385C` achieves a contrast ratio of **3.52:1** (satisfying 3.0:1 for large text and non-text UI components, but failing the 4.5:1 criterion for normal text).
      - **`primary-active` (`#E00B41` - Rausch Active):** The canonical active/press state token from `DESIGN.md`. Documented exclusively as the press / pointer-down variant for `button-primary-active`. White text (`#FFFFFF`) on `#E00B41` has a relative luminance of $L \approx 0.16468$, producing a contrast ratio of **4.89:1** against `#FFFFFF`. It must not be repurposed as the default resting CTA background or equated with a hover state, as `DESIGN.md` defines it specifically as the press state.
      - **`primary-accessible` (`#D90740`):** A proposed project-specific accessible alternative token (not present in `DESIGN.md`), documented as a design proposal for high-contrast accessibility mode or whenever strict WCAG 2.1 AA 4.5:1 contrast for normal-sized white button text is mandated at rest. Its relative luminance is $L \approx 0.15274$, producing a contrast ratio of **5.18:1** for white text (`#FFFFFF`) on `#D90740` (strictly exceeding 4.5:1). This token is a documented proposal and does not signify that a complete high-contrast mode currently exists in the application.
    - **Text-Color Adjustment:** When using `#FF385C` as a background fill, pairing it with dark `ink` text (`#222222`, relative luminance $L \approx 0.01600$, contrast ratio $\frac{0.24861 + 0.05}{0.01600 + 0.05} \approx \mathbf{4.52:1}$) satisfies the 4.5:1 normal-text threshold.
    - **Running Body Text & Links:** `#FF385C` must not be used for running body copy or text links without underline on `#FFFFFF` canvas. Running text on white canvas must use `ink` (`#222222`, contrast ratio **15.91:1** vs `#FFFFFF`) or `body` (`#3F3F3F`, relative luminance $L \approx 0.04971$, contrast ratio **10.53:1** vs `#FFFFFF`); inline validation error text on white canvas uses `primary-error-text` (`#C13515`, relative luminance $L \approx 0.13938$, contrast ratio **5.54:1** vs `#FFFFFF`).
- *Status Note:* These contrast ratios and adjustments represent design specifications and testing targets, not evidence or claims that the application has already passed accessibility verification. Satisfying contrast criteria alone does not guarantee overall WCAG compliance; comprehensive automated and manual accessibility testing (covering touch targets, keyboard navigation, focus indicators, and screen reader semantics) must be conducted during frontend UI implementation.

---

## 4. Spacing, Sizing, and Layout

### 4.1 Spacing Scale (from `DESIGN.md`)
The system is built on a **4px base grid** with a 2px micro-step:
| Token Name | Value | Purpose |
|---|---|---|
| `spacing.xxs` | 2px | Micro-adjustments, badge inner padding, border offsets |
| `spacing.xs` | 4px | Dense icon-to-text spacing, category strip dividers |
| `spacing.sm` | 8px | Caption gutters, chip internal padding, compact element spacing |
| `spacing.md` | 12px | Amenity list row padding, input horizontal inner padding |
| `spacing.base` | 16px | Standard card meta block padding, grid gutters between cards |
| `spacing.lg` | 24px | Card internal padding (author card, sticky action rail), web column gutters |
| `spacing.xl` | 32px | Section sub-headers, pill category strip corner radius |
| `spacing.xxl` | 48px | Page header spacing, major block breathing room |
| `spacing.section` | 64px | Major page section vertical padding |

### 4.2 Layout & Grid Conventions
- **Page Container Max Width:**
  - Standard Editorial / Homepage: `~1280px` centered.
  - Detail & Sticky Action Pages: `~1080px` centered (balances photo presentation with action rail).
  - Search / Discovery Full-Width: capped at `1440px`.
- **Vertical Section Rhythm:** Major sections use `64px` (`spacing.section`) vertical padding. Card grids sit compactly at `16px` (`spacing.base`) to preserve high item density per scroll.
- **Card Grids:**
  - Mobile (< 744px): 1 column.
  - Tablet (744px – 1128px): 2 columns.
  - Desktop (1128px – 1440px): 3–4 columns.
  - Wide (> 1440px): 4 columns.

---

## 5. Shape Language, Corner Radii, and Elevation

### 5.1 Corner Radii (`rounded`)
| Token Name | Value | Component Application |
|---|---|---|
| `rounded.none` | 0px | Underline indicators, full-bleed media dividers |
| `rounded.xs` | 4px | Micro tags, compact indicators |
| `rounded.sm` | 8px | Standard buttons (`button-primary`, `button-secondary`), form text inputs |
| `rounded.md` | 14px | Itinerary cards, photo banner clipping, author cards, modal sheets |
| `rounded.lg` | 20px | Large promo cards, dialog surfaces |
| `rounded.xl` | 32px | Category strip chips, segmented filter bars |
| `rounded.full` | 9999px | Search pill bar, circular search orb, favorite heart buttons, guest favorite badge |

### 5.2 Elevation & Shadows
The system uses a **flat baseline with one shadow tier**:
- **Flat (No Shadow):** 95% of surfaces (page canvas, list containers, footers, headers) rely on pure white with 1px `hairline` (`#DDDDDD`) borders.
- **Card Hover Float & Floating Elements:**
  - CSS equivalent: `box-shadow: rgba(0, 0, 0, 0.02) 0 0 0 1px, rgba(0, 0, 0, 0.04) 0 2px 6px 0, rgba(0, 0, 0, 0.1) 0 4px 8px 0`
  - Flutter equivalent: `BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 4))`, layered with subtle ambient shadow.
  - Applied to: Itinerary card hover state, pill search bar at rest, sticky action card, floating guest favorite badge, and dropdown menus.
- **Modal Scrim:** `#000000` at 50% opacity (`scrim`) for all modal dialogs, date pickers, and mobile bottom sheet backdrops.

---

## 6. Components

### 6.1 Buttons
- **`button-primary`:** Background `#FF385C` (Rausch), text `#FFFFFF`, font `button-md` (16px / w500), radius `8px` (`rounded.sm`), height `48px`, padding `14px 24px`. Minimum touch target 48x48dp.
- **`button-primary-active`:** Background `#E00B41` on press/pointer down.
- **`button-primary-disabled`:** Background `#FFD1DA`, text `#FFFFFF`, cursor not-allowed.
- **`button-secondary`:** Background `#FFFFFF`, text `#222222` (ink), 1px `#222222` border, radius `8px`, height `48px`.
- **`button-tertiary-text`:** Transparent background, text `#222222`, underlined on hover. Used for "Xem thêm", modal close, and secondary actions.
- **`button-pill-rausch`:** Background `#FF385C`, text `#FFFFFF`, font `button-sm` (14px / w500), radius `9999px` (`rounded.full`), padding `10px 20px`. Used for high-visibility featured CTAs ("Tạo chuyến đi").

### 6.2 Global Search Pill & Orb
- **`search-bar-pill`:** Height `64px`, radius `9999px` (`rounded.full`), white fill, 1px `#DDDDDD` hairline border, subtle elevation shadow.
  - Divided by vertical 1px hairline rules into segments: **Điểm đến** (Where), **Thời gian** (When), **Ngân sách/Người đi** (Who).
  - Terminated on the right by the **`search-orb`**: 48x48px circular Rausch (`#FF385C`) button containing a white magnifying-glass icon.
- **Mobile Collapse:** On mobile screens (< 744px), collapses to a compact 48px pill displaying a single search prompt, tapping which opens a full-screen search/filter modal.

### 6.3 Top Navigation
- **`top-nav`:** Height `80px`, white background, 1px bottom `#DDDDDD` hairline divider.
  - Left: Travel Planner logo/wordmark.
  - Center (Web): Discovery category tabs (Lịch trình phổ biến, Trải nghiệm, Điểm đến) with 32px icons, active indicator (2px ink underline).
  - Right: "Tạo chuyến đi" button, language/region picker, and user account avatar/menu.
- **Mobile Top Bar:** Height 56px, logo left, compact search or profile icon right; primary navigation resides in the bottom navigation bar.

### 6.4 Itinerary Listing & Detail Cards
- **`itinerary-card` (Derived from `property-card`):** Photo-first card presenting travel itinerary summaries.
  - Image: 1:1 or 4:3 aspect ratio photo with `14px` (`rounded.md`) corner clipping.
  - Floating Badges: Top-left `guest-favorite-badge` ("Được yêu thích", white pill with subtle shadow), top-right circular heart favorite button (`icon-button-circle`, 32x32dp, white outline at rest, Rausch filled when saved).
  - Meta block (beneath photo): Title in `title-md` (`#222222`), duration & season in `body-sm` (`#6A6A6A`), estimated budget in `body-sm` bold (`#222222`).
- **`rating-display-card`:** Detail screen trust banner featuring the large `64px` rating score flanked by laurel wreath ornaments, review count, and community rank.
- **`itinerary-action-card` (Sticky Action Rail / Bottom Bar, Derived from `reservation-card`):**
  - Desktop: Sticky right-rail card (`~32%` width), 24px padding, 14px radius, 1px hairline border, subtle shadow. Contains estimated total trip budget summary, recommended duration, date selector, "Lưu vào chuyến đi của tôi" (Bookmark) and "Sao chép lịch trình" (Reuse/Clone) primary CTAs, and activity breakdown.
  - Mobile: Collapses to a sticky bottom bar (56–64px height) above the bottom safe area with estimated budget summary and primary action button.
- **`author-card` (Derived from `host-card`):** Community creator card presenting author avatar, name, verification badge, total published itineraries, and a "Xem trang cá nhân" or "Theo dõi" secondary button.

### 6.5 Form Inputs
- **`text-input`:** White surface, 1px `#DDDDDD` border, 8px radius (`rounded.sm`), 56px height, 14x12px padding.
  - Label: stacked caption (`caption`, 14px / w500, `#6A6A6A`).
  - Input text: `body-md` (16px / w400, `#222222`).
  - Focus state: Border stroke thickens to 2px solid `#222222` (ink); no colored outer ring or glow.
  - Error state: Border flips to `#C13515`, inline helper text in `caption` with `#C13515`.

### 6.6 System State Displays
- **Loading State:** Centered `CircularProgressIndicator` in Rausch (`#FF385C`) for page-level loads; skeleton cards with `rounded.md` clipping for feed loading; localized button spinner (18x18dp) for asynchronous form submission.
- **Empty State (`AppEmptyState`):** Centered layout with muted visual illustration/icon (48x48dp), semi-bold headline (`title-md`), supportive description (`body-sm`), and a clear primary action button ("Khám phá ngay", "Tạo lịch trình").
- **Error State (`AppErrorState`):** Clear explanation in friendly language (no stack traces or SQL errors) with a primary retry action for GET queries.

---

## 7. Responsive Breakpoints and Platform Adaptations

### 7.1 Breakpoints
| Breakpoint Name | Screen Width | Key Layout Characteristics |
|---|---|---|
| **Mobile** | `< 744px` | 1-column itinerary feed; single-tap compact search pill; top nav collapses to logo + action icon; primary navigation via bottom navigation bar (`NavigationBar`); itinerary action rail collapses to sticky bottom bar; touch targets >= 48x48dp. |
| **Tablet** | `744px – 1128px` | 2-column itinerary feed; narrower search pill; product tabs visible; sticky right action rail enabled on detail pages; collapsible drawer on admin surfaces. |
| **Desktop** | `1128px – 1440px` | 3–4 column itinerary feed; full 3-segment search pill (`search-bar-pill`) at 64px height; full top navigation; 2-column detail page (64% content, 32% sticky right action rail); persistent sidebar rail on admin web. |
| **Wide** | `> 1440px` | Max container width capped at 1280px–1440px centered with margin absorption; prevents excessive stretched text lines. |

### 7.2 Flutter Web & Administrative Workflow Considerations
- **Scope Alignment:** Based on project architecture (`docs/ai/01-architecture.md`), `frontend/web` serves primarily as the administration, moderation, and content management platform (`dashboard`, `moderation`, `violations`, `users`), while supporting responsive layouts.
- **Admin Layout Patterns:**
  - Uses the same visual tokens (white canvas `#FFFFFF`, 1px hairlines `#DDDDDD`, 8px input radius, 14px card radius, Rausch primary CTA highlights, and ink typography).
  - Employs persistent side navigation rails, structured data tables with bottom pagination bars, and moderation split panels suitable for desktop mouse/keyboard workflows.
  - Does not force mobile bottom navigation or consumer-only category strips onto administrative dashboards.

---

## 8. Implementation Status and Categorization

To maintain project integrity across documentation and codebase:

### Category 1: Explicit Decisions from `DESIGN.md` (Adopted as Canonical Standard)
- Rausch (`#FF385C`), ink (`#222222`), body (`#3F3F3F`), muted (`#6A6A6A`), hairline (`#DDDDDD`), and canvas (`#FFFFFF`).
- 4px spacing scale and 64px section rhythm.
- Soft radii scale: 8px (buttons/inputs), 14px (cards), 9999px (pills/orbs).
- Single shadow tier and flat white-on-white baseline.
- Pill search bar with circular Rausch search orb.
- Photo-first itinerary cards with floating favorite badges and rating trust display.
- Breakpoints: < 744px (Mobile), 744–1128px (Tablet), 1128–1440px (Desktop), > 1440px (Wide).

### Category 2: Retained Project-Specific Decisions (Not Specified in `DESIGN.md`)
- Retained semantic feedback tokens: Success Emerald 500 (`#10B981`), Warning Amber 500 (`#F59E0B`), Info Blue 500 (`#3B82F6`) for platform alerts and moderation status.
- Admin Web Layout: Dedicated persistent navigation sidebar, data table moderation queue, and split views for content management.
- Reusable Flutter Widget Hierarchy: `lib/shared/widgets/` component library implementing the design tokens.
- Shared Backend Contract: Both Mobile and Web consume identical Spring Boot REST APIs regardless of presentation layout.

### Category 3: Unresolved Decisions Pending Implementation
- **Font Integration:** Adoption of `Inter` or `google_fonts` vs. continuing with `Roboto` / platform defaults requires a separate dependency and asset integration task.
- **Frontend Codebase Theme Migration:** Current Dart files in `frontend/mobile` and `frontend/web` continue to use Teal tokens pending a dedicated frontend refactor task.
- **Dark Mode Policy:** `DESIGN.md` explicitly notes no dark mode exists on public web. Dark mode support for Mobile/Web remains an unconfirmed future roadmap item.
- **Map View Theming:** Detailed map tile tinting and custom map marker tokens require map SDK integration specs before adoption.
