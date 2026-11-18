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
- `user_messaging_settings`: policy của người nhận; mặc định hiện tại `EVERYONE` nếu chưa có row. Các lựa chọn đã lưu không bị ghi đè.
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
## Cập nhật triển khai — 2026-11-17

Phần dưới đây bổ sung trạng thái mới, không thay thế snapshot lịch sử ngày 10/11.

### Đã triển khai trong source

- Backend dùng `Conversation` hiện có để lưu `PENDING/ACCEPTED/DECLINED`, requester/recipient và timestamps; conversation cũ có status `null` được xem là `ACCEPTED`.
- Thêm API phân trang danh sách request, badge count, accept và decline. Yêu cầu bị block bị ẩn khỏi inbox/count. Request pending chỉ cho sender gửi tin mở đầu; recipient accept mới mở trao đổi hai chiều.
- Privacy `EVERYONE/FRIENDS_ONLY/NOBODY` áp dụng khi tạo chat; accepted chat tiếp tục sau đổi policy hoặc unfriend, trừ block/tài khoản inactive. Declined thread giữ lịch sử và cho gửi lại sau 1 ngày.
- Friend/request events phát invalidation sau commit; app shell sở hữu shared realtime client; chat lấy snapshot trạng thái hiện tại khi khởi tạo. UI có Friends/Invites/Stranger Inbox, badge tách riêng, avatar/time và thao tác accept/decline.

### Kiểm thử phiên này

- Backend: `.\mvnw.cmd "-Dtest=MessageRequestServiceTest,FriendshipPrivacyServiceTest,ChatRateLimiterTest" test` — PASS, 9 tests, 0 failures/errors.
- Backend Spring context: `TravelPlannerApplicationTests` — PASS trên MySQL 8.0.44 test schema; JPA mapping, repository initialization và query parsing khởi tạo thành công.
- Backend full suite trên test schema mới: 497 tests, 455 passed, 42 errors ở `RatingControllerTest`, `RouteServiceTest`, `SavedItineraryControllerTest`. Các test setup xóa `users` trong khi test trước để lại rows `media_assets.uploaded_by` hoặc `posts.author_id`; 3 class chạy riêng trên schema sạch pass 42/42. Đây là lỗi test-data isolation của suite, không thuộc messaging.
- Flutter: `flutter test` — 427 passed, 26 failed. Các lỗi tập trung ở Activity/Itinerary/Rating widget tests ngoài messaging/social badge. Messaging tests, gồm `chat_screen_test`, chạy PASS trong suite.
- Flutter: `flutter analyze` — chưa PASS; analyzer phát hiện informational lints, gồm brace-style lints trong các file Flutter liên quan và các lints sẵn có trong project.
- ADB nhận diện một Android device và một emulator (`adb devices`); chưa cài/chạy app, chưa khởi chạy backend, chưa có test hai tài khoản.
- Chưa chạy authenticated API/concurrency tests, MySQL API-level migration review, WebSocket thật hoặc Android build.

### Còn cần xác minh

Hibernate đã cập nhật mapping trên test schemas riêng; không chạy backend với DB development. Test schema `travel_planner_test` và schema tạm `travel_planner_test_realtime_20261117` được giữ nguyên, không drop. Chưa review DDL/query plan bằng report schema, chưa test authenticated API/WebSocket hoặc hai thiết bị. Còn 42 backend test-isolation errors trong 3 suite, 26 Flutter regression failures và analyzer informational lints; tất cả vẫn được ghi là chưa hoàn tất trong checklist.

## Phụ lục — Community navigation và tìm người dùng (2026-11-17)

Theo yêu cầu tiếp tục sau khi review plan bổ sung số 12, source đã được triển khai:

- Tách lối vào mobile thành Inbox thường, Stranger Inbox, Bạn bè/Lời mời và Tìm người dùng; Community feed và năm bottom destinations được giữ nguyên.
- Thêm tìm kiếm authenticated theo tiền tố tên hiển thị/handle, phân trang phía server, debounce và bỏ kết quả cũ phía mobile. DTO không trả username/email; relationship flags được nạp theo batch. Chưa thêm index vì không có bằng chứng query plan trên dữ liệu đại diện.
- Thêm unread-count riêng cho tin nhắn request đang pending; badge dot Community kết hợp unread accepted, unread stranger và incoming friend requests, không dùng tổng pending stranger thay cho unread.
- Không thay đổi schema, bảng hoặc migration. Control vuông chưa xác định được giữ nguyên đến khi nhận screenshot.

