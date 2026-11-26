# Phase 3 — Admin Announcement

**Trạng thái:** Code Phase 3 đã triển khai theo phương án được duyệt ngày 2026-11-26; focused backend suite, Flutter analyze và Web build đã xác minh. Full regression, production rollout và device runtime chưa xác minh.

## 1. Mục tiêu
Cho admin tạo, xem trước, phát hành, hủy và tra cứu lịch sử announcement; lưu nội dung một lần, hiện trong Mobile Notification Center và tùy chọn gửi FCM sau commit.

## 2. Phạm vi
Backend admin/user API, `system_announcements`, `announcement_reads`; màn hình quản trị trong Flutter Web hiện tại; render/read trong Mobile Phase 2; push broadcast nếu Firebase environment được xác nhận.

## 3. Những chức năng sẽ thực hiện
Draft title/body and optional expiry; validation/preview; explicit confirmation; publish/cancel; publish/expiry times; history/filter/pagination; user eligibility/list/read; active unread count. All announcement content belongs to the same `SYSTEM` group; there is no category selection.

## 4. Những chức năng không được thay đổi
Admin audit logs remain immutable audit records; system settings are not announcements; moderation workflows stay in current screens. No copy of announcement content per recipient; no FCM private key in Web app.

## 5. Phân tích trạng thái code hiện tại
Admin Web is Flutter Web, `AdminShell`/`AdminTab` with hash routes. Existing modules: dashboard, posts, reports, users, places, itineraries, media, administrative areas, audit logs, settings, profile. `AdminSettingsController` manages `SystemSetting`; `AdminAuditLogController` is read-only. No announcement screen/API/entity. `AdminTab` has no announcement item.

## 6. Những file/class/component cần đọc
`frontend/web/lib/features/layout/domain/admin_tab.dart`, `admin_shell.dart`, `admin_sidebar.dart`; `features/settings/**`, `features/audit_logs/**`, shared Admin forms/tables/dialogs; backend `AdminSettingsController`, `AdminAuditLogController`, `SecurityConfig`, `SystemSettingServiceImpl`, `AuditLogServiceImpl`; Mobile Center model/repository; production config and Firebase credentials (CHƯA XÁC MINH).

## 7. Những file dự kiến cần tạo/chỉnh sửa
Potential backend announcement entity/repository/service/controller/DTO/tests; Flutter Web announcement feature repository/model/screen and AdminTab/shell/sidebar integration; Mobile Center response rendering. Exact names/routes require design approval. Reuse shared Admin table/toolbar/form/dialog/token/API client and audit logging rather than another Admin shell.

## 8. Database changes
`system_announcements` one row/content; `announcement_reads` composite PK `(announcement_id,user_id)`; fields/index/FK in 10. No per-user Notification rows. Runtime schema/migration policy CHƯA XÁC MINH; no DDL until reviewed.

## 9. Backend implementation
Admin service enforces DRAFT→PUBLISHED→CANCELLED transitions, validates window/time, records created_by/published_at and appends existing audit event. Admin no longer selects a category; user Center API represents all shared content as `SYSTEM`. Bulk audience is query-time, not fanout. Publish transaction persists once.

## 10. Flutter implementation
Mobile reuses Center list/feed contract. Admin Flutter Web adds accessible entry under existing system/admin navigation, draft editor, preview, confirmation, history/status/expiry and validation. UI state follows existing loading/error/empty and design tokens.

## 11. Flutter Web Admin scope
Announcement management is implemented in the existing Flutter Web application and mounted inside `AdminShell`/`AdminTab`. The backend retains ADMIN authorization; provider credentials are not delivered to the browser. No separate Angular application exists or is required for this repository.

## 12. API contract
Admin GET/POST `/api/admin/announcements`, GET/PUT detail, POST publish/cancel; user GET `/api/announcements`, POST `/{id}/read`. Save request contains title/body/expiry only; the response exposes the fixed `SYSTEM` group for existing clients. User DTO excludes internal audit data and returns read state. Authenticated admin and user APIs remain separated.

## 13. Luồng end-to-end
Admin form → preview rendered from unsaved draft → confirmation → admin-only publish request → DB commits one row → after-commit push job/topic attempt → Mobile list queries currently active eligible rows → read endpoint upserts receipt. Push failure does not undo published content/read center.

