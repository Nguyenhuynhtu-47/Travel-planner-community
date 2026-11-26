# Phase 7 — Testing, Security, Performance và Hardening

**Trạng thái:** Đang kiểm thử/hardening; chưa đạt tiêu chí release. Kết quả thực chạy 2026-11-26 ghi ở mục 23.

## 1. Mục tiêu
Chứng minh hợp đồng end-to-end trên backend, MySQL, Mobile, Flutter Web Admin, FCM và Messaging; đóng lỗ hổng bảo mật, đồng thời ghi rõ môi trường chưa thể kiểm chứng.

## 2. Phạm vi
Regression và deployment readiness của Phase 1–6; test data, metrics/logging, query plan, failure/retry, multi-device, privacy and rollback.

## 3. Những chức năng sẽ thực hiện
Unit/integration/API/UI tests, MySQL migration rehearsal, FCM staging, WebSocket + Push interplay, user/admin authorization, data retention, performance and operational checklist.

## 4. Những chức năng không được thay đổi
Không mở rộng scope sang broker/microservices; không refactor unrelated flows; không tuyên bố push delivery exactly-once; không thay D-25 hoặc tách unread hệ thống.

## 5. Phân tích trạng thái code hiện tại
Current code lacks Notification/FCM; Messaging WS is simple broker with REST source. Existing backend/mobile/web test suites exist, but pass status for future changes is unknown. Runtime MySQL/Firebase credentials/device coverage CHƯA XÁC MINH.

## 6. Những file/class/component cần đọc
Every changed test; Spring profiles/security/exception config; DB DDL/migration; mobile route/app lifecycle and FCM handlers; Web Admin auth/navigation; D-25 messaging privacy tests; deployment env templates and secret docs.

## 7. Những file dự kiến cần tạo/chỉnh sửa
Tests under existing `backend/src/test/java`, `frontend/mobile/test`, `frontend/web/test`; test fixtures/fake FCM provider and documented staging checklist. Exact files derive from implementation diff; no test file is named as existing unless verified.

## 8. Database changes
Validate schema diff, FK/index/unique, backfill (if any), rollback and backup restore on disposable MySQL same major/version. Measure explain plans for recipient page/unread, announcement anti-join, token lookup and Like actor aggregation. No production destructive DDL.

## 9. Backend implementation
Fix only defects introduced or blocking approved feature. Add metrics for provider outcomes/retries without secrets; bounded timeouts; retry classification; idempotency; transaction boundaries; admin audit trails. Keep dispatch after commit.

## 10. Flutter implementation
Run analyze/test/build for Mobile and Web. Test permission denied, foreground/background/terminated, route cold-start, token refresh/account switch, Center pagination/read badge, state restore and high text scale.

## 11. Flutter Web Admin scope
N/A until Angular app exists/approved. Flutter Web test suite is the current Admin verification target.

## 12. API contract
Contract tests for pagination cursor stability, max page size, ownership, read idempotency, announcement active window, token endpoint auth, admin-only publish and compatibility with existing routes. No D API creates notification row.

## 13. Luồng end-to-end
Build verified DB → login two accounts → generate each C/F/A event → inspect recipient Center/count/deep link → send D events while online/offline/foreground/background → query database to prove push-only rule → admin publish/failure/expiry → compare multi-device read state → restart backend and inspect documented delivery loss/retry.

## 14. Business rules
Matrix in 09 is test oracle; D-25 current. Exact test assertions include no self event, only parent author on reply, single announcement content, hidden message never pushes, Center badge independent, open Center not mark-all.

## 15. Validation và error handling
Exercise 400/401/403/404/409/5xx/network, malformed payload, rate limits/provider quota, expired credentials, invalid tokens, timeout, backend restart, duplicate publish/read/like, partial multicast errors. User-facing errors should be actionable and not expose internals.

## 16. Security và authorization
Cross-user IDOR tests; admin RBAC; recipient spoof; hidden/deleted/private target; block pair; token secrecy; no message text/APNs preview leak; admin notes excluded; locked user; log scrub. Run dependency/config secret scan as existing workflow permits.

## 17. Realtime và Push behavior
Test WS invalidation and REST reconcile when event lost; push delivery and OS display independently; same conversation foreground suppression; multiple devices; reconnect; collapse; FCM never marks read. Document single-instance presence limitation.

## 18. Test plan
Matrix in 09 plus concurrent Like/publish/read; DB volume paging; Dart analyze/tests/build; Maven unit/integration; authenticated HTTP/STOMP; staging physical Android+iOS (if available). Record exact commands, environment, versions, actual result and unavailable gates.

## 19. Acceptance criteria
No regression; P0/P1 bugs resolved; query/page and unread count bounded; privacy/security matrix passes; two devices validated; secret/config check passes; rollback and support instructions reviewed. Missing device/Firebase env is an explicit incomplete gate, not pass.

## 20. Dependencies
All previous phases implemented and individually tested; staging Firebase, disposable MySQL and two test accounts/device(s). Production rollout waits for user approval and backup/rollback evidence.

## 21. Risks and mitigation
FCM OS behavior differs; use physical devices. DB schema source vs runtime drift; inspect exact target. Broker local-only; REST reconcile. Large announcement audience; asynchronous topic/batched delivery. Test isolation/flaky integration; run repeat only on failures, retain reproducible evidence.

