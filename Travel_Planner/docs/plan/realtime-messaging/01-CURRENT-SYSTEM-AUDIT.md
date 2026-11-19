# 01 — Audit hiện trạng realtime messaging và friendship

**Cập nhật:** 2026-11-17. Audit source/config/docs tại nhánh `develop`; không chạy app, test, hoặc kết nối database.

## 1. Kết luận điều hành

Source đã có MVP chat 1-1, REST lưu/gửi/lịch sử, STOMP notification sau commit, friendship, block và messaging privacy. Báo cáo triển khai Giai đoạn 3 là tài liệu lịch sử ngày 10/11, không phải bằng chứng kiểm thử lại hiện tại. Không thể xác nhận schema đang tồn tại trong MySQL thật khi chưa kết nối đúng DB.

Hai lỗi lifecycle được nêu trong bản audit trước đã được xử lý trong source hiện tại: `ChatScreen` đọc trạng thái `currentStatus` của client dùng chung khi khởi tạo; `PublicProfileScreen` mở chat bằng `MessagingRealtimeClient.shared`. Giới hạn tối đa 5 session/user vẫn có trong backend. Đây là trạng thái đọc từ source, chưa phải xác nhận realtime chạy ổn định trên thiết bị; mạng/handshake thực tế cần log runtime để kết luận.

## 2. Luồng hiện tại

1. Mobile lấy JWT từ phiên đăng nhập. REST dùng `ApiClient`; WebSocket client dùng STOMP CONNECT header `Authorization: Bearer ...`.
2. `ChatWebSocketConfig` mở `/ws`, simple broker `/queue`, application prefix `/app`, user prefix `/user`. Client chỉ được subscribe `/user/queue/chat-events`; client không được STOMP SEND để tạo tin.
3. Mobile gửi tin qua REST. `MessagingServiceImpl` xác thực thành viên, người nhận, privacy/block, giới hạn và idempotency; lưu message/sequence trong transaction.
4. Sau commit, `ChatEventListener` gửi event đến hai user queue. Broker hiện là simple broker trong memory; không có durable outbox/retry. REST lịch sử là nguồn đồng bộ sau reconnect.
5. Read cursor tăng đơn điệu; danh sách hội thoại trả unread count theo hội thoại. `/api/conversations/unread-total` trả tổng số unread messages, không phải số hội thoại chưa đọc.

## 3. Backend và dữ liệu hiện có

`backend/pom.xml` dùng Spring Boot 4.1.1, Java 22 và WebSocket starter. Security stateless JWT; handshake `/ws` được phép qua HTTP, còn STOMP CONNECT tự xác thực JWT, kiểm tra account ACTIVE và expiry, giới hạn 5 session/user trong tiến trình. Token được kiểm tra lại trên frame. Cấu hình giới hạn frame 65.536 bytes, send buffer 524.288 bytes, send time 15.000 ms; tốc độ gửi 30/phút/user và message tối đa 4.000 ký tự.

REST hiện có conversations (list/create/open, unread-total, paged messages before/after sequence, send, read, message-request list/count/accept/decline/unread-count), friendship (send/list/accept/decline/cancel/unfriend/block/unblock), messaging settings (GET/PUT) và user discovery `GET /api/users/search`. Các message pages dùng sequence/keyset, không tải toàn bộ hội thoại.

JPA mappings hiện có sáu nhóm: `conversations`, `messages`, `conversation_read_states`, `friendships`, `user_messaging_settings`, `user_blocks`. Entity/repository/indexes được ghi chi tiết tại [03 — Thiết kế dữ liệu](03-DATABASE-DESIGN.md). `application.properties` dùng Hibernate `ddl-auto=update`; production dùng `validate`. Không thấy Flyway/Liquibase trong cấu hình được kiểm tra. Không khởi chạy ứng dụng để suy ra schema vật lý hoặc tự cập nhật DB.

Không có Notification entity/API lưu lịch sử thông báo; Notifications screen vẫn là empty state. Community notifier hiện tải badge qua REST cho tin nhắn chưa đọc, lời mời kết bạn, yêu cầu tin nhắn và tin người lạ. Việc cập nhật badge dựa vào các lần fetch/refresh và luồng màn hình, chưa có subscription realtime toàn cục; vì vậy không mô tả chúng là realtime.

## 4. Mobile và UI hiện có

`MessagingRealtimeClient.shared` dùng STOMP, heartbeat 20 giây, reconnect timer, JWT, và subscribe user queue; URL WS/WSS được tạo từ `ApiConstants.baseUrl`. Android emulator mặc định dùng `10.0.2.2:8080`; thiết bị thật cần `API_BASE_URL` trỏ LAN IP của cùng backend. `adb reverse tcp:8080 tcp:8080` là lựa chọn cho thiết bị USB theo README.

