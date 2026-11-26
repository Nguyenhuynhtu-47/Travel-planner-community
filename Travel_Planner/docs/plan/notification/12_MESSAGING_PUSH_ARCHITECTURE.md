# Thiết kế riêng Messaging Push

**Ràng buộc không thay đổi:** Tin nhắn và request đã có persistence trong Messaging. FCM chỉ báo tin mới; không tạo `notifications` row, `message_notifications`, message notification history, hay Outbox row cho từng tin. Không dùng Notification Center badge để biểu diễn unread chat.

## Luồng hiện tại đã xác minh

`ConversationController` gọi `MessagingService`; `MessagingServiceImpl.send` transactionally validates pair/account/block/visibility, persists `Message`, updates conversation sequence/read state as applicable, rồi publish `CommittedChatEvent`. `ChatEventListener` nhận AFTER_COMMIT và phát STOMP user events qua Spring simple broker `/queue`. Mobile `MessagingRepository` dùng `/api/conversations`, `/message-requests`, `/unread-total`, per-conversation message API; request là `Conversation.status/requester/requestRecipient`. REST là durable source; STOMP không durable. `ChatWebSocketSessionRegistry` chỉ session count per username; chưa theo dõi conversation SUBSCRIBE hay foreground.

## D1/D2/D3 theo policy source hiện hành D-25

| Loại | Điều kiện server | Push tới ai | Không được làm |
|---|---|---|---|
| D1 | Conversation ACCEPTED; message visible; both active; pair unblocked | Peer recipient | Không phụ thuộc họ còn là friends; không tạo Center row |
| D2 | Nonfriend PENDING hợp lệ theo EVERYONE; message visible trong Stranger Inbox | Request recipient | Không gộp thành accepted; không tính unread Center; không push nếu recipient invisible |
| D3 | Chuyển lần đầu sang pending request / request-created transition | Recipient một lần cho request mới | Không push một “request mới” cho từng tin sau đó; không tạo notification record |
| Hidden sender-only | FRIENDS_ONLY nonfriend message; persisted sender-side only | Không gửi recipient push; sender giữ UX hiện tại | Không lộ người gửi/tin tồn tại tới recipient qua OS notification |
| Declined/blocked/inactive | Declined round invisible, block or inactive enforced | Không gửi recipient push | Không resurrect old hidden messages or bypass block |

Retry sau decline dùng canonical Conversation và cooldown một ngày theo D-25; chỉ event mới eligible theo rule hiện tại có thể được cân nhắc push. Accept là recipient action; mở hoặc reply không implicit-accept. Khi accepted, future eligible messages theo D1. Không sửa read cursor/unread semantics.

## Gộp/collapse options

1. **FCM/APNs collapse** theo conversation: ít state, latest push thay thế/thu gọn ở OS khi được nền tảng hỗ trợ; không đảm bảo số lượng/tất cả actor. Đề xuất MVP.
2. **In-memory debounce** recipient+conversation trong backend: có thể combine count/sender trong khoảng ngắn; restart/instances làm mất state và multi-instance duplicate; không đề xuất trước khi cần.
3. **Durable coalesced bucket** theo recipient+conversation/window: retry/restart tốt hơn, nhưng cần bảng/job and cleanup; chỉ nếu SLA yêu cầu. Không tạo một row cho mỗi message.

MVP payload generic “Bạn có tin nhắn mới” (hoặc “Có yêu cầu tin nhắn mới”), collapse key conversation/request, TTL bounded; app fetches exact unread count and sender via authorized APIs. Nếu UX yêu cầu “4 tin từ A và 2 người khác”, phải thiết kế batch state/window first; không thể khẳng định collapse tự tạo số liệu đúng.

## Suppress khi đang xem đúng conversation

Server hiện không có evidence exact active conversation. Chỉ có session-by-username registry, không dùng để suppress. Lựa chọn:

- Mobile foreground listener giữ `activeConversationId`; nếu bằng conversation push, không hiện local notification, nhưng cập nhật UI bằng REST/WS. Dễ triển khai và exact khi app foreground.
- Server presence/subscription map gắn principal/session/conversation, cập nhật khi SUBSCRIBE/UNSUBSCRIBE/disconnect; volatile single-instance và race; authorize subscription, expire stale session. Dùng như optimization, không phải correctness/security.
- Khi app background/terminated, exact suppression không được bảo đảm nếu backend không có active state reliable; push generic/collapsible là fallback.

Không cần Redis trong single-instance MVP. Nếu scale nhiều backend instances, volatile map không global; cần broker/presence strategy theo evidence và ADR.

## Device token lifecycle và credentials

Authenticated endpoint upsert current FCM token/platform. FCM token refresh upsert; stale/invalid registration marks disabled and removes ownership; account switch rebinds token; logout unregisters or detaches per approved product policy. User may have multiple active tokens. Android `google-services.json` is present in the current working tree and its package matches Gradle `applicationId`; do not overwrite it without checking ownership. No Google Services plugin reference was found in inspected Gradle files. Flutter FCM plugin and backend Admin SDK are not present in manifests/source. iOS APNs/bundle setup and server credentials are CHƯA XÁC MINH. Server credentials must use environment/secret manager, never be committed. Android runtime permission and APNs are prerequisites. Add plugin/dependencies only after Firebase project ownership/config is confirmed.

## Privacy and validation

- Push carries event type, opaque conversation ID only if that recipient is authorized to open, generic localized text, collapse/TTL. Do not include message body, image preview, email, auth token, internal request state.
- On tap app navigates to inbox; API rechecks account, membership, block, conversation status and recipient visibility. Stale push is harmless.
- Event handling revalidates `recipientVisible`, block/account and conversation. Notification delivery failure does not roll back send.
- Do not log token or content; log message/conversation correlation only if safe and bounded.

## Error model and acceptance

FCM transient errors: bounded retry after commit or best effort per Phase 0; invalid tokens deactivate; quota/configuration failures monitored. No guarantee of exactly once or device display. Offline user recovers data through existing conversation REST/unread APIs.

Acceptance must prove D1 accepted after unfriend, D2 allowed request, D3 one initial request push, FRIENDS_ONLY no recipient push, declined/block/inactive suppress, exact foreground conversation suppression, multiple devices/token rotation, no message content leak, fail-after-commit safe, and zero inserts to Notification Center tables for every D event.
