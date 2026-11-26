# Phase 5 — Messaging Push-only (D1–D3)

**Trạng thái:** Android-first source implementation and focused verification complete; Firebase delivery/runtime acceptance remains pending. Owner confirmed Firebase project `travel-planner-54f53`; Android config/plugin, FID lifecycle, authenticated token API, backend FCM adapter and push policy are implemented. Delivery remains disabled by default until backend ADC credentials/project settings and `user_device_tokens` is provisioned through the existing database process. No Notification Center row for message.

## 1. Mục tiêu
Gửi FCM đến thiết bị thích hợp sau message commit mà không thay REST/WS, unread, privacy, request lifecycle hay database message source.

## 2. Phạm vi
Token registration/lifecycle, backend FCM adapter, after-commit event integration, Mobile permission/foreground/background/tap handling, batching/collapse and D1–D3 regression.

## 3. Những chức năng sẽ thực hiện
D1 accepted conversation; D2 eligible visible stranger request messages; D3 one notification for new request transition; multiple devices; invalid token cleanup; exact foreground suppression where reliable; generic private-safe payload.

## 4. Những chức năng không được thay đổi
No `notifications` row, no `message_notifications`, no push history per message or outbox row per message. Do not replace STOMP, alter unread/read cursor, implicitly accept requests, change cooldown, reveal sender-only messages or add message badge to Center.

## 5. Phân tích trạng thái code hiện tại
`MessagingServiceImpl.send` persists `Message` and conversation sequence, publishes `CommittedChatEvent`; `ChatEventListener` is AFTER_COMMIT; simple broker STOMP `/queue`. `ChatWebSocketSessionRegistry` tracks username/session only, not subscriptions/current conversation. `Conversation` contains request status, requester/recipient, created/declined timestamps. D-25 rules are current. Audit 2026-11-26: the user confirmed Android project ownership as `travel-planner-54f53`; `google-services.json` package matches `com.example.mobile`. Android plugin/client, FID lifecycle, backend Firebase Admin adapter and token API/schema are now added. Backend ADC credentials, FCM API enablement, additive schema rollout and physical-device delivery remain unverified. iOS/APNs remains out of Android-first scope.

## 6. Những file/class/component cần đọc
`MessagingServiceImpl`, `CommittedChatEvent`, `ChatEventListener`, `ChatWebSocketConfig`, `ChatStompAuthInterceptor`, `ChatWebSocketSessionRegistry`, `Conversation`, `Message`, `ConversationReadState`, Messaging API/repository, privacy service/tests, Android Gradle applicationId/manifest, iOS Runner config, app lifecycle and auth logout/account switch.

## 7. Những file dự kiến cần tạo/chỉnh sửa
Added backend FCM provider/config/token entity-repository-controller-service and after-commit event policy; mobile dependency/plugin, background handler, permission/token registration, logout unregister and notification tap-to-inbox. Existing Android `google-services.json` was left unchanged. iOS/APNs is deferred.

## 8. Database changes
`user_device_tokens` is mapped by JPA Entity/Repository. Local/test use existing `ddl-auto=update`; production uses `validate` and requires schema provisioning through the existing operational database process. No feature-specific SQL or migration framework is introduced. The mobile SDK registers Firebase Installation IDs (FID), stored with a SHA-256 uniqueness hash; FID is only used for sending and is never returned/logged. Messaging entities unchanged. No message notification/outbox-history table.

## 9. Backend implementation
Send only after transaction commit and revalidate recipient visibility/status/block. D1 when conversation accepted (even if friendship later removed per D-25). D2 for visible pending request under EVERYONE. Pending-message pushes use a generic request title and Android conversation collapse key. FRIENDS_ONLY sender-only messages, declined-round messages, blocked/inactive recipients get no recipient push. FCM errors do not rollback committed message.

## 10. Flutter implementation
Request runtime permission at appropriate UX point; obtain token, authenticated upsert, listen refresh, handle token/account changes; foreground chooses in-app/no local alert when same conversation active; background/tap routes to Inbox then fetches authorized REST. No data model copied into Center.

