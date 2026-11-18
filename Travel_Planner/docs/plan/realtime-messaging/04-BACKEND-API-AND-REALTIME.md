# 04 — Backend API và realtime

**Cập nhật:** 2026-11-18. Contract dưới đây đã được đối chiếu với source sau implementation; MySQL/API runtime chưa xác minh.

Messaging settings mặc định `EVERYONE` cho tài khoản mới/chưa có row; lựa chọn đã lưu không bị thay đổi (D-22).

## 1. Hiện trạng contract

| Nhóm | Luồng hiện có | Trách nhiệm |
|---|---|---|
| Conversations | `/api/conversations`, open/create direct, list, unread-total | JWT principal là danh tính; service áp dụng policy khi mở mới |
| Messages | paged messages before/after sequence; send; mark read | REST ghi bền vững, sequence/idempotency; read cursor đơn điệu |
| Friendship | send/list received+sent/accept/decline/cancel/friends/unfriend | PENDING/ACCEPTED/REJECTED; quyền kiểm tra server-side |
| Messaging settings | GET/PUT `/api/users/me/messaging-settings` | EVERYONE/FRIENDS_ONLY/NOBODY; default EVERYONE for missing/new settings; saved choices unchanged |
| WebSocket | handshake `/ws`; STOMP SUBSCRIBE `/user/queue/chat-events` | CONNECT bearer JWT; client không gửi message qua STOMP SEND |

Payloads/paths phải được đối chiếu với controller/DTO tại implementation; bảng trên không thay thế OpenAPI contract.

## 2. Message request API đã được thêm vào source

Giữ convention controller/service/repository, DTO validation, `GlobalExceptionHandler` và response/error shape hiện có. Chốt path thực tế trong code review trước khi triển khai.

- Conversation summary: bổ sung `status`, `canRespondToMessageRequest`, `requestAvailableAt`; legacy null = ACCEPTED.
- Stranger requests: `GET /api/conversations/message-requests` phân trang, `GET /api/conversations/message-requests/count`, `POST /api/conversations/{conversationId}/accept` và `/decline`. Participant/recipient được xác thực từ principal và conversation.
- Friend request count: Flutter lấy `totalElements` từ `GET /api/users/me/friend-requests?direction=received`; chỉ tính incoming requests.
- Theo D-25 không có API xóa/ẩn conversation; giữ conversation và lịch sử dùng chung.
- Unread conversations count: nếu UI cần số này, thêm aggregate endpoint/query riêng. Không đổi ý nghĩa `/unread-total`, hiện là unread messages.
- Message-request counts tách pending request tổng khỏi unread message request. Red badge chỉ dùng unread count; không giữ dấu chỉ vì request đã đọc. Chưa thêm unread conversation count riêng.

Mọi list dùng page/cursor server-side, mặc định giới hạn và thứ tự ổn định. POST accept/decline/open/send phải idempotent hoặc có conflict semantics xác định. Dùng status code/error code hiện hữu cho forbidden, not found, conflict, validation.

## 3. Invariants bảo mật

- Lấy actor từ JWT principal; không tin sender/owner ID trong body.
- Conversation phải thuộc actor; message/history/read cursor không rò conversation khác.
- Inbox, Stranger Inbox và unread loại conversation nếu một trong hai thành viên đã block người kia; authorization cũng áp dụng cho direct detail/history/send.
- Chỉ recipient xử lý accept/decline pending request; trạng thái đã kết thúc không được accept lại.
- Kiểm tra ACTIVE account, block hai chiều, trạng thái conversation và friendship/privacy tại server.
- Chặn STOMP destinations ngoài user queue cho phép; không gửi nội dung nhạy cảm vào log.
- REST history vẫn là source of truth nếu event mất, broker restart hoặc app offline.

## 4. Luồng realtime

Hiện tại: transaction lưu message + metadata; sau commit listener phát sự kiện đến sender/recipient. Friend/request changes cũng phát event invalidation sau commit để client refetch REST. Failure sau commit được log nhưng không retry/outbox; simple broker chỉ trong một process. Không hứa delivery bền vững hay cross-instance.

Mở rộng nên giữ payload event tối thiểu (event type, conversation ID, sequence/message ID, timestamp/version). Event về friend request hoặc message request chỉ invalidation badge/list; client refetch REST. Không gửi đồng thời event đếm badge tuyệt đối và tự increment local state nếu không có version/dedup.

`MESSAGE_REQUEST_ACCEPTED` invalidation phát sau commit tới cả hai bên; accept và read-cursor của recipient commit cùng transaction. Không mark-read khi pending. Block được kiểm lại trong event listener trước khi giao event; block pair không nhận chat events. Tin recipient-invisible chỉ phát tới sender.

Connection lifecycle: một owner rõ ràng (application/session-level shared client hoặc provider scoped được dispose). UI subscribe state stream và lấy snapshot current state để không lỡ event trước listener. Reconnect phải resubscribe; token refresh/expiry đóng socket cũ và nối với JWT mới; logout/account switch phải hủy timer, subscription, socket, cache và state user cũ.

## 5. Quan sát lỗi hai thiết bị

Checklist manual: xác nhận hai client truy cập cùng backend `/api/health`; ghi host không chứa secrets; kiểm tra HTTP status; server log CONNECT accepted/rejected (reason code, account/session correlation), SUBSCRIBE success, session cap, disconnect; client log state transitions and reconnect attempts. Không in JWT. Khi gửi tin, xác minh REST 2xx + message ID/sequence, sau đó event recipient; nếu không có event, REST refresh phải khôi phục message. Thử phone Wi-Fi/LAN IP và emulator `10.0.2.2` riêng nhưng cùng process/backend.

