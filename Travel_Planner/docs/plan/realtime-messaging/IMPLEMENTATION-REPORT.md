# Báo cáo triển khai Giai đoạn 3 — Realtime chat và Friendship

Ngày cập nhật: 2026-11-10  
Branch: `feature/realtime-messaging`  
Phạm vi: Development, Flutter Mobile và Spring Boot; chưa chạy Production, chưa chạy Hibernate trên MySQL.

## Kết quả

Đã bổ sung backend JPA cho hội thoại 1-1, tin nhắn, read cursor, lời mời kết bạn, cài đặt quyền nhận tin và block. REST lưu tin nhắn; STOMP chỉ phát sự kiện sau khi transaction commit. Đã thêm mobile model/repository, một STOMP client dùng chung cho app account, giao diện danh sách chat/bạn bè/lời mời, chat bubble, retry theo cùng `clientMessageId`, trang cài đặt privacy/block và nút kết bạn/nhắn tin trên hồ sơ công khai.

Đây là implementation ở mức source code đã biên dịch và có unit/widget tests giới hạn. Chưa thể nghiệm thu toàn bộ luồng: chưa xác minh database Development, chưa có backup/restore được xác nhận, chưa khởi chạy ứng dụng có `ddl-auto=update`, chưa khởi tạo Spring context, chưa thử MySQL integration/concurrency hoặc hai thiết bị Android. Vì vậy không đánh dấu phần kiểm thử đó là PASS.

## Database và entity mới

JPA entities khai báo các bảng:

- `conversations`: cặp user canonical, unique pair, sequence mới nhất và tham chiếu tin cuối.
- `messages`: nội dung, sender, sequence theo conversation, timestamp server, unique `(conversation_id, sequence_number)` và `(sender_user_id, client_message_id)`.
- `conversation_read_states`: composite key `(conversation_id, user_id)` và read cursor.
- `friendships`: cặp user canonical, requester, trạng thái và unique pair.
- `user_messaging_settings`: policy của người nhận; mặc định `FRIENDS_ONLY`.
- `user_blocks`: blocker/blocked và unique chiều block.

Entity/repository bổ sung nằm dưới `backend/src/main/java/Travel_Planner/Travel_Planner/{model,repository}`. Hibernate mapping, FK/index thực tế và tương thích schema hiện hữu vẫn phải xác minh bằng một database Development đã xác định và backup phục hồi được. Không chạy DDL, không có migration framework, không xóa/reset dữ liệu. `UserHandleBackfillRunner` và Follow không được sửa trong thay đổi này.

## Backend API

- `POST /api/conversations/direct`, `GET /api/conversations`
- `GET /api/conversations/{conversationId}/messages` hỗ trợ `beforeSequence` hoặc `afterSequence`, trả `peerReadSequence` để phục hồi read receipt; `POST /api/conversations/{conversationId}/messages`
- `POST /api/conversations/{conversationId}/read`
- `POST /api/users/{userId}/friend-requests`
- `GET /api/users/me/friend-requests?direction=received|sent`
- `POST /api/friend-requests/{friendshipId}/accept|decline`, `DELETE /api/friend-requests/{friendshipId}`
- `GET /api/users/me/friends`, `DELETE /api/users/me/friends/{userId}`
- `POST /api/users/{userId}/block`, `DELETE /api/users/{userId}/block`, `GET /api/users/me/blocks`
- `GET /api/users/me/messaging-settings`, `PUT /api/users/me/messaging-settings`

Sender được suy ra từ JWT principal. Backend xác minh người dùng/conversation/quyền/block trước gửi; cursor đọc chỉ tăng; gửi lại cùng `clientMessageId` được dedupe. Open direct khóa user theo thứ tự ID và conversation có unique pair. Event `MESSAGE_CREATED` và `READ_CURSOR_UPDATED` được gửi tới `/user/queue/chat-events` qua `@TransactionalEventListener(AFTER_COMMIT)`. Client không được STOMP SEND; CONNECT yêu cầu JWT bearer header và chỉ cho phép subscribe user queue đã định.

## Chính sách và giới hạn

- `FRIENDS_ONLY` mặc định; `EVERYONE` cho người lạ mở chat; `NOBODY` chặn tin nhắn mới kể cả bạn bè.
- Request ngược chiều không tự accept. Follow và Friendship là hai quan hệ riêng.
- Block/hủy bạn không xóa lịch sử; quyền gửi được kiểm tra lại phía server mỗi lần gửi.
- Tin nhắn tối đa 4.000 ký tự; rate limit Development 30 tin/phút/user; tối đa 5 WebSocket sessions/user; frame 65.536 bytes; send buffer 524.288 bytes; send time limit 15.000 ms.
- Các giới hạn rate-limit hiện là theo tiến trình backend, phù hợp Development đơn instance; chưa phải distributed limiter.

