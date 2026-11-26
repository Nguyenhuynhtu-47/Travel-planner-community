# Implementation Planner — Hệ thống Notification Travel Planner

**Trạng thái:** Phase 1–6, các hành động Admin hiện có và Notification Center liên quan đã được triển khai. Phase 7 chưa đạt release gate: full Mobile/Web regression có failure; FCM staging/thiết bị thật và production schema chưa xác minh. Không có API cảnh cáo tài khoản/bài viết trong source nên không tạo giả.
**Audit source:** 2026-11-26. Runtime DB, deployed Firebase và production Web deployment: **CHƯA XÁC MINH**.

## Mục tiêu

Triển khai Notification Center dùng cho social, announcement và moderation; FCM làm delivery channel; tích hợp Mobile và Admin Web hiện có; kiểm thử bằng MySQL, Android/iOS và nhiều tài khoản.

**Hard boundary:** D1/D2/D3 tin nhắn chỉ Push. Không insert bảng `notifications`, không tạo `message_notifications`, không thêm per-message history/Outbox. Existing Message/Conversation, unread/read state, request lifecycle, REST/STOMP tiếp tục là nguồn chuẩn.

## Kết quả audit code hiện tại

### Backend — audit snapshot trước Phase 1

- Cấu trúc Java feature layer: controller/service/repository/model/dto/config/security/event; dùng Spring Boot, JPA/MySQL, JWT và transactions. Controllers lấy principal với `@AuthenticationPrincipal`; admin controllers có `@PreAuthorize("hasRole('ADMIN')")`.
- Modules hiện hữu: users/auth, Friendship/Follow, community Post/Like/PostComment, itinerary/activity `Comment` threads, PostReport/moderation, Admin dashboard/users/itinerary/place/media/settings/audit, Messaging.
- `FriendshipServiceImpl.sendRequest/accept` là nơi có state transition; `PublicUserServiceImpl.follow` insert idempotently; `PostServiceImpl.likePost/unlikePost` insert/delete PostLike và tăng/giảm count; `addComment`/reply methods nằm cùng service; `CommentServiceImpl` tạo root/reply cho itinerary/activity.
- `MessagingServiceImpl.send` persist Message và Conversation state; publish `CommittedChatEvent`; `ChatEventListener` giao STOMP sau commit qua simple broker. `Conversation` lưu request status. Current socket registry chỉ ánh xạ user/session, không chứng minh đang subscribe cuộc hội thoại cụ thể.
- Không thấy Notification/Announcement/FCM token entity/API, Firebase Messaging dependency hoặc backend Firebase Admin integration. Android `google-services.json` hiện có trong working tree và package bên trong khớp Gradle `applicationId`; tuy vậy chưa tìm thấy Google Services Gradle plugin reference trong các Gradle file đã kiểm tra. Đây là cấu hình Firebase Android một phần, không chứng minh app đã khởi tạo FCM. iOS/APNs/backend credentials/runtime delivery **CHƯA XÁC MINH**. Actual schema live không truy vấn được trong audit này.

### Flutter Mobile

- `NotificationsScreen` hiện render fixed empty state. `features/notifications` chưa có repository/model/notifier trong source.
- Có `AppSyncBus` (`core/sync/app_sync_bus.dart`) với `SyncDomain.notifications` và TTL một phút: cache invalidation local, không phải notification persistence/API hoặc remote notification delivery. Tái sử dụng cho local refresh, không coi là backend event.
- Audit source ban đầu thấy shortcut rải ở nhiều màn hình. Sau corrective refactor, chỉ Home/Khám phá giữ NotificationBellButton và điều hướng đến một NotificationsScreen; unread badge dùng một shared notifier. Chat unread badge vẫn riêng trong Community.
- `MessagingRepository` lấy unread total, message requests/unread request riêng. Không gộp vào Center badge.

### Admin Web và database