Kiểm thử phần bổ sung: `PublicUserServiceTest`, `MessageRequestServiceTest`, `FriendshipPrivacyServiceTest` PASS; Flutter `test/features/messaging` và `community_feed_test.dart` PASS 20/20; analyzer trên năm file route/model mới PASS. Phân tích rộng hơn các file đã sửa trước đó báo 17 lint mức info. Full backend lần này chạy 499 tests, 0 assertion failures và 175 errors trong test setup/cleanup, chủ yếu do xóa user bị khóa ngoại `media_assets.uploaded_by` trong test schema dùng lại. Chưa chạy app/API trên backend đang chạy hoặc test hai thiết bị. Kết quả này bổ sung, không thay thế các kết quả historical phía trên.

## Plan Revision 2 — Community, Explore, Public Profile, Privacy and Search (2026-11-17)

Theo yêu cầu mới, chỉ tài liệu trong `docs/plan/realtime-messaging/` được cập nhật; không sửa source, test, database hoặc migration trong lượt này. Plan 12 §9 là mục tiêu review, D-21 chờ duyệt.

Audit xác nhận Community header đang có shortcut Stranger riêng; Explore chỉ có itinerary search trong body và Notifications trên AppBar; user discovery API/screen đã có nhưng entry hiện ở Community/Friends; Inbox filter chỉ lọc conversations đã tải, không tìm user mới hoặc lịch sử message. Public profile chỉ có một `canMessage` flag nên không phân biệt quyền bắt đầu thread mới với tiếp tục accepted thread tồn tại. Privacy entity/API/screen vẫn có; vị trí truy cập hiện tại là Community headers, chưa có canonical Profile settings entry.

Plan đề xuất chuyển user-search entry sang Explore cạnh Notifications, bỏ shortcut Stranger riêng nhưng giữ Inbox entry, đặt Profile > Settings làm đường canonical privacy, và thêm additive can-start/can-continue context giữ nguyên D-16/server enforcement. Search user/conversation vẫn tách; prefix tiếng Việt normalized là phương án ưu tiên, còn DB column/index chỉ sau khi xác minh collation, EXPLAIN và volume. Các thay đổi này chưa được implement và không có kết quả test mới phát sinh từ plan-only revision.

### Trả lời các hạng mục audit

1. **Đang tồn tại:** user search theo prefix, Friends/Invites, Stranger Inbox, accepted inbox, profile relationship actions, privacy settings (three policies), backend authorization, accepted-thread continuity và block checks.
2. **Sai vị trí/thiếu:** Stranger Inbox có shortcut riêng trên Community dù đã có entry từ Messaging Inbox; user search ở Community/Friends chứ chưa ở Explore; privacy settings mở từ Community headers chứ chưa có canonical Profile settings path; profile CTA gộp quyền start mới/continue cũ.
3. **File chịu trách nhiệm hiện tại:** Explore: `frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart`; Community entry/badges: `frontend/mobile/lib/features/social/presentation/screens/community_feed_screen.dart` và `community_feed_notifier.dart`; Inbox: `frontend/mobile/lib/features/messaging/presentation/screens/messaging_inbox_screen.dart`; Stranger: `stranger_inbox_screen.dart`; user search: `user_search_screen.dart`, `messaging_repository.dart`, backend `PublicUserController`, `PublicUserServiceImpl`, `UserRepository`; profile: `public_profile_screen.dart`, `PublicUserServiceImpl`, `FriendshipServiceImpl`; privacy: `messaging_settings_screen.dart`, `MessagingSettingsController`, `MessagingSettingsServiceImpl`, `UserMessagingSettings`; create/send/continue chat: `MessagingServiceImpl`, `ConversationRepository`, `FriendshipServiceImpl`.
4. **Nguyên nhân đã xác minh:** Explore AppBar hiện chỉ có Notifications và avatar; user search action chưa được đặt ở đó. Community feed có route trực tiếp Stranger ngoài MessagingInbox route. `PublicProfileResponse.canMessage` phản ánh current can-start rule; UI ẩn CTA khi false, trong khi `MessagingServiceImpl.openDirect` trả thread cũ và accepted-send uses `canContinueConversation`. Search query chỉ `LIKE prefix` theo fullName/handle; không có normalized name/index contract, nên partial input ở đầu có thể hoạt động nhưng substring/diacritic guarantees chưa có. Privacy screen/API/storage vẫn tồn tại; chỉ access path hiện chưa nằm trong Profile settings.
5. **Thay đổi cần làm sau khi duyệt:** chuyển entry user search sang Explore; bỏ shortcut Stranger riêng trên Community, giữ Inbox entry; add Profile settings route; trả additive `canStartConversation`/`canContinueConversation` relationship states; profile CTA và status theo hai state; cải thiện Vietnamese prefix search; giữ Inbox local filter là conversation-only; backend revalidate policy/block/account on open/send.
6. **Database:** không cần bảng mới cho privacy, search API reuse, navigation hay relationship flags; `user_messaging_settings`/`conversations`/`users` đã tồn tại trong Entity model. Có thể cần normalized full-name column + index nếu query plan/collation chứng minh cần. Chưa xác minh physical schema/collation trên target DB; không được tạo migration trước khi đo và review.
7. **Plan đã cập nhật:** README, 01 audit, 02 scope, 03 DB, 04 API, 05 mobile, 06 privacy, 07 roadmap, 08 tests, 09 risks, 10 checklist, 11 decision record, 12 Community Navigation/Friend Discovery, và Implementation Report. Các nội dung mới đánh dấu plan-only, chờ review.
8. **Implementation:** không thực hiện ở revision này theo yêu cầu rõ ràng của người dùng.

