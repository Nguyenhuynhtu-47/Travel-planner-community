# Phase 2 — Flutter Mobile Notification Center

**Trạng thái:** Feed đã tích hợp Phase 3 announcement và quyết định parent-route. Còn kiểm thử tích hợp, deep-link producer verification và xác minh đầy đủ trước khi đóng phase.

## 1. Mục tiêu
Đưa notification feed đã persist lên Flutter Mobile, hiển thị chính xác badge riêng, paging/read/deep-link/realtime invalidation và các trạng thái lỗi/lifecycle.

## 2. Phạm vi
`features/notifications` placeholder → data/model/repository/state/UI; app navigation/bell owner; authorized route handling; announcement/personal item merge theo API contract.

## 3. Những chức năng sẽ thực hiện
Load initial page, load more, refresh, read one, read all, unread count, `99+`, type-specific rendering, target routing, safe unavailable state, foreground/resume/refetch and socket invalidation.

## 4. Những chức năng không được thay đổi
Messaging unread total, request/friend badges, five-tab shell semantics, existing destinations/domain authorization, open Center must not mark all read. FCM tap handling comes in Phase 5 and reuses resolver.

## 5. Phân tích trạng thái code hiện tại
`NotificationsScreen` is fixed `AppEmptyState`; feature directory has no data/state files. Project uses feature-first Flutter and shared `ApiClient`, theme, empty state/page-title widgets. Exact bell host and route owner must be re-traced at implementation. Notification badge API absent.

## 6. Những file/class/component cần đọc
`notifications_screen.dart`, main/app navigation shell and bell widget (exact source not yet named), `ApiClient`, auth notifier/token refresh/logout, `MessagingRepository`/`PageResult` conventions, post/comment/itinerary/activity destinations, profile public routes, shared avatar/time/empty/error widgets, Design System and UX guidelines.

## 7. Những file dự kiến cần tạo/chỉnh sửa
Create notification model, repository, notifier/provider and list/item components under `frontend/mobile/lib/features/notifications/**`; update screen, verified navigation host and tests under corresponding `test/features/notifications/**`. Exact bell-owner file is CHƯA XÁC MINH and must not be guessed. Don't create a parallel router/provider if existing owner suffices.

## 8. Database changes
None. Backend Phase 1 provides personal records; Phase 3 provides shared announcement + read state. Read is persisted by API, not local-only.

## 9. Backend implementation
Consume approved Phase 1/3 contracts. Backend supplies authenticated page, count, read operations; event changes are invalidation only. API must return unread count without client fetching all pages.

## 10. Flutter implementation
Use existing feature structure and `ApiClient`; implement typed DTO parsing, bounded cursor, dedup by notification ID/source pair, cancellation/stale response guard, states: loading/empty/error/retry/content/loading-more. Badge refresh on auth, app resume, route return and invalidation; clear user-scoped cache at logout/account switch. Use existing design tokens; do not hardcode visual scheme.

## 11. Flutter Web Admin scope
N/A. Admin is Flutter Web per source; this Phase is Flutter Mobile only. Do not add Angular or Firebase SDK here unless Phase 5 approved.

## 12. API contract
Use APIs from 13: list cursor/size; unread count; mark read; mark all read. Request never sends user ID. Response includes actor summary and allowlisted target descriptor, read timestamp. Target loading may need existing post/comment/itinerary/activity GET APIs, exact routes verify against current ApiClient/controller before implementation.

## 13. Luồng end-to-end
App gets token → loads unread count and first page → user taps item → mark-read request for own ID → resolve target route → destination API revalidates; if deleted/hidden/forbidden show safe unavailable message. Realtime invalidation/resume refetches authoritative count; no local increment. Read all calls explicit action only.

## 14. Business rules
Center badge includes personal social/moderation plus active unread announcements only. Excludes messages, requests and friendship badges. Opening list is not read. Single tap marks only tapped item. Pending page entries remain until server marks read.

## 15. Validation và error handling
Handle invalid JSON/unknown future type with generic item; missing target, 401, 403, 404, timeout, offline, pagination cursor expiry, duplicate tap and rapid route change. Retry preserves current state; optimistic read must rollback or reconcile count on failure.

## 16. Security và authorization
Never trust local target IDs; backend destination auth rechecks. Cache keyed by user/session; clear on logout/switch. No display of message push as Center item. Avoid logging personal notification body.

## 17. Realtime và Push behavior
WebSocket event only invalidates/refetches; one subscription owner with dispose/reconnect behavior. Foreground FCM in Phase 5 uses same notification navigation service; Center data remains REST. No duplicate notification due WS plus FCM.

## 18. Test plan
Model/repository tests, cursor pagination, widget states, 99+, read-one/all semantics, unknown type, route matrix, inaccessible target, resume/reconnect, logout/account switch cache clearing, duplicate invalidation and no coupling to chat badges.

## 19. Acceptance criteria
User sees only own items; Center opens without marking all; one tap reads one; count matches API and caps 99+; paging has no duplicate; routes resolve or fail safely; unread updates cross-device after refetch; analyzer/tests pass.

## 20. Dependencies
Phase 1 for personal API; Phase 3 for announcement feed/read merge. Phase 5 push navigation must reuse the same resolver, not duplicate.

## 21. Risks and mitigation
Unspecified bell host/routes: re-audit before edit. Combined feed cursor can skip same-time rows; use type + timestamp + ID. Existing API client token expiry may clear route; restore safe state. Realtime simple broker may be process-local; REST resume is fallback.