`ChatScreen` tải lịch sử REST, gửi tin optimistic, nghe event và hiển thị thời gian tin nhắn. Avatar hiện chỉ render cho tin nhận bên trái; tin gửi chưa render avatar tài khoản hiện tại, dù helper có fallback profile. Trạng thái ban đầu lấy từ `currentStatus` của client. Chat mở từ hồ sơ truyền `MessagingRealtimeClient.shared`, không tạo client riêng. Chi tiết avatar/layout và đề xuất sửa được ghi ở addendum trong plan 04/05.

Community đã là feed-first với tab bar 5 mục. Header feed hiện có shortcut Tin nhắn, Bạn bè/Lời mời, Tin nhắn người lạ, Thông báo, Tìm người dùng và Quyền riêng tư tin nhắn. `MessagingInboxScreen` cũng mở được Stranger Inbox và Friends. User search hiện vào từ Community/Friends, chưa từ Explore. Explore có tìm kiếm lịch trình trong body và Notifications trên AppBar nhưng chưa có user search action. Notifications chưa có dữ liệu backend. Inbox search hiện chỉ lọc local trên các conversations đã tải.

## 5. Friendship/privacy hiện tại và phần thiếu

Policy hiện có `EVERYONE`, `FRIENDS_ONLY`, `NOBODY`; sau cập nhật 2026-11-17, missing/new setting mặc định `EVERYONE`, còn lựa chọn đã lưu được giữ nguyên. Quyền bắt đầu conversation mới được kiểm tra tại backend; `EVERYONE` với người chưa kết bạn tạo PENDING request trong Stranger Inbox, sender chỉ gửi tin mở đầu trước khi recipient accept. `FRIENDS_ONLY` yêu cầu friendship accepted để bắt đầu chat; `NOBODY` chặn bắt đầu mới kể cả với bạn bè. Accepted conversation được tiếp tục sau policy change/unfriend; `canContinueConversation` chặn block hoặc account inactive. Block xóa friendship nhưng giữ thread/history và cấm gửi. Các semantics này theo D-16/D-22.

`UserMessagingSettings`, GET/PUT API và `MessagingSettingsScreen` vẫn còn. Màn hình có thể vào từ header Community/legacy messaging Community; chưa có đường canonical trong Profile settings. Public profile chỉ hiển thị Nhắn tin khi `canMessage`; context chưa biểu diễn riêng quyền bắt đầu conversation mới và quyền tiếp tục accepted conversation cũ. Search API hiện match prefix `fullName`/public `handle`; accent-insensitive/không dấu chưa được kiểm chứng bằng schema/runtime.

## 6. Chẩn đoán realtime trên hai thiết bị

Source không cho biết hai thiết bị đang trỏ đến cùng host. Cần xác minh cùng URL backend bằng `/api/health`, cấu hình `API_BASE_URL`, log HTTP và STOMP CONNECT/SUBSCRIBE. Kiểm tra thêm token hết hạn/disabled, Origin allowlist, Wi-Fi/VPN/firewall, backend restart, session-cap rejection và trạng thái subscribe. Không ghi JWT vào log/chụp màn hình. Khi mất STOMP, REST vẫn phải tải được lịch sử; khi online lại, notifier refetch để khử lệch.

## 7. Tài liệu và giới hạn audit

Đã đọc README/DESIGN, quy ước kiến trúc và UI liên quan, CODEBASE_GUIDE, các tài liệu realtime hiện hữu và tìm kiếm chéo docs theo messaging/friendship/notification/unread. Một số tài liệu 6B/AI là snapshot lịch sử nên còn nói chat chưa triển khai hoặc mô tả Community cũ; cần đọc theo ngày và ưu tiên source hiện tại. Không khẳng định đã đọc tuần tự từng dòng của toàn bộ 167 file Markdown. Không xác minh database thật, thiết bị, logs runtime, build hay tests.

## Audit bổ sung — Conversation hide và badge (2026-11-18, lịch sử D-24; D-25 supersedes)

> Các bullet dưới đây ghi lại audit/triển khai D-24 tại thời điểm đó. D-25 là hành vi hiện hành: không hide/delete conversation, không đổi privacy/status accepted sau unfriend; xem Decision Record và Implementation Report mới nhất.

- `ConversationReadState` đã có composite key per-user/per-conversation và read cursor; dùng cùng entity để lưu nullable `hidden_at`, không thêm bảng participant state.
- Trước revision, conversation controller có list/history/send/read/request routes nhưng chưa có API ẩn riêng. Bổ sung `DELETE /api/conversations/{id}`; repository list/count phải lọc theo state của principal.
- `MessageResponse` dùng chung cho REST và WebSocket; được mở rộng additive với `conversationStatus`/`recipientVisible`. WebSocket sender-only vẫn chỉ tới sender.
- Inbox trước revision có dot khi còn pending request dù mọi tin đã đọc. Hiện Inbox/Community badge lấy unread request count, không lấy tổng pending để giữ dấu đỏ.
- Spring context test trên MySQL test schema đã thêm `hidden_at`; đây không phải bằng chứng schema/database của ứng dụng đã được cập nhật.