## Plan-only update — Chat avatar/layout (2026-11-17)
Đã rà soát `ChatScreen`, `ChatMessage`, `PublicUserSummary`, `AuthNotifier` và backend `MessageResponse`. Nguyên nhân thiếu avatar của mình là nhánh outgoing chỉ căn `bubble` sang phải, không gọi `_messageAvatar`; tin nhận mới render avatar. UI hiện không gom nhóm tin. REST và WebSocket cùng dùng response có senderUserId/avatar/time; optimistic own message thiếu senderAvatar nhưng có thể lấy Profile hiện tại. Đã thêm đề xuất layout hai chiều, fallback peer profile, avatar cố định/loading/error, grouping trình bày không gộp dữ liệu, roadmap và test matrix vào plan 04/05/07/08/10. Chưa thay đổi code/API/database và chưa chạy tests vì đây là cập nhật kế hoạch.

## Implementation follow-up — Chat avatar/layout (2026-11-17)
Theo yêu cầu tiếp theo, đã implement `chat_screen.dart`: own avatar lấy từ Profile/AuthNotifier ở bên phải; peer avatar ưu tiên senderAvatar rồi fallback conversation peer ở bên trái; ảnh có loading/error placeholder; thay đổi Profile làm chat rebuild; bubble có chiều rộng giới hạn sau khi dành chỗ cho avatar. Tin liên tiếp cùng sender trong cùng ngày và cách nhau tối đa 2 phút được trình bày thành nhóm, avatar ở cuối nhóm; dữ liệu message vẫn tách riêng.

Đã thêm widget tests cho avatar own/peer, peer fallback, một avatar mỗi nhóm, đổi avatar own trong phiên và nội dung dài ở màn hình hẹp. `flutter test test/features/messaging`: PASS, 12 tests. `flutter analyze --no-pub lib/features/messaging/presentation/screens/chat_screen.dart test/features/messaging/chat_screen_test.dart`: PASS, no issues. Chưa chạy kiểm thử thủ công trên emulator/điện thoại; chưa đổi API/database.

## Implementation follow-up — Community navigation, block, timestamps và Explore search (2026-11-17)

### Đã triển khai