- Repo thực tế là **Flutter Web**, không Angular: `frontend/web/pubspec.yaml`, Dart `main.dart`, AdminTab/AdminShell. Không thấy Angular workspace manifest. Chi tiết screen/API/backend ở [11_ADMIN_WEB_INTEGRATION_AUDIT.md](11_ADMIN_WEB_INTEGRATION_AUDIT.md).
- Admin có user, post moderation, reports, itineraries, canonical places, administrative areas, media, audit logs, settings, dashboard và profile. Chưa có announcement management. Reuse AdminShell/module, không tạo portal song song.
- Entity source chứng minh hiện trạng mapping; bảng thực tế trên máy/server, migration đã chạy hay chưa, MySQL version và backup/restore: **CHƯA XÁC MINH**. Dùng database inventory/ERD proposal ở 10 làm căn cứ cần đối chiếu trước migration.

## Đề xuất kiến trúc

```text
Business mutation / transition
  ├─ Social, moderation → Center notification row, committed with domain action
  ├─ Admin announcement → one shared content row + per-user read receipt
  └─ Message → existing Message/Conversation only → optional FCM push-only

Mobile Center: authenticated REST page/count/read + AppSyncBus/socket invalidation
Admin authoring: existing Flutter Web AdminShell + authenticated Admin API
Push: backend FCM adapter after commit; no client private key
```

Tách business event, persistent Center record, push dispatch, FCM delivery và user read. REST/database authoritative. Push success không đồng nghĩa đã đọc. Không thêm Kafka/Redis/RabbitMQ theo mặc định. Outbox chỉ sau khi có reliability requirement cụ thể; tuyệt đối không per message.

## Thứ tự phase / phụ thuộc

| Phase | File | Nội dung | Phụ thuộc |
|---|---|---|---|
| 0 | 01 | Audit, source-of-truth, chốt design/schema/platform | — |
| 1 | 02 | Core DB/API/read/count/paging/Like grouping | 0 + DDL approval |
| 2 | 03 | Mobile Center/badge/navigation/realtime invalidation | 1; composite merge after approved Phase 3 contract |
| 3 | 04 | Admin announcement, Flutter Web authoring and read receipts; FCM deferred to Phase 5 | 0,1,2 |
| 4 | 05 | C1–C8 hooks vào business transactions | 1,2 |
| 5 | 06 | D1–D3 token/FCM Push-only | 0 + Firebase configuration; Center records not required |
| 6 | 07 | F1/F2/F4/F5/F6/F7 verified moderation transitions | 1,2 |
| 7 | 08 | Security/performance/runtime/regression release gate | 1–6 |

Detailed graph: [14_IMPLEMENTATION_DEPENDENCY_MAP.md](14_IMPLEMENTATION_DEPENDENCY_MAP.md).

## Database proposal

Các nhóm bảng cần dùng gồm `notifications` cho C/F; `system_announcements` lưu một bản nội dung; `announcement_reads` lưu read marker; `user_device_tokens` lưu FCM registration/FID; `notification_like_actors` giữ membership cần cho C4 unlike, không phải bản sao PostLike. Không thêm bảng message push. Entity/Repository là nguồn mapping; local/test dùng Hibernate `ddl-auto=update`. Notification không bổ sung SQL script hoặc migration framework; production `validate` cần schema được provision qua quy trình quản trị database hiện có.

## Execution status — 2026-11-26

Phase 1 core, Phase 2 personal center, Phase 3 shared announcements/admin/composite feed, Phase 4 C1–C8, Phase 5 Android FCM source and Phase 6 F1/F5/F6 are implemented. C4 follows approved UTC-day/unlike semantics. Before this corrective pass, focused tests passed and source builds succeeded, but full mobile/web regressions were not green and an earlier backend run was stopped after real SMTP delivery was observed. Corrective pass moved social event mapping to `SocialNotificationService`/`SocialNotificationServiceImpl`, removed notification SQL scripts and duplicate bells, and added Surefire safety overrides. Current focused backend run: 91 passed; notification Mobile tests: 10 passed; Home notification navigation tests: 5 passed; scoped Mobile analyze clean; `flutter build apk --debug` passed. The full bottom-navigation test still has two unrelated existing community-title assertions failing. Full backend/mobile/web regressions, FCM device delivery and production schema remain unverified. See [Phase 7](08_PHASE_7_TESTING_AND_HARDENING.md) and the English development log for exact evidence.