## 14. Business rules (đã chốt)
Announcement PUBLISHED, chưa hết hạn hiển thị cho mọi tài khoản ACTIVE, bao gồm người dùng đăng ký sau ngày phát hành. DRAFT, CANCELLED và hết hạn không hiển thị, không tính unread. Mở Trung tâm không tự đánh dấu đã đọc; chỉ thao tác mở announcement mới tạo receipt. Nút đọc tất cả chỉ áp dụng notification cá nhân. FCM không phải lịch sử và vẫn bị tắt cho tới khi credential, token registration và kế hoạch Phase 5 được xác minh.

## 15. Validation và error handling
Require nonblank title/body, bounded length, expiry after publish and legal status transitions; reject double publish safely. Conflict returns clear error. No AnnouncementType category enum is used.

## 16. Security và authorization
`@PreAuthorize("hasRole('ADMIN')")` at server controller/service boundary. User cannot draft/publish/read another user's receipt. Escape rendered text; no internal admin notes. Admin audit record separate from announcement; service-account credentials backend secret only.

## 17. Realtime và Push behavior
Center list/count refetch after publish invalidation or on resume. Push topic or bounded token multicast only after an audience/privacy decision; topic does not replace DB or provide read receipt. No synchronous fanout of every user in HTTP request.

## 18. Test plan
Backend status transitions/roles/future users/expiry/cancel/read uniqueness/count/paging, concurrent publish/double submit, audit entry, FCM fake fail. Flutter Web draft/preview/confirm/history/error/loading; Mobile future-account and read behavior; Android/iOS staging push after config.

## 19. Acceptance criteria
One content row regardless of user count; future active user sees unexpired publication (if approved); receipts are unique; unread count excludes expired; admin-only mutation; push failure independent; no secrets in client; tests and role runtime verified.

## 20. Dependencies
Phase 0 stack/audience/schema/FCM decisions; Phase 1 persistence/index/read API; Phase 2 merged Center feed and badge. Optional FCM token infrastructure from Phase 5 can be parallelized after its security contract.

## 21. Risks and mitigation
Announcement feed merged with personal notification pages needs stable composite cursor. Audience grows dynamically; query plan must be measured. Topic membership and new-device lifecycle must be validated. Existing audit is not an announcement history replacement.

## 22. Completion checklist
- [x] Reuse Admin shell and existing audit mechanism; no duplicate portal.
- [x] Database and API decision approved; additive schema written for manual rollout.
- [x] CRUD, publish lifecycle, user display/read, expiry/future-user and role permissions covered by focused tests.
- [ ] Push staging and failure behavior recorded; FCM remains disabled and unverified.

## Implementation update — 2026-11-26

- Added `SystemAnnouncement` and `AnnouncementRead` JPA models and repositories. Content is stored once; per-user state is one composite-key receipt. Schema follows the existing Hibernate configuration; no feature-specific DDL script is kept.
- Added ADMIN-only `/api/admin/announcements` create/list/detail/update/publish/cancel API. Draft transitions are transactional/locked and strict-audited. Published text cannot be edited; only drafts can change, only published rows can be cancelled.
- Approved ACTIVE audience and future-account semantics are enforced at query time. Expired/cancelled/draft rows are excluded from feed/unread. Read endpoint insert-if-absent is called only on opening an announcement.
- Mobile composite feed, source-aware cursor, three-part unread summary and announcement detail route are wired. No FCM delivery is attempted.
- Flutter Web admin entry reuses `AdminShell`, with draft form, validation/preview, confirmation dialogs, filtering and paging.
- Focused backend tests covered draft→publish→cancel with audit trail, non-admin denial, receipt transaction/idempotency, future users and expiry/cancel filtering on `travel_planner_test`; manual DDL validation was removed with the scripts. Mobile notification tests passed 10/10; Web `flutter analyze` and `flutter build web --no-pub` passed. Full regression, UI browser interaction, production schema provisioning and Android/iOS runtime remain unverified.

## Corrective architecture update — 2026-11-26

- Removed notification-specific SQL DDL files and tests that executed those scripts. Entity/Repository mappings now rely solely on existing Hibernate schema behavior; production provisioning remains an operational concern and was not executed.
- Admin announcements remain a screen inside the existing Flutter Web `AdminShell`; no separate Angular application was introduced.