- Bỏ shortcut Stranger Inbox khỏi Community feed; giữ nguyên Stranger Inbox và badge trong Messaging Inbox.
- Thêm action tìm người dùng cạnh Notifications trên Explore, dùng `UserSearchScreen` và repository/API hiện có; ô tìm lịch trình không đổi.
- Chat Detail có avatar người trò chuyện ở header và menu `...` để mở public profile hoặc chặn. Chặn có bước xác nhận, gọi block API hiện hữu, khóa composer sau thành công và không xóa lịch sử.
- `ChatEventListener` kiểm tra block trước khi gửi event tới hai user, đóng khe hở khi block đã commit nhưng event đang chờ xử lý. Không thêm endpoint, bảng hoặc migration.
- Thêm `MessagingDateTime` dùng chung cho timestamp API zone-less (coi là giờ Việt Nam), ISO có timezone/UTC (đổi sang UTC+07 đúng một lần), và format `HH:mm dd-MM-yyyy`. Dùng formatter ở chat, inbox thường, stranger inbox và legacy community screen.
- Badge pending message requests được hiển thị tại Messaging Inbox; request item hiển thị timestamp.

### Xác minh

- Backend `mvnw -q '-Dtest=ChatEventListenerTest,FriendshipPrivacyServiceTest,MessageRequestServiceTest' test`: PASS, 10 tests, 0 failures/errors.
- Flutter `flutter test test/features/messaging test/features/social/community_feed_test.dart`: PASS, 29 tests (đã chạy trong phiên).
- Flutter analyzer trên 9 file liên quan: PASS, no issues.
- Không thay đổi schema/database hoặc thêm endpoint; tái sử dụng API hiện có. Profile/search response được mở rộng tương thích ngược bằng field `canContinueConversation`.

### Còn mở

- Chưa kiểm thử hai tài khoản trên emulator/điện thoại hoặc WebSocket khi backend đang chạy.
- Tìm user vẫn theo prefix như API hiện tại; tìm chuỗi bắt đầu ở giữa tên chưa được triển khai. Accent-insensitive prefix đã được xác nhận riêng trên MySQL 8.0.44 test schema ở phần bổ sung bên dưới.
- Xác minh thủ công ảnh avatar sau khi thay đổi trên server và chuỗi reconnect/block cần chạy ở runtime.

## Implementation update — Stranger messaging default và block restore (2026-11-17)

- Người dùng mới/chưa có row messaging settings nhận mặc định `EVERYONE`; lựa chọn policy đã lưu vẫn giữ nguyên, không có backfill/migration.
- Chat Detail tải danh sách block khi mở và resume để menu hiện “Bỏ chặn người dùng” đúng trạng thái sau khi rời/mở lại; unblock dùng API hiện có rồi mở lại direct context để backend quyết định quyền gửi.
- Hồ sơ có entry quyền riêng tư trên AppBar và trong nội dung. Khi API từ chối bắt đầu chat vì privacy, nút Nhắn tin mở preview chat chỉ đọc với thông báo chung; không tạo conversation/message giả và không nêu trạng thái block. Request pending chưa có opener cũng có banner giải thích khi không còn quyền gửi.
- Kiểm thử phiên này: backend `FriendshipPrivacyServiceTest,MessageRequestServiceTest,PublicUserServiceTest` PASS; Flutter messaging widget suite PASS 18 tests, gồm khôi phục block và menu unblock.
- `flutter analyze --no-fatal-infos` trên bốn file liên quan sau khi sửa: không có warning/error, còn 22 informational lints về brace style/Radio API deprecated. Profile screen test riêng PASS 1 test. Chưa xác minh runtime hai tài khoản/emulator/điện thoại.

## Implementation update — Privacy save, unread stranger badge và profile CTA (2026-11-17)

- Xác nhận privacy setting là lưu trữ backend qua `MessagingSettingsServiceImpl` và bảng JPA `user_messaging_settings`, không phải chỉ state trong Flutter. Sửa parser Flutter để giữ đúng cả `EVERYONE`, `FRIENDS_ONLY`, `NOBODY`; trước đó `FRIENDS_ONLY` bị giải mã thành `EVERYONE`.
- Màn hình cài đặt hiển thị nội dung lỗi API/status khi PUT thất bại thay cho thông báo chung, giúp xác định lỗi kết nối, phiên hoặc backend trên máy chạy thật.
- Badge Tin nhắn người lạ dùng số message chưa đọc; nếu còn request chờ xử lý nhưng không còn tin chưa đọc thì hiện dấu chấm. Badge Cộng đồng ở bottom navigation hiện tổng tin chưa đọc của accepted conversations và Stranger Inbox; lời mời bạn bè vẫn tạo dấu chấm khi không có tin chưa đọc.
- Gỡ nút Nhắn tin trùng trong relationship actions; giữ một CTA cạnh Theo dõi. Thêm widget regression test xác nhận chỉ có một nút.
- Backend `MessagingSettingsServiceTest` và `FriendshipPrivacyServiceTest` PASS; Flutter models/profile/community-feed tests PASS. Runtime PUT trên DB người dùng chưa xác minh, vì cần nhìn HTTP error chi tiết sau khi app mới chạy.