## 22. Completion checklist
- [x] Backend focused Notification/C4/FCM/Phase 6 tests and MySQL integration results recorded.
- [x] Focused Mobile notification/messaging tests, scoped analyze, Android debug build, and scoped Flutter Web notification analyze recorded.
- [ ] Full backend suite completed. The attempted run was interrupted after the existing email-change test reported successful SMTP dispatch to a masked test address; disable/mock external mail before rerunning.
- [ ] Full Mobile and Flutter Web regression suites are green. Current full-suite failures are listed below and unresolved.
- [ ] FCM foreground/background/two-device staging done or explicitly pending.
- [ ] D1–D3 database assertion proves zero notification record.
- [ ] Documentation, operational/rollback notes and development log updated.

## 23. Kiểm thử thực tế — 2026-11-26

- Backend focused: `mvnw.cmd '-Dtest=DeviceTokenServiceImplTest,MessagingPushPolicyTest,NotificationDatabaseIntegrationTest,NotificationServiceImplTest,SocialNotificationServiceImplTest,CommunityPostServiceTest,AdminUserModerationNotificationTest' test` — the previous 67-test result predates the corrective refactor; rerun before accepting.
- Backend full `mvnw.cmd test`: **không có kết quả hoàn tất**. Đã dừng khi log cho biết test đổi email hiện hữu báo SMTP gửi thành công tới địa chỉ test đã mask; phải cô lập/mô phỏng mail trước khi chạy lại toàn bộ suite.
- Mobile notification: `flutter test test/features/notifications` — 10 passed. Messaging: `flutter test test/features/messaging` — 45 passed, gồm foreground `PUSH_HINT` refresh.
- `flutter analyze lib/main.dart lib/features/messaging` và analyze scoped notification trên Mobile/Web — không issue. Analyze toàn Mobile dừng với hai deprecation infos trong `report_post_dialog.dart`; analyze toàn Web dừng với unused `isOnline` trong `admin_header.dart`.
- Android `flutter build apk --debug` — thành công. `adb devices` không liệt kê thiết bị nên không thể làm kiểm tra thiết bị thật.
- Full Mobile: 616 passed, 29 failed; failure xuất hiện ở một số assertion navigation/profile/itinerary/social UI và overflow `PostCardWidget`, ngoài notification-specific suite. Đây không phải pass toàn suite; cần triage riêng.
- Full Flutter Web: 133 passed, 19 failed; failure tập trung ở assertion Admin/Places/dashboard theo text không được render; test bản đồ cũng nhận HTTP 400 từ CARTO tile server. Đây không phải pass toàn suite.
- Flutter Web notification module analyze: không issue. `flutter build web --no-pub` — thành công.
- Chưa có kiểm thử FCM gửi/nhận thật, background/terminated, hai thiết bị, D1–D3 end-to-end, production DDL, backup/rollback hoặc deployed Web.

## Corrective architecture pass — 2026-11-26

- `SocialNotificationPublisher` was replaced with the project-standard `SocialNotificationService`/`SocialNotificationServiceImpl` pair; domain services now depend on its interface. Removed the nullable `NotificationLikeActorRepository` constructor fallback from `NotificationServiceImpl`.
- Deleted the four notification-specific MySQL DDL files and removed integration tests that executed those scripts. JPA/Hibernate remains the sole Notification schema source. No development/production DB was altered; test integration remains scoped to the owner-approved `travel_planner_test`.
- Surefire now sets `app.mail.enabled=false` and `app.firebase.messaging.enabled=false` as JVM system properties so environment/.env developer toggles cannot activate external delivery in Maven tests. The selected email-change integration test logged simulation mode, not SMTP dispatch.
- Removed duplicate bell entry points from Profile, Community, Community Feed, Collection, My Itineraries and Saved Itineraries. The existing Home/Explore bell and Notification Center remain; chat/friend-request badge stays separate.
- Backend corrective focused run (includes NotificationDatabaseIntegrationTest, NotificationServiceImplTest, SocialNotificationServiceImplTest, device/push policy, moderation, friendship/privacy, comment, post and email-change integration tests): 91 passed, 0 failed/errors.
- Mobile `flutter analyze` on notification, bell host, affected screens and navigation test: no issues. `flutter test test/features/notifications`: 10 passed. `flutter test test/bottom_navigation_test.dart --plain-name "Notification"`: 5 passed.
- `flutter build apk --debug`: succeeded after the bell/navigation correction. Android runtime and push delivery remain unverified.
- Flutter Web `flutter analyze lib/features/notifications`: no issues; `flutter build web --no-pub`: succeeded. A broader scoped analyze including `features/layout` reports the existing unused local `isOnline` in `admin_header.dart:30`, which is outside Notification scope.
- The complete `bottom_navigation_test.dart` run remains 2 failures (expected `Cộng đồng du lịch` absent) and 9 passing; these assertions concern pre-existing Community screen content and are outside this notification correction. No full mobile/web/backend regression or physical-device FCM claim is made.
- Vì full suite chưa xanh và staging chưa có thiết bị/ADC, Phase 7 vẫn mở; không được đánh dấu notification system hoàn tất/release-ready.