## 6. Hiệu năng và vận hành

Tránh N+1 bằng projection/batch loading; counts lấy aggregate SQL; giới hạn page size; indexes xác nhận theo query plan thực trên MySQL. Simple broker đơn instance là giới hạn đã biết; chỉ đề xuất broker ngoài process/outbox khi yêu cầu scale/reliability và vận hành được chốt.

## Addendum — User discovery API và search revisions
`GET /api/users/search?q=&page=&size=` đã có trong source, principal-bound tại service và trả public fullName/handle/avatar/relationship actions. Revision 2 không tạo API user search thứ hai; mở rộng matching cho prefix normalized/tiếng Việt và response relationship flags theo §9 của plan 12.

API cần phân biệt additive `canStartConversation` với `canContinueConversation` (accepted canonical conversation còn tồn tại, cả hai ACTIVE, không block). Giữ `canMessage` như alias nếu cần backward compatibility. Search result phải nạp conversation/friend/block/settings context theo batch, không N+1. `openDirect` và `send` tiếp tục revalidate quyền ở service; không dùng client flag làm authorization.

`MessagingSettingsController` GET/PUT `/api/users/me/messaging-settings` và `UserMessagingSettings` đã tồn tại. Không thêm privacy API/table. `ConversationRepository` có thể bổ sung bulk accepted-pair query; search user và inbox conversation search vẫn là API/queries có mục đích khác nhau. Inbox filter hiện tại client-side trên conversation page tải về; nếu bổ sung server-side conversation filter, chỉ truy vấn participant's conversations, không tìm toàn users/message history.

Không đổi nghĩa `/api/conversations/unread-total`; các count pending/unread vẫn tách. Search field/index là migration tùy query-plan evidence, xem plan 03/12.

## Addendum — Privacy/block, stranger flow và timestamp (2026-11-17)
Audit Plan 12 §10: privacy setting, block persistence/API, canonical pending conversation, accept-to-same-thread và backend enforcement đã có; không thêm DB/API. `ChatEventListener` hiện broadcast sau commit theo username mà không kiểm tra block state lúc giao event. Kế hoạch sửa event envelope/listener để recheck `user_blocks` trước khi gửi message event, tránh event queued trước block nhưng deliver sau khi block commit; vẫn giữ REST history. Kiểm tra friendship request/open/send đã dùng `existsBetween`/service rules.

`MessageResponse.createdAt`, `ChatEventResponse.occurredAt` và `readAt` lấy từ backend `LocalDateTime`; database không đổi. Flutter parse cần phân biệt timestamp offset với LocalDateTime không offset. Không tự thêm zone/convert hai lần; formatter dùng duy nhất timezone Asia/Ho_Chi_Minh. Search API hiện chỉ prefix; accent-insensitive/substring phụ thuộc collation và query plan, nên chưa thay query hoặc schema trong implementation này nếu chưa chứng minh an toàn.

## Addendum — Chat avatar và căn chỉnh tin nhắn (plan-only, 2026-11-17)

### Audit source
`ChatScreen` (`frontend/mobile/lib/features/messaging/presentation/screens/chat_screen.dart`) hiện render từng message trong `ListView.builder`. Tin nhận có `_messageAvatar(message)` bên trái; tin gửi chỉ `Align.centerRight` với bubble nên avatar tài khoản hiện tại không được render dù helper có fallback đến `AuthNotifier.currentUser['avatar']`. Avatar helper ưu tiên `message.senderAvatar`; nếu thiếu và sender là peer thì hiện placeholder, chưa fallback đến `conversation.peer.avatar`. Mỗi bubble có margin dọc riêng; chưa gom tin liên tiếp. `ChatMessage` (`data/models/chat_message.dart`) đã có `senderUserId`, `senderAvatar`, `createdAt`, content, sequence và optimistic flags. Backend `MessageResponse` trả `senderUserId`, `senderAvatar`, `senderName`, `createdAt`; cùng mapper `MessagingServiceImpl.messageResponse` được REST page và event sau gửi sử dụng, vì vậy avatar theo sender có thể dùng chung cho REST/WebSocket. Tin optimistic hiện tạo senderUserId của mình nhưng không gán senderAvatar.

### Hành vi mục tiêu và hợp đồng dữ liệu
Giữ `senderUserId == currentUserId` là căn cứ duy nhất phân biệt phía gửi/nhận. Tin của mình luôn lấy avatar từ hồ sơ hiện tại (fallback khi optimistic message chưa có senderAvatar); tin peer ưu tiên avatar theo message response, sau đó dùng `ConversationSummary.peer.avatar` khi response thiếu. Không bao giờ dùng avatar peer cho own message. URL rỗng/lỗi/tải ảnh phải trả về cùng placeholder mặc định hình tròn; ảnh cover/crop, không co kéo và không làm thay đổi kích thước layout. REST và STOMP event phải cùng kết quả xác định sender/avatar.

Không cần đổi API/DB cho v1: backend đã trả avatar sender trong `MessageResponse`; xác minh API contract và giữ mapper nhất quán. Nếu runtime chứng minh một transport thiếu `senderAvatar`, sửa serializer/service tương ứng trong phạm vi implementation, không lưu bản sao avatar vào bảng message.