## Implementation update — Profile privacy entry và tiếp tục chat accepted (2026-11-17)

- Profile cá nhân có nút vào `MessagingSettingsScreen`, dùng `MessagingRepository` và GET/PUT settings hiện hữu.
- Public profile và User Search nhận field additive `canContinueConversation` tách khỏi `canMessage`. Backend tra accepted peer IDs theo batch, rồi áp dụng kiểm tra active/block; không lộ người bị block và không cho phép mở thread mới nếu policy không cho.
- Flutter hiển thị nút Nhắn tin nếu có thể bắt đầu thread mới hoặc tiếp tục thread accepted. Cả hai đi qua `openDirect`, backend vẫn là nguồn quyết định cuối cùng.
- Backend 4 class tests: 16 tests pass (bao gồm test policy chặn new chat nhưng giữ continuation); Flutter Profile + messaging + Community: 37 tests pass.
- Analyzer 14 file với `--no-fatal-infos`: không có lỗi/warning; còn 13 informational brace-style lints có sẵn trong `public_profile_screen.dart`.
- `UserHandleDatabasePersistenceTest#testSearchMatchesVietnameseNameWithoutDiacritics`: PASS trên MySQL 8.0.44 test schema; query prefix không dấu `nguyen%` khớp `Nguyễn Huệ` theo collation hiện tại. Không đổi query/schema.
- Search còn prefix-based; tìm chuỗi bắt đầu ở giữa tên chưa được triển khai. Cần đo EXPLAIN/volume trước khi đổi sang `%substring%` vì dạng đó có thể quét bảng và làm mất lợi ích index.

## Implementation update — Stranger privacy semantics D-23 (2026-11-18)

- Sửa lỗi lưu privacy mới trên entity `UserMessagingSettings`: constructor không tự gán `userId` cho entity `@MapsId`, nhờ vậy Spring Data dùng persist thay vì merge; test MySQL đăng ký tài khoản test, PUT `FRIENDS_ONLY`, GET lại và xác nhận có đúng một row.
- Gửi người lạ được nhiều tin. `EVERYONE` hiển thị request trong Stranger Inbox và reply của người nhận tự chuyển cùng conversation sang `ACCEPTED`. `FRIENDS_ONLY` cho sender thấy các tin của mình, nhưng lưu `recipient_visible=false`; recipient không thể đọc qua history, inbox/preview, request list, unread counter, event, mark-read hoặc accept/decline API.
- Khi hai người kết bạn, thread pending được promote khi mở/gửi; tin sender-only cũ vẫn bị lọc theo message, còn tin mới hiển thị bình thường. Màn hình sender giải thích rõ policy và không còn giới hạn một tin. Settings UI chỉ hiển thị `Mọi người`/`Bạn bè`; NOBODY cũ được hiểu như FRIENDS_ONLY ở Flutter và backend.
- Schema dùng cột `messages.recipient_visible` qua `ddl-auto=update`, không tạo bảng mới. Không xóa/reset dữ liệu. DTO conversation bổ sung `recipientPrivacyRestricted`.
- Backend: `FriendshipPrivacyServiceTest`, `MessageRequestServiceTest`, `MessagingSettingsServiceTest` và `TravelPlannerApplicationTests` pass; MySQL `UserHandleDatabasePersistenceTest#testFirstMessagingSettingsUpdatePersistsWithMapsId` pass. Kết quả gộp gần nhất: 11 tests pass. Spring context khởi tạo repository queries thành công.
- Sau khi thống nhất semantics legacy NOBODY với FRIENDS_ONLY, bộ service hiện tại chạy lại: 10 tests pass, 0 failures/errors.
- Flutter: `flutter test test/features/messaging` pass 18 tests, có kiểm tra gửi nhiều tin FRIENDS_ONLY và cờ privacy; analyzer sáu file liên quan báo `No issues found`.
- Chưa chạy tương tác thủ công hai tài khoản trên emulator/điện thoại hoặc xác minh WebSocket với backend đang chạy. Integration MySQL dùng `travel_planner_test`, không phải database dữ liệu ứng dụng.

