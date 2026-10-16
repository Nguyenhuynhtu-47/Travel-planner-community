
# UX Guidelines

## 1. Core Principles
- Make common tasks easy to discover.
- Keep navigation predictable.
- Provide clear feedback after user actions.
- Prevent avoidable mistakes.
- Preserve user input when practical.
- Avoid unnecessary steps and repeated confirmations.

## 2. Navigation
- Keep navigation consistent within each platform.
- Make the current screen and active section clear.
- Provide a predictable way to return to the previous screen.
- Avoid unexpected navigation after saving or editing.
- Prevent accidental loss of unsaved changes.

## 3. Loading States
- Page-level loading: Centered spinner (`CircularProgressIndicator` in primary color) with an optional descriptive message (e.g., "Đang tải dữ liệu chuyến đi...").
- Component-level loading: Show a localized spinner or subtle inline indicator inside the specific card or section being refreshed, avoiding blocking the entire screen.
- Button-level loading: Disable the button immediately and replace or accompany text with an embedded spinner (18x18dp) to strictly prevent double-click or multiple simultaneous submissions during network dispatch.
- Content loading: For feed/list screens (explore itineraries, comments), prefer simple skeleton cards to minimize visual jumping.
- Always cancel or dispose async requests and subscriptions if the user navigates away before completion.

## 4. Empty States
Every list or content container must handle empty collections gracefully.
Structure of an `AppEmptyState`:
1. Title: Semi-bold 16sp, concise summary (e.g., "Chưa có lịch trình đã lưu"). Required.
2. Description: 14sp muted text explaining what to do (e.g., "Khám phá các chuyến đi cộng đồng và nhấn Lưu để xem lại tại đây"). Required.
3. Action: A clear Call-to-Action button (e.g., "Khám phá ngay", "Tạo chuyến đi mới", "Đặt lại bộ lọc"). Required where an actionable next step exists.
4. Icon: Visual helper (48x48dp with `textSecondary` / muted color). Optional; do not force icons everywhere if space is constrained or unnecessary.

Examples:
- No saved itineraries: Provide button to explore public itineraries.
- No search results: Explain that no matches were found and provide button to reset filters.
- No activities for a day: Show card with an "Thêm hoạt động" button.

## 5. Error States
- Never show raw technical exceptions, database stack traces, SQL syntax, or internal error objects to users.
- Display categorized messages:
  - Network / Connectivity: "Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng." + [Thử lại] button.
  - Validation / 400: Highlight invalid fields inline with clear explanations.
  - Authentication / 401: "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
  - Permission / 403: "Bạn không có quyền truy cập hoặc chỉnh sửa nội dung này."
  - Not Found / 404: "Lịch trình không tồn tại hoặc đã bị xóa."
  - Server / 500: "Hệ thống gặp sự cố tạm thời. Vui lòng thử lại sau."
- Safe Retry Rule:
  - For **read-only / idempotent queries** (GET requests), provide a prominent "Thử lại" (Retry) action.
  - For **write / mutating operations** (POST, PUT, DELETE such as creating an itinerary or submitting a review), **never perform automatic retries** that risk creating duplicate records. Require user confirmation or manual re-submission.
- Form submission error: Preserve all user-entered inputs and highlight the invalid fields with specific inline validation messages.
- Transient error feedback: Use `SnackBar` with semantic error color for non-blocking failures (e.g., failed to bookmark).

## 6. Forms and Validation
- Mark required fields clearly.
- Validate input before submission when possible.
- Enforce business validation on the backend.
- Place useful validation messages near relevant fields.
- Avoid clearing valid input after an error.
- Confirm before discarding substantial unsaved work.

## 7. Itinerary Creation and Editing
- Organize itinerary editing into understandable sections.
- Make days, destinations and activities easy to distinguish.
- Keep the relationship between activities and their days clear.
- Provide visible controls to add, edit, remove and reorder items.
- Preserve the user's changes when practical.
- Validate required information before saving.
- Confirm destructive operations when appropriate.

## 8. Saving and Reusing Itineraries
- Clearly distinguish saving a reference from copying an itinerary.
- Explain when reuse creates a separate editable copy.
- Preserve the original itinerary when a user edits a copy.
- Give feedback when saving or copying succeeds or fails.
- Follow the documented rules for attribution and ownership.

## 9. Ratings and Comments
- Explain why an action is unavailable when relevant.
- Prevent duplicate or invalid submissions according to business rules.
- Show the updated result after successful submission.
- Apply moderation and eligibility rules from the backend.

## 10. Destructive Actions
- Ask for confirmation when an action is difficult to undo.
- Identify the item that will be affected.
- Explain the consequence when it is not obvious.
- Do not show unnecessary confirmation dialogs for harmless actions.

## 11. Authentication and Permissions
- Redirect unauthenticated users according to the route policy.
- Preserve the intended destination when appropriate.
- Explain access-denied states clearly.
- Do not rely on hidden buttons as the only authorization check.
- Respect public and private profile settings.

## 12. Accessibility and Responsive Behavior
- Maintain readable text and sufficient contrast.
- Provide labels for form fields and meaningful controls.
- Support keyboard navigation on web where practical.
- Avoid relying on color alone to communicate status.
- Prevent clipped content and horizontal overflow.

## 13. Feedback Consistency
Define consistent patterns for:
- Success messages.
- Validation messages.
- Network failures.
- Permission errors.
- Confirmation dialogs.
- Retry actions.

Reuse existing shared components and patterns.