### Corrective implementation — Admin action records and notification groups

- Notification Center now uses `SYSTEM` for Admin moderation actions and shared announcements. Messaging remains push-only; social/personal event types stay individual business events.
- Added nullable `notifications.action_type` for specific Admin actions. Existing recipient, actor, target, title/body, event key, timestamps and read state are reused; no table or audit subsystem was added.
- Added `GET /api/admin/notification-actions` as a read-only, paginated, ADMIN-only query over those same action rows; no separate history table was introduced.
- Account suspend/restore, role change, successful session revocation, post hide/remove/restore/purge, and report resolve/dismiss now create a recipient-scoped system notification in the same JPA transaction as the existing Admin mutation. Duplicate/no-op report transitions are rejected under a row lock; other state no-ops do not emit a second notice.
- Removed `AnnouncementType` and A1/A2/A3/A5 selection from request/UI. Announcement API responses expose one `SYSTEM` group. The old non-null `system_announcements.type` schema column is retained as an opaque legacy compatibility field and normalized to `SYSTEM` on writes; old stored values are never used to classify content.
- `MODERATION_UPDATE` remains a deprecated Java enum alias only so existing rows deserialize. It is returned as `SYSTEM` and included by the `SYSTEM` filter. New moderation actions are stored as `SYSTEM` with an action type.
- No account/post warning endpoint exists in the source, so no warning action was fabricated. FCM remains excluded from these transaction-bound records.
- Focused verification on 2026-11-26: backend moderation/notification tests 62 passed (including `travel_planner_test` schema/persistence), Mobile notification tests 10 passed and scoped analyze clean, Flutter Web notification analyze clean. Full suite/device/production schema remain unverified.

Production schema rollout still needs the existing DBA provisioning path: ensure `notifications.type` accepts `SYSTEM`, add nullable `notifications.action_type`, and change legacy `system_announcements.type` from its old enum to `VARCHAR(24)` before deploying code with `ddl-auto=validate`. Inspect live schema and preserve rows; do not reset the database. `ddl-auto=update` performed these changes only in the owner-approved `travel_planner_test` database during verification.

## Tiêu chí hoàn thành

- C/F đúng recipient, transition, self-suppression, idempotency; comment/reply hướng đúng parent writer.
- Announcement một row, pagination/read/unread đúng, user tương lai/expiry policy rõ.
- D1–D3 FCM only, no database record/badge; D-25 privacy và current websocket/unread logic giữ nguyên.
- API principal-scoped; Admin role server enforced; target reauthorized on open; no private message/admin notes in push.
- MySQL integration, backend/mobile/web tests, Flutter analyze/build, FCM multi-device staging và docs/log có kết quả xác thực; không claim runtime nếu thiếu môi trường.

## Quyết định còn chờ

1. MySQL production schema/provisioning and backup/restore strategy remain unverified; Notification relies on JPA/Hibernate locally and adds no SQL rollout framework.
2. Announcement audience future users, expiry, cancellation and read semantics were approved and implemented.
3. C4 Like grouping is decided and implemented; UTC-day actor membership semantics are documented in section 10.
4. Push remains best-effort after commit; D1/D2 use generic collapsed payloads per conversation; no durable retry or exact background presence suppression.
5. Android Firebase project ownership is confirmed by user for `travel-planner-54f53`; Android plugin/client code is added. Backend ADC credentials, FCM API enablement and physical-device delivery remain unverified. iOS/APNs stays out of this Android-first phase; logout unregister/account transfer is implemented.
6. Whether explicit warning F2/F4 and reporter feedback F7 exist in product rules.

Review unresolved product/environment gates before dependent phases; do not infer product decisions from the implementation proposal.