### Hồi quy toàn bộ repository (2026-11-18)

- `mvnw test`: không pass toàn suite; 506 tests được chạy, 175 errors và 0 assertion failures. Các lỗi nằm ở setup/cleanup của fixture dùng chung `travel_planner_test`, gồm xung đột email fixture và FK `media_assets.uploaded_by` ngăn xóa user. Nhóm messaging + Spring context + MySQL integration phía trên đều pass độc lập.
- `flutter test`: 440 tests pass, 26 fail. Các failure nằm ngoài thay đổi messaging, chủ yếu test kỳ vọng cũ ở activity/itinerary detail, comment/rating và itinerary map. `flutter test test/features/messaging` vẫn pass toàn bộ 18 tests.
- Chưa chỉnh các suite ngoài phạm vi này trong thay đổi messaging.

## Implementation update — Ẩn conversation riêng, privacy sau unfriend và Inbox menus (2026-11-18)

### Đã triển khai

- Tái sử dụng `conversation_read_states`: thêm nullable `hidden_at` theo participant. API `DELETE /api/conversations/{id}` xác thực thành viên, chỉ ẩn phía actor, không xóa conversation/message; gửi `CONVERSATION_HIDDEN` invalidation riêng người thao tác.
- Backend lọc Inbox, Stranger Inbox, pending/unread request counts và unread total theo `hidden_at`. Tin mới bỏ ẩn cho sender và chỉ các recipient được phép thấy; sender-only không tạo list/unread/event ở recipient. History cũ recipient-visible trong accepted thread vẫn đọc được; từng tin sender-only tiếp tục bị lọc.
- Sau khi hủy kết bạn, gửi tin trong accepted conversation canonical sẽ kiểm tra lại quan hệ/privacy: EVERYONE dùng lại conversation chuyển thành PENDING stranger request; FRIENDS_ONLY lưu tin sender-only. Lịch sử cũ giữ visibility cũ, không sinh conversation trùng.
- Send response thêm `conversationStatus` và `recipientVisible`; chat UI hiển thị privacy notice sau send sender-only và không hiện trạng thái “Đã gửi/Đã đọc” cho tin đó.
- Inbox thường và Stranger Inbox có menu row riêng xem profile, chặn, xóa; block/delete xác nhận trước khi gọi API. Badge Stranger và Community chỉ phản ánh tin chưa đọc, request đã đọc không giữ dấu đỏ.

### File/API/Database

- Backend thay đổi `ConversationReadState`, `ConversationRepository`, `MessageRepository`, `MessagingService`, `MessagingServiceImpl`, `ConversationController`, `MessageResponse`; tests mở rộng `MessageRequestServiceTest`.
- Flutter thay đổi `MessagingRepository`, `ChatMessage`, `ChatScreen`, `MessagingInboxScreen`, `StrangerInboxScreen`, `CommunityFeedNotifier`, `CommunityFeedScreen`; thêm `messaging_inbox_screen_test.dart`, mở rộng chat/model/community tests.
- Thêm `DELETE /api/conversations/{conversationId}` (204); send response có hai field additive. Local test profile Hibernate cập nhật test schema và phát `ALTER TABLE conversation_read_states ADD COLUMN hidden_at datetime(6)`. Không thêm bảng; production DDL/release chưa được chuẩn bị.

### Xác minh

- Backend: `MessageRequestServiceTest` 11, `FriendshipPrivacyServiceTest` 3, `MessagingSettingsServiceTest` 1, `ChatEventListenerTest` 2 = 17 tests pass; `TravelPlannerApplicationTests` thêm 1 context test pass. JPA context dùng MySQL 8.0.44 `travel_planner_test`, xác nhận field mới được thêm ở test schema.
- Flutter: `flutter test test/features/messaging test/features/social/community_feed_test.dart` — 37 tests pass; `flutter analyze` trên 11 file thay đổi — No issues found.
- Chưa chạy full repository suites sau revision này. Kết quả hồi quy full suite ở phần trước là snapshot cũ, không phải chứng cứ mới.
- Chưa chạy API app-runtime hoặc kiểm thử hai tài khoản trên emulator/điện thoại. Không áp dụng schema update lên database ứng dụng.