## Flutter Mobile

Files mới dưới `frontend/mobile/lib/features/messaging/`:

- `data/models/`: message, conversation summary, event, friend request, messaging settings.
- `data/messaging_repository.dart`: dùng `ApiClient` hiện tại.
- `data/messaging_realtime_client.dart`: shared socket, exponential reconnect backoff, JWT expiry timer, subscription user queue.
- `presentation/screens/`: Community, Chat và Messaging Settings.

Đã nối Community vào tab Cộng đồng hiện hữu qua export tương thích; giữ năm bottom tabs và NotificationsScreen. Chat đồng bộ REST khi reconnect/foreground, khôi phục peer read cursor, hỗ trợ phân trang lịch sử, optimistic bubble và retry cùng UUID. PublicProfile đọc friendship context từ API mới, giữ Follow, bổ sung các thao tác request/accept/decline/cancel/unfriend và mở conversation nếu được phép. Cài đặt có policy nhận tin và danh sách bỏ chặn.

## Dependencies và cấu hình

- Backend: `spring-boot-starter-websocket`.
- Flutter Mobile: `stomp_dart_client: 3.0.1`.
- Các giới hạn chat được khai báo trong `backend/src/main/resources/application.properties`.
- Giữ nguyên Development `spring.jpa.hibernate.ddl-auto=update`; chưa khởi động backend vì điều kiện DB/backup chưa được xác nhận.

## Kiểm thử đã chạy

- Backend `mvnw -Dtest=ChatRateLimiterTest test`: PASS, 1 test.
- Backend `mvnw "-Dtest=ChatRateLimiterTest,FriendshipPrivacyServiceTest" test`: PASS, 3 tests; không nạp Spring context, không kết nối DB.
- Backend `mvnw -DskipTests test-compile`: PASS; biên dịch 190 source main và 29 test source.
- Flutter `flutter test test/features/messaging/messaging_models_test.dart test/bottom_navigation_test.dart`: PASS, 19 tests.
- Flutter full `flutter test`: 360 passed, 3 failed. Ba lỗi còn lại ở `explore_test.dart` (CreatorSummary fallback) và hai test `rating_ui_layout_test.dart`; không thuộc luồng messaging.
- Flutter `flutter analyze --no-fatal-infos`: PASS, exit code 0; còn 39 informational lints về brace style và `RadioListTile` API deprecated, không còn warning/error.
- Chưa chạy Spring Boot context/API tests, MySQL mapping/concurrency, WebSocket handshake thật, Android/iOS build, Flutter Web, hoặc manual test hai tài khoản.

## Chưa xác minh / bước tiếp theo

1. Xác nhận `DB_URL` trỏ đúng Development DB và backup có thể restore; xem lại các giá trị env mà backend sẽ nạp. Chỉ sau đó mới chạy app để Hibernate cập nhật schema và xác minh sáu bảng, FK, unique constraints, indexes.
2. Chạy Spring context/repository/API tests trên MySQL test DB cô lập; bổ sung test sequence ordering, duplicate concurrent open/send, cursor và IDOR.
3. Chạy WebSocket integration test cho JWT, subscribe destination, expired token, inactive user và event sau commit/rollback.
4. Cài app trên hai thiết bị/emulator, xác minh login/logout/account switch, realtime, privacy/block, resume/reconnect, lịch sử sau restart và read receipt.
5. Hoàn thiện UI smoke test của Community/Chat/Settings và xử lý ba Flutter regression failures ngoài phạm vi trước khi tuyên bố toàn bộ suite xanh.

## Cách kiểm thử hai tài khoản sau khi DB đã được duyệt

1. Khởi chạy backend Development theo README sau khi xác minh `DB_URL` và backup.
2. Chạy Flutter Mobile trên hai thiết bị với `--dart-define=API_BASE_URL=http://<LAN-IP>:8080`.
3. Đăng nhập tài khoản A/B. Ở B, mở Hồ sơ > quyền riêng tư tin nhắn, chọn `EVERYONE` để thử chat người chưa kết bạn hoặc giữ `FRIENDS_ONLY` và chấp nhận request từ A.
4. Từ hồ sơ B, A gửi lời mời; B chấp nhận trong Cộng đồng > Lời mời. A mở lại hồ sơ B > Nhắn tin.
5. Gửi tin hai chiều, xác nhận nhận realtime và read state; tắt/mở app, cuộn lên tải lịch sử; tắt mạng rồi bật lại để xác minh đồng bộ.
6. Đổi B sang `NOBODY`, thử gửi tin mới; thử block/unblock và xác nhận nội dung lịch sử vẫn tồn tại.
7. Đăng xuất A rồi đăng nhập C trên thiết bị đó; xác nhận không thấy hội thoại/private state của A.

Không được coi các bước này là PASS trước khi thực hiện thật.