# Phase 0 — Codebase Audit và Architecture Design

**Status:** source audit for this plan is complete; runtime MySQL, production Firebase and deployment configuration are **CHƯA XÁC MINH**. Plan only.

## 1. Mục tiêu
Lập baseline có bằng chứng trước khi implementation, khóa các quyết định ảnh hưởng schema, API, admin platform, push privacy và retry.

## 2. Phạm vi
Backend, Mobile, Web Admin hiện có, entity/JPA schema source, tài liệu CODEBASE_GUIDE/db_info, messaging plan/decision records, coding/UI rules, auth và môi trường. DB runtime và Firebase Console không truy cập được trong audit này.

## 3. Những chức năng sẽ thực hiện
Khi Phase 0 được duyệt: chốt glossary/event contract; actor/recipient matrix; hiện trạng vs proposal; target DB/migration/rollback; Firebase app credentials; API pagination/read/deep-link; Angular-vs-Flutter Web scope; D1–D3 coalescing/privacy; retention/retry.

## 4. Những chức năng không được thay đổi
Không sửa Friendship, Follow, Messaging, Comment, moderation hoặc Admin workflows; không tạo DDL, dependency, Firebase config hay code; không thay D-25.

## 5. Phân tích trạng thái code hiện tại
- Backend modules theo `config/controller/dto/event/exception/mapper/model/repository/security/service`; Spring Data JPA, JWT security, service transaction. `SecurityConfig`, `JwtAuthenticationFilter`, `CustomUserDetails` cần re-read khi implementation.
- Auth principal trong controller lấy `@AuthenticationPrincipal UserDetails`; admin controllers dùng `@PreAuthorize("hasRole('ADMIN')")`. Service giải quyết username→user và domain authorization.
- Paging dùng project `PageResponse` hoặc Spring `Page`; bounded size tùy endpoint. Notification APIs chưa tồn tại.
- Chat dùng `MessagingServiceImpl` → `CommittedChatEvent` → `ChatEventListener @TransactionalEventListener(AFTER_COMMIT)` → STOMP `/queue` simple broker. Không tìm thấy durable broker/notification event bus chung.
- Mobile: feature-first, repository qua `ApiClient`, state notifier convention (re-audit exact provider at implementation). `NotificationsScreen` empty state; chat unread/request counts tách biệt.
- Web Admin source là Flutter (`frontend/web`), shell route theo `AdminTab` hash paths, không phải Angular. Không có `angular.json`/Angular workspace manifest được tìm thấy.
- Android có `frontend/mobile/android/app/google-services.json` trong working tree; package trong file khớp `applicationId` của `frontend/mobile/android/app/build.gradle.kts`. Chưa thấy Google Services Gradle plugin reference trong các Gradle files đã kiểm tra và không có `firebase_messaging` trong Mobile manifest hoặc Firebase Admin SDK trong backend POM/source. Android project file đã có nhưng chưa chứng minh FCM được khởi tạo. iOS/APNs/service account/Console ownership/runtime delivery **CHƯA XÁC MINH**. Không in giá trị API key từ config ra log.
- JPA entities là căn cứ schema source; DB runtime DDL, production migration process và exact MySQL version **CHƯA XÁC MINH**.

## 6. Những file/class/component cần đọc
Backend: `security/SecurityConfig.java`, `security/JwtAuthenticationFilter.java`, `controller/ConversationController.java`, `service/impl/MessagingServiceImpl.java`, `service/ChatEventListener.java`, `config/ChatWebSocketConfig.java`, `config/ChatWebSocketSessionRegistry.java`, `FriendshipServiceImpl`, `PublicUserServiceImpl`, `PostServiceImpl`, `CommentServiceImpl`, `AdminCommunityController`, `AdminUserController`, `AdminUserTransactionalWorker`, `AdminItineraryController`, `AdminPlaceController`, `AdminSettingsController`, `AdminAuditLogController`.
Mobile: `features/notifications/presentation/screens/notifications_screen.dart`, `features/messaging/data/messaging_repository.dart`, auth/session owner, shell/navigation containing bell, social/comments/itinerary destinations.
Web: `features/layout/domain/admin_tab.dart`, `features/layout/presentation/screens/admin_shell.dart`, sidebar, user/itinerary/location/moderation/audit/settings/dashboard repositories/screens.
Docs: root README, DESIGN, CODEBASE_GUIDE and db_info, docs/ai coding/design/API/auth docs, realtime-messaging plan and implementation report, admin feature plans and development log.