## 11. Flutter Web admin implementation
N/A for push delivery; admin UI does not send FCM directly. Flutter Web may author announcements in Phase 3. Never ship service account credentials in browser.

## 12. API contract
Candidate authenticated token upsert `PUT /api/users/me/devices/fcm-token` and unregister `DELETE /api/users/me/devices/fcm-token` with token/platform in body; final route/ownership and response in 13. Message send API remains current `/api/conversations/{id}/messages`; no notification API call by client per message.

## 13. Luồng end-to-end
Mobile authenticated session registers token → existing send validates and commits → after-commit push policy filters event → FCM delivers generic data/collapse key to active recipient tokens → client suppresses foreground same-thread notification or displays system/local notification → tap fetches current authorized conversation. WS continues independently.

## 14. Business rules
See 12 D-25 matrix. D1 means accepted conversation, not necessarily friends. D2 means pending stranger inbox-visible message; D3 first request. Friends-only hidden sender message remains sender-only permanently even if later befriended. Decline cooldown is one day. Block wins. Read state is not derived from Push.

## 15. Validation và error handling
Validate authenticated token ownership/platform/length; token refresh/upsert; deactivate invalid registration; bounded retries only as approved. Handle permission denied, missing config, rate/quota failure, duplicate event, expired token, provider outage and app terminated. No message content in log/payload.

## 16. Security và authorization
FCM credentials from backend secret manager/env, not repository or web/mobile bundle. Token API binds current principal. Payload contains generic event, opaque conversation ID and collapse metadata only. API revalidates user membership, block, status and recipient visibility when opened.

## 17. Realtime và Push behavior
Do not replace WebSocket. FCM is hint; REST remains source. Current backend cannot prove exact conversation viewing. Reliable foreground mobile suppression is feasible; server suppression requires authenticated session subscription tracking and remains process-local unless distributed presence is chosen. Collapse key reduces duplicate display but does not calculate exact count.

## 18. Test plan
D1 after unfriend accepted, D2 EVERYONE pending, D3 once, FRIENDS_ONLY hidden, declined/retry, block/inactive; token multi-device/switch/logout/invalid; foreground same/different thread, background/terminated, no content leak, FCM error; query asserts no Center insert and badges unchanged.

## 19. Acceptance criteria
Only visible authorized messages trigger recipient push; no push persistence per message; no Center row/badge changes; two devices receive eligible pushes; opening uses current backend data; WS/unread semantics pass regression; Android/iOS staging evidence recorded.

## 20. Dependencies
Owner confirmed Android Firebase project; backend ADC credentials, FCM API enablement and additive schema rollout remain operational prerequisites. iOS/APNs is deferred. Reuse existing Messaging inbox route on push tap.

## 21. Risks and mitigation
No exact server presence today; don't claim suppression guarantee outside foreground. Process crash loses best-effort send; choose durable coalescing only if SLA requires. Topic/collapse behavior differs OS; test physical devices. Missing/unverified Firebase Console ownership, Gradle plugin/SDK integration, iOS/APNs setup or server credentials block runtime acceptance, not fake-sender unit tests.

## 22. Completion checklist
- [x] D-25 policy matrix preserved in the after-commit policy: pending invisible/block/inactive requests are excluded; accepted conversations remain eligible regardless of friendship state.
- [x] Android configured from owner-confirmed Firebase project; iOS/APNs remains deferred.
- [x] Authenticated token ownership, SHA-256 deduplication, account reassignment/logout unregister, invalid FID deactivation implemented; focused tests added.
- [x] Push payload is generic and excludes message body; D3 first message of pending request is distinguished, Android messages collapse by conversation.
- [x] `user_device_tokens` JPA table is materialized in isolated test database through current `ddl-auto=update`; production DDL remains manual and unapplied.
- [x] Focused backend regression: 67 tests passed; Flutter messaging suite: 45 tests passed; scoped analyze and Android debug APK build passed (2026-11-26).
- [ ] Backend ADC credentials and FCM HTTP v1 enabled for `travel-planner-54f53`.
- [ ] Two-device D1–D3 tests pass; direct integration assertion confirms no Center row for any message.
