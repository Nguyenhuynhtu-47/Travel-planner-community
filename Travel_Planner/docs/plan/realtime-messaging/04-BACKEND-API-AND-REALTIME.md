# 04 — Backend API và realtime

## 1. Chọn kiến trúc

Dùng Spring WebSocket + STOMP qua cùng Spring MVC backend, phù hợp REST/JWT và Java layering hiện tại. Bắt đầu với in-memory simple broker cho single-instance demo; broker relay/message broker chỉ khi cần nhiều backend instance hoặc broker durability/ack. Không polling làm realtime chính.

Tách đường gửi khỏi realtime: gửi text qua REST POST để tái sử dụng ApiClient, response/error/idempotency hiện có. REST service persist message rồi phát domain event. WebSocket/STOMP chỉ đẩy event đã commit đến user queue. Điều này tránh client tự phát message event giả và làm REST history trở thành recovery path.

Spring Framework docs xác nhận STOMP over WebSocket dùng spring-messaging + spring-websocket và @EnableWebSocketMessageBroker; Spring Security hỗ trợ authorization theo message qua inbound channel. Spring mặc định dùng HTTP authenticated Principal và không tự xử lý Bearer header ở STOMP CONNECT, nên JWT CONNECT cần interceptor riêng. Nguồn: [Spring Boot WebSocket](https://docs.spring.io/spring-boot/reference/messaging/websockets.html), [Spring STOMP setup](https://docs.spring.io/spring-framework/reference/web/websocket/stomp/enable.html), [token authentication](https://docs.spring.io/spring-framework/reference/web/websocket/stomp/authentication-token-based.html), [message authorization](https://docs.spring.io/spring-framework/reference/web/websocket/stomp/authorization.html).

## 2. REST API proposal

Tất cả writes cần JWT + ACTIVE user; pagination validate/cap size; các query cá nhân lấy actor từ principal. Response/error theo PageResponse, DTO và ErrorResponse hiện có.

| Method | Path | Body / response | Quyền và nghiệp vụ |
|---|---|---|---|
| POST | /api/conversations/direct | recipientUserId → conversation summary | Tạo hoặc trả conversation cũ; policy/block/friendship kiểm tra |
| GET | /api/conversations?page=&size= | page conversation summary | Chỉ hội thoại của actor; sắp xếp last activity desc |
| GET | /api/conversations/{id}/messages?beforeSequence=&size= | page messages | Member only; keyset pagination |
| POST | /api/conversations/{id}/messages | clientMessageId, content (tối đa 4.000 ký tự) → saved MessageResponse | sender từ principal; unique idempotency |
| POST | /api/conversations/{id}/read | lastReadSequence → read state | member only; cursor monotonic, message belongs to chat |
| GET | /api/users/me/messaging-settings | settings | authenticated self |
| PUT | /api/users/me/messaging-settings | inboundPolicy → settings | authenticated self |
| POST | /api/users/{id}/friend-requests | empty | send request; no self/duplicate/accepted/blocked |
| GET | /api/users/me/friend-requests?direction=received or sent&page=&size= | paginated request summaries | authenticated self |
| POST | /api/friend-requests/{id}/accept | empty | addressed receiver only; atomic PENDING→ACCEPTED |
| POST | /api/friend-requests/{id}/decline | empty | receiver only |
| DELETE | /api/friend-requests/{id} | empty | requester cancels pending request |
| GET | /api/users/me/friends?page=&size= | public-safe user summary page | accepted + active users, excludes blocked |
| DELETE | /api/users/me/friends/{userId} | empty | unfriend both sides |
| POST | /api/users/{id}/block | empty | block; revoke chat/friend ability |
| DELETE | /api/users/{id}/block | empty | unblock; no friendship auto-restored |
| GET | /api/users/me/blocks?page=&size= | page public-safe summaries | owner only |

Expected statuses: conversation create 200 existing / 201 new (settle one contract); messages and friend request create 201; read/settings 200; accept/decline/unfriend/block actions 204 or 200 consistently. Validation 400; unauthenticated 401; authenticated policy violation 403 generic; missing/non-member private resource 404 to avoid IDOR enumeration; duplicate idempotent request returns existing state or 409 only where transition conflicts; rate limit 429.

PublicProfileResponse may add contextual fields such as friendshipState, canMessage, canSendFriendRequest for the current viewer, with guest-safe false/UNKNOWN. Never return the owner’s raw privacy setting, email, phone, address, or block target. Existing Follow fields/routes remain backward compatible.

## 3. STOMP/WebSocket contract

- Endpoint proposal: /ws (wss in production), exact allowed origins from CORS config; no wildcard with credentials.
- STOMP CONNECT includes Authorization: Bearer JWT in STOMP headers, never URL. ChannelInterceptor validates through JwtTokenProvider, loads active UserDetails, and sets authenticated Principal. Reject missing, expired, invalid or disabled/banned users.
- Client subscribes only /user/queue/chat-events. Server uses convertAndSendToUser to the authenticated user destination. No client-subscribable /topic/conversation/{id}.
- Deny all client STOMP MESSAGE destinations for MVP; message writes go through REST. Deny arbitrary /queue/**, /topic/**, user-ID-in-path subscriptions. Authorize CONNECT/SUBSCRIBE/UNSUBSCRIBE/DISCONNECT narrowly.
- Heartbeats negotiated/configured with scheduler; caps for message size, sessions/user, connection attempts, idle timeout, inbound queue, and send rate. Use TLS/WSS outside localhost.

### Event envelope

eventId, type, occurredAt, conversationId and payload. MESSAGE_CREATED payload includes persisted messageId, sequenceNumber, clientMessageId, sender safe summary, content, createdAt; recipients are precisely conversation’s two members. CONVERSATION_UPDATED can carry conversation summary; READ_CURSOR_UPDATED carries actor and cursor only to the other member as the basic read receipt. Avoid broadcasting email/private profile fields. REST list remains authoritative for unread count.

## 4. Persist-then-publish and recovery

Within transaction: authorize, validate content, lock conversation row, allocate the next sequence_number, insert message and update conversation latest metadata atomically, then commit. Serialize sends for the same conversation; use sequence_number (not auto-increment message_id or timestamp) for ordering and cursors. Publish event in @TransactionalEventListener(AFTER_COMMIT) (or transaction synchronization) so rollback never leaks an event. This ensures event is after durable commit, but has a small crash window between DB commit and publish; history sync repairs it. If production needs guaranteed broker publication across crashes/instances, add transactional outbox in a separately approved phase.

On app connect/resume: authenticate socket, load conversation list and unread state via REST, then paginate messages from last known cursor; use messageId/clientMessageId to dedupe events that raced sync and sequenceNumber to order them. Fetch each conversation delta after its last known sequence. STOMP is not durable and does not retain events for offline clients. Spring transaction-bound event source: [Transaction-bound Events](https://docs.spring.io/spring-framework/reference/data-access/transaction/event.html).

## 5. Authorization rules and errors

- Never accept senderId as authority from body; ignore/reject if present.
- Check conversationId membership on GET history, POST message, read update, event publication and any future subscription.
- Re-evaluate both users’ ACTIVE status, block in either direction, friendship and receiver setting per new send.
- Never trust client to specify target user on publish; server derives pair from conversation.
- Generic 403 reason avoids revealing whether blocked or privacy set to NOBODY. Profile may safely return contextual canMessage.
- Apply rate limit per authenticated user and recipient/conversation; current Bucket4j use is location/IP oriented, so new chat key design must be user ID, not copied blindly.
- Do not log body, bearer token or raw STOMP CONNECT headers. Event ID/message ID makes duplicate delivery harmless.

## 6. Dependencies and alternatives

Current backend lacks websocket starter; Mobile lacks STOMP package. Add only after owner approves this plan and a compatibility spike against Boot 4.1.1/Flutter 3.13.5.

Candidate client: stomp_dart_client (Pub currently documents Mobile/Web platforms, CONNECT headers, heartbeat and reconnect options). Browser custom HTTP WebSocket headers are unsupported; STOMP CONNECT headers are the documented route. Treat candidate as a spike, pin compatible version, test Android/iOS/Web if scope changes; do not install in Phase 1. [Package documentation](https://pub.dev/packages/stomp_dart_client).

Alternatives: raw WebSocket has less protocol overhead but requires custom reconnect/framing/dispatch/auth conventions; SSE is server→client only and still needs REST sends, but native browser auth/reconnect semantics differ from Flutter mobile; polling is simpler but violates desired immediacy/load requirement. STOMP selected for structured broker destinations, heartbeat, user queues and Spring integration.

Push is separate: FCM/APNs/Web Push are needed for OS notifications when app is backgrounded/terminated; socket does not guarantee that. Official Flutter FCM docs distinguish foreground/background/terminated handling and platform setup: [Receive messages in Flutter apps](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages). Defer push.