## 22. Completion checklist
- [x] Personal API/model contract verified against backend Phase 1.
- [x] Personal feed states, unread badge, cursor paging and mark/read tests pass.
- [x] Center badge uses the personal notification count endpoint only; messaging/request counters are not combined.
- [ ] Supported destination and inaccessible-target route matrix tests pass.
- [ ] Mobile runtime check across resume, logout and two-device read sync recorded.

## Implementation update — 2026-11-26

### Đã triển khai

- Thay `NotificationsScreen` empty-state cố định bằng personal feed có tải ban đầu, pull-to-refresh, cursor load-more, deduplicate theo notification ID, loading/empty/error/retry, đọc một và đọc tất cả.
- Thêm DTO parser và repository gọi đúng `GET /api/notifications`, `/unread-count`, `POST /{id}/read`, `/read-all`; client không gửi recipient ID.
- Thêm `NotificationUnreadCountNotifier.shared`: các bell trên nhiều tab cùng dùng authoritative count, coalesce request đang chạy, cache ngắn 30 giây, clear khi logout/chuyển account. Badge `99+` không gộp chat hay friend-request counters.
- Initial integration replaced the icons in several screens, but corrective architecture review removed those duplicate entry points. Final state: only Home/Explore uses `NotificationBellButton`; it reloads on resume or `SyncDomain.notifications` invalidation.
- Đã nối target USER, POST và ITINERARY vào các destination hiện có. Unknown/missing target hiện thông báo an toàn; không mở route tự tạo.
- Không thay đổi backend/schema ở Phase 2.

### Chưa hoàn tất / phụ thuộc

- Feed hiện chỉ có personal notification. Chưa merge system announcement vì API, audience, expiry và read receipt chưa được chốt/triển khai ở Phase 3.
- Target ACTIVITY cần itinerary/day context; COMMENT cần loại comment/domain và parent/context; REPORT cần safe result target. Notification core hiện chỉ có `targetType/targetId`, nên chưa đủ dữ liệu để xác định chính xác các destination này. Không suy diễn bằng ID.
- Chưa chạy kiểm thử runtime trên Android thật/emulator hoặc xác minh cross-device; không đánh dấu checklist đó xong.
- Dependency note: Phase 3 phụ thuộc Center cơ bản của Phase 2; hoàn thiện announcement merge là follow-up của Phase 2 ngay sau khi Phase 3 contract/schema/API sẵn sàng. Không chuyển sang producer phases trước khi Center aggregate/route contract được hoàn tất.

### Files đã thêm/chỉnh

- Added: `frontend/mobile/lib/features/notifications/data/models/notification_item.dart`, `data/notification_repository.dart`, `presentation/notification_unread_count_notifier.dart`, `presentation/widgets/notification_bell_button.dart`.
- `NotificationsScreen` is integrated with the Home/Explore bell only. Duplicate bell entry points in Profile, Community Feed, Messaging Community, Collection, My Itineraries and Saved Itineraries were removed during corrective refactoring.
- Added tests: `test/features/notifications/notification_repository_test.dart`, `notification_unread_count_notifier_test.dart`, `notifications_screen_test.dart`.

### Kiểm thử

- `flutter test test/features/notifications`: 9 tests passed.
- Historical pre-correction run: 3 bell-entry tests passed while shortcuts were mounted in several tabs; those duplicate-entry tests were replaced by a one-entry-point assertion in the corrective pass.
- `flutter analyze lib/features/notifications`: passed.
- Full `flutter analyze`: chỉ còn 2 info deprecated có sẵn tại `features/social/presentation/widgets/report_post_dialog.dart`; không thuộc files Phase 2.
- Full `flutter test --reporter failures-only`: 613 passed, 29 failed in existing itinerary/profile/community and other non-notification tests; đây không phải kết quả full suite xanh.
- Chưa kiểm thử runtime Android/iOS trên thiết bị.

## Cập nhật sau khi Phase 3 contract được duyệt — 2026-11-26

- Đã nối feed composite `/api/notifications`: notification cá nhân và announcement đang PUBLISHED/chưa hết hạn; cursor có timestamp, ID và source (`N`/`A`) để phân biệt ID trùng nguồn.
- `NotificationItem` có `announcement` và stable key theo nguồn; read announcement gọi `/api/announcements/{id}/read`. `/unread-count` cung cấp tổng, personal và announcement count; nút đọc tất cả chỉ tác động phần personal.
- Đã chốt route producer: activity/activity-comment ánh xạ parent itinerary; post-comment/itinerary-comment ánh xạ parent POST/ITINERARY tương ứng. REPORT thiếu route an toàn thì hiện trạng thái không hỗ trợ; không suy luận target từ ID đơn.
- Đã thêm trang chi tiết announcement tối giản và hỗ trợ `targetType=ANNOUNCEMENT`.
- Test sau cập nhật: `flutter test test/features/notifications` 10/10 passed; `flutter analyze lib/features/notifications` passed. Android/iOS runtime và hai thiết bị vẫn chưa kiểm tra.

## Corrective navigation verification — 2026-11-26

- `flutter test test/bottom_navigation_test.dart --plain-name "Notification"`: 5 passed, including Home/Explore bell navigation and a single-entry-point assertion.
- Full `bottom_navigation_test.dart`: 9 passed and 2 failed because existing expectations look for `Cộng đồng du lịch`, which the current Community screen does not render. No notification assertion failed.