## Implementation update — Stranger acceptance, block enforcement và bỏ quản lý xóa hội thoại (D-25, 2026-11-18)

### Đã triển khai

- Stranger request chỉ được accept tường minh bởi recipient. Mở pending chat không đánh dấu đã đọc; Accept đặt conversation `ACCEPTED` và cập nhật read cursor của recipient trong cùng transaction. Reply không còn auto-accept.
- Decline giữ nguyên lịch sử cho requester nhưng đánh dấu các tin pending trước đó là recipient-invisible; các tin đó không xuất hiện ở Inbox/history/realtime phía recipient sau này. Retry sau cooldown một ngày tái sử dụng canonical conversation và chỉ các tin mới được xét theo policy hiện hành.
- Accepted conversation tiếp tục bình thường sau unfriend và privacy change; không chuyển lại thành request. Block chặn cặp người dùng ở profile, search, feed/post, itinerary, comment/reply, rating summary và messaging; WebSocket không phát event cho cặp bị block. Dữ liệu/hội thoại được giữ lại để unblock không tự tái tạo friendship hoặc accept.
- Bỏ API DELETE/hide hội thoại và menu xóa ở Inbox; menu còn profile/block và row tap vẫn mở chat. JPA không còn map `hidden_at`; nếu cột vật lý đã được `ddl-auto=update` tạo ở local/test, không drop cột.
- Flutter giữ người dùng trong chat sau Accept, bật composer khi backend xác nhận, không mark-read khi chỉ mở request, và xử lý event block để khóa/đóng nội dung tương ứng.

### File và hợp đồng

- Backend: `ConversationController`, `ConversationRepository`, `MessageRepository`, `MessagingService`, `MessagingServiceImpl`, `ChatEventResponse`, `ChatEventListener`, friendship/user/post/itinerary repository-service-controller liên quan; `CommentController`, `ActivityCommentController`, `CommentThreadController`, `CommentServiceImpl`, `RatingController`, `RatingServiceImpl`; không thêm bảng hoặc migration.
- Flutter: `messaging_repository.dart`, `chat_event.dart`, `chat_screen.dart`, Inbox/Stranger Inbox; test chat/inbox/feed/profile được mở rộng.
- Không còn endpoint `DELETE /api/conversations/{id}`; accept/decline và message APIs giữ nguyên route. Event `CONVERSATION_ACCESS_REVOKED` chỉ gửi cho phía bị block để khóa giao diện; event khác bị loại khi cặp đang block.

### Xác minh lần cập nhật này

- Backend unit: bảy suite `MessageRequestServiceTest`, `FriendshipPrivacyServiceTest`, `CommunityPostServiceTest`, `PublicUserServiceTest`, `ChatEventListenerTest`, `CommentThreadServiceTest`, `RatingBlockAccessTest` — 55 tests pass. Hai test mới xác nhận viewer bị block không đọc được comment hoặc rating summary qua direct API.
- Spring context: `TravelPlannerApplicationTests` (1 test) khởi tạo thành công trên MySQL 8.0.44 `travel_planner_test`; đây là test schema, không phải database ứng dụng.
- Flutter: `flutter test test/features/messaging test/features/social/community_feed_test.dart test/features/profile/public_profile_screen_test.dart` — 40 tests pass.
- Flutter analyzer trên 8 file liên quan hoàn tất, không có lỗi/warning; còn 12 info-only `curly_braces_in_flow_control_structures` trong `public_profile_screen.dart`.
- Chưa chạy toàn bộ backend/Flutter suite trong revision này; chưa chạy app API thực tế, WebSocket giữa hai tài khoản, emulator/điện thoại hoặc rollout DB. Đây vẫn là điều kiện nghiệm thu còn mở.
- Một lượt gộp thêm `RatingControllerTest` vào Spring suites thất bại ở fixture setup/cleanup (15 errors/70 tests, 0 assertion failures) vì dữ liệu cũ trong `travel_planner_test` còn FK `media_assets.uploaded_by` khi test xóa user. Các unit suites và Spring context chạy tách riêng đều pass; không quy kết lỗi fixture này cho logic D-25.