## 7. Những file dự kiến cần tạo/chỉnh sửa
Phase 0 không sửa file dự án. Output được ghi trong planner này và các quyết định ở 10–14. Source file list implementation phải revalidate vì đây mới là kế hoạch.

## 8. Database changes
Không có trong Phase 0. Source hiện có `User`, `Friendship`, `Follow`, `Post`, `PostLike`, `PostComment`, `Comment`, `Itinerary`, `Activity`, `PostReport`, `Conversation`, `Message`, `ConversationReadState`, `AuditLog`, `SystemSetting`; không có notification/announcement/token entity. Runtime schema **CHƯA XÁC MINH**. Đề xuất additive schema chỉ xem ở 10, chưa phê duyệt.

## 9. Backend implementation
Không implement. Audit transaction boundaries, exception mapping, principal scope, source transitions, event idempotency, `@Async`/transaction listeners và exact admin API workflows. Đã tìm thấy email verification/password reset after-commit listeners; không mặc định có generic async queue.

## 10. Flutter implementation
Không implement. Trace auth token lifetime, app shell lifecycle, bell/badge location, route restore/deep links, Provider/Notifier ownership, shared empty/loading/error widgets, notification destination access.

## 11. Flutter Web Admin scope
N/A theo source hiện tại: repo Web là Flutter Web, `AdminTab`/`AdminShell`/Dart repositories; Angular project **không tìm thấy**. Người dùng cần quyết định tái dùng Flutter Web hay cung cấp Angular workspace riêng. Không tạo Angular files trong plan mặc định.

## 12. API contract
Không phát hành contract. Đề xuất authenticated user API: list/cursor, unread count, read-one, read-all; admin announcement CRUD/publish; user announcement listing/read; token register/remove. Các candidate paths ở 13, chưa phải endpoints hiện hữu.

## 13. Luồng end-to-end
Business transaction xác định transition và recipient → (Center events) persist atomically → post-commit push adapter best-effort/retry decision → Mobile refetches Center or opens an authorized target. Message transaction persists only existing Message/Conversation → eligible FCM dispatch; no Center insert.

## 14. Business rules
D-25 is current messaging source of truth: accepted conversation continues after unfriend/privacy change; block/inactive blocks; FRIENDS_ONLY sender-only messages invisible to recipient; pending stranger requests/accept/decline and one-day retry retained. No self notifications; replies notify parent writer only; messages never become Center items.

## 15. Validation và error handling
Chốt event payload allowlists, target existence/visibility, request transition dedup, body bounds, pagination caps, invalid token handling, post-commit exception isolation, retry SLO and stale-target behavior.

## 16. Security và authorization
Principal-bound list/read; server-side ADMIN role; no client-supplied recipient; target authorization rechecked on click; no internal moderation notes/private message content in push; token secret handling; account block/deactivation cleanup.

## 17. Realtime và Push behavior
REST/db authoritative; websocket invalidates/refetches. Current socket registry is user/session-only, not exact conversation presence. FCM is delivery hint, never read evidence. Confirm foreground suppression strategy and single/multi-instance limitations.

## 18. Test plan
Audit tests are source inspections, not runtime claims. Later: service transition tests, MySQL integration, API principal tests, mobile/widget & Web tests, FCM fake/staging, D-25 regression, two-device check.

## 19. Acceptance criteria
Every present-state statement references a source/document; unknown runtime state labeled CHƯA XÁC MINH; all events have recipient and skip rules; Admin inventory complete; decisions blocking schema/API are explicitly approved; no code/schema change.

## 20. Dependencies
No prior phase. Phase 1–7 depend on review of this audit, schema/DDL strategy, admin stack, FCM project/security and event semantics.

## 21. Risks and mitigation
Docs may be stale; re-check source before every phase. Runtime MySQL and Firebase Console/APNs/service-account are not verified; Android config file exists but plugin/SDK integration is incomplete or unverified. Confirm environment before deployment. Angular mismatch; do not invent app. Post-commit delivery has loss window; choose best-effort vs durable delivery explicitly. Admin warning/report semantics need domain owner review.

## 22. Completion checklist
- [x] Source audit of core messaging/social/moderation modules and Flutter Web admin inventory.
- [x] Marked absent modules/features and unknown runtime facts.
- [ ] User confirms Admin Web stack, Firebase environment and open decisions in 10/12.
- [ ] No code, schema, dependency or config changed in this phase.
