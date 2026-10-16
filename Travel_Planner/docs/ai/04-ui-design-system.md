
# UI Design System

## 1. Design Direction
Style: Clean Travel Planner.

The interface should feel:
- Clean and modern.
- Practical and content-focused.
- Easy to scan and navigate.
- Suitable for a travel community.
- Consistent across mobile and web.

Use travel applications as inspiration for usability,
not as a reason to copy their exact layouts or assets.

## 2. Color System
Use the established design tokens in `lib/core/theme/` across both Mobile and Web:

| Token Name | Hex Value | Purpose |
|---|---|---|
| `primary` | `#0D9488` (Teal 600) | Main brand color, active navigation, primary action buttons |
| `primaryLight` | `#2DD4BF` (Teal 400) | Subtle indicators, hover states |
| `primaryDark` | `#115E59` (Teal 800) | Active pressed states, dark headers |
| `accent` | `#F97316` (Orange 500) | Badges, rating stars, highlighting key travel actions |
| `background` | `#F8FAFC` (Slate 50) | General app screen background |
| `surface` | `#FFFFFF` | Card backgrounds, dialogs, bottom sheets, navigation bars |
| `textPrimary` | `#0F172A` (Slate 900) | Headlines, primary body text, titles |
| `textSecondary` | `#64748B` (Slate 500) | Captions, timestamps, author notes, helper labels |
| `border` | `#E2E8F0` (Slate 200) | Card outlines, input borders, divider lines |
| `success` | `#10B981` (Emerald 500)| Completed trips, positive alerts, verified status |
| `warning` | `#F59E0B` (Amber 500)  | Moderation alerts, draft itineraries, attention notices |
| `error` | `#EF4444` (Red 500)    | Error banners, destructive confirmations, field validation failures |
| `info` | `#3B82F6` (Blue 500)   | Informational tips, system announcements, guide notes |

Usage Rules:
- Primary (`#0D9488`) is used for primary brand elements, active tabs, main CTAs, and key interactive highlights.
- Accent (`#F97316`) must be used sparingly. Reserve it strictly for rating stars, unread badges, and high-priority travel highlights. Do NOT overuse accent colors for ordinary cards, buttons, or backgrounds.
- Ensure WCAG AA compliance (minimum 4.5:1 contrast ratio) between text and background across all surfaces.

## 3. Typography
Use clear, highly legible typography with consistent hierarchy:
- Preferred font family: Inter or Roboto (fall back to platform system default).
- Scale:
  - `headlineLarge`: 28sp / bold (w700) — Major screen headers.
  - `headlineMedium`: 22sp / semi-bold (w600) — Section headings, trip titles.
  - `titleMedium`: 16sp / semi-bold (w600) — Sub-headers, card titles, modal titles.
  - `bodyMedium`: 14sp / regular (w400) — Standard content, itinerary descriptions.
  - `bodySmall`: 12sp / regular (w400) — Metadata, date/time chips, review count.
  - `labelLarge`: 14sp / semi-bold (w600) — Button labels, interactive tabs.

Maintain readable line height (minimum 1.4 for body text) and avoid mixing more than two font weights within the same card.

## 4. Spacing and Layout
- Base unit: **4px grid**.
- Standard spacing scale:
  - `xs`: 4px
  - `sm`: 8px
  - `md`: 12px
  - `lg`: 16px (standard component padding and screen margin for mobile)
  - `xl`: 24px (section gaps, web screen margin)
  - `2xl`: 32px (major layout blocks)
  - `3xl`: 48px (page tops, empty state vertical breathing room)
- Corner radius: `8px` for inputs and small cards; `12px` for dialogs and large preview cards.
- Elevation: Restrained (`1-2dp` for cards, `4dp` for dialogs/floating controls; avoid heavy drop shadows).

## 5. Components
Reuse shared components located in `lib/shared/widgets/`:
- Form inputs, buttons (`ElevatedButton`, `OutlinedButton`, `TextButton`).
- Standard AppBars and SearchBars.
- Loading indicator (`AppLoadingIndicator`).
- Empty state display (`AppEmptyState`).
- Error state display with retry (`AppErrorState`).
- Destination and itinerary summary cards.

## 6. Cards and Decoration
- Clean Travel Planner aesthetic: light backgrounds, clear visual hierarchy, content-first presentation.
- Use cards only when grouping distinct related content. Do not wrap every single text element in a card.
- Avoid excessive shadows, gradient overlays, or decorative borders.
- Keep corner rounding moderate (8-12px); avoid fully circular or excessively rounded shapes for containers.
- Prioritize real itinerary information and destination photos over decorative illustrations and excessive icons.

## 7. Mobile UI
- Screen width constraint: `< 600px`.
- Prioritize a clear vertical reading flow.
- Navigation: Standard bottom navigation bar (`NavigationBar`) for primary tabs; top AppBar with back arrow for details.
- Primary actions placed within thumb reach (bottom navigation, sticky bottom action bar for "Lưu chuyến đi" or "Sao chép lịch trình").
- Form fields: Full width, stacked vertically with clear spacing.
- Data lists: Vertical scrolling cards; avoid multi-column data tables on small screens (use stacked summary cards instead).
- Touch targets: Ensure minimum touch target size of 48x48dp.
- Avoid horizontal overflow; truncate or wrap text gracefully.

## 8. Web UI
- Responsive Breakpoints (these are standard guideline tokens and may be adjusted in a controlled manner if framework demands):
  - Compact / Mobile view: `< 600px`
  - Medium / Tablet view: `600px - 1024px`
  - Expanded / Desktop view: `> 1024px`
- Navigation:
  - Desktop: Persistent left-side navigation rail or sidebar drawer.
  - Tablet/Mobile: Collapsible drawer or top app bar.
- Layout and Data Display:
  - Use desktop screen width efficiently with multi-column layouts.
  - Data tables (admin user list, moderation queue): Full-width table with pagination bar at the bottom. For compact widths, provide horizontal scroll or convert to card view.
  - Map exploration: Place the interactive map beside the itinerary list when width > 1024px (split view).
  - Form max-width: Constrain text forms to a maximum container width of `640px` to prevent uncomfortable scanning on wide displays.

## 9. Travel Planner Screens
Apply consistent design principles to:
- Explore itineraries.
- Search, filter and sort.
- Itinerary details.
- Create and edit itineraries.
- Day, destination and activity management.
- User profiles.
- Saved and reused itineraries.
- Ratings and comments.
- Notifications.
- Admin dashboard and moderation.

## 10. Design Tokens and Shared Theme
Centralize:
- Colors.
- Typography.
- Spacing.
- Corner radii.
- Elevation and borders.
- Component dimensions where appropriate.

Flutter widgets must use the project's shared theme
and reusable components rather than duplicating style values.

## 11. UI Consistency
Before creating a new screen:
1. Inspect similar existing screens.
2. Reuse the established layout and components.
3. Follow shared typography and spacing.
4. Handle different screen widths.
5. Verify empty, loading and error states.

Do not redesign unrelated screens while implementing a feature.
