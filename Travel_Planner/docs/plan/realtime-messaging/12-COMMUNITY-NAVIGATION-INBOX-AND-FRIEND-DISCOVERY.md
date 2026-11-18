# 12 — Community Navigation, Messaging Inbox và Friend Discovery

**Trạng thái:** Baseline source phần inbox/search đã được triển khai ngày 2026-11-17. Revision 2 dưới đây chỉ cập nhật Plan theo yêu cầu ngày 2026-11-17; các thay đổi điều hướng Explore, public profile và privacy discoverability chưa được implement. Không thay thế quyết định đã duyệt D-16 về privacy/message requests.

## 1. Audit hiện trạng

*Audit ở mục này là snapshot trước khi triển khai baseline §8. Source hiện tại được audit lại tại §9.1; phần đó có ưu tiên khi nội dung khác nhau.*

- Bottom Navigation ở frontend/mobile/lib/shared/navigation/main_navigation_shell.dart có 5 mục; Community là mục thứ hai và mở social CommunityScreen → CommunityFeedScreen.
- Feed ở frontend/mobile/lib/features/social/presentation/screens/community_feed_screen.dart có hai tab bài viết. AppBar có shortcut Tin nhắn (chat bubble → messaging CommunityScreen tab 0), Lời mời kết bạn (person add → tab 2), Tin nhắn người lạ (mailbox → tab 3), và Thông báo (notifications screen). Đây là các lối vào trực tiếp riêng.
- Messaging CommunityScreen ở frontend/mobile/lib/features/messaging/presentation/screens/community_screen.dart gom inbox, bạn bè, lời mời đến/đã gửi và stranger inbox trong bốn tab.
- CommunityFeedNotifier lấy unread messages, tổng lời mời kết bạn đến và tổng message requests đang chờ. Community icon dưới Bottom Navigation chưa có badge.
- Backend đã có public profile theo ID/handle, friends, friend requests, conversation list, message request list/count và unread-total. Chưa có API tìm kiếm user.
- User có fullName, handle, username, email; handle là định danh công khai. Profile response dùng fullName/handle và relationship context, không nên tìm/lộ username hoặc email đăng nhập.
- Không thấy icon hình vuông rõ ràng trong các actions Header Community đã đọc. Attachment không chứa screenshot nên không nhận diện được control cần xóa.

## 2. Navigation mục tiêu

*Navigation ở mục này là baseline proposal. Yêu cầu mới về Explore/Community/Profile nằm tại §9.2 và supersede các entry point user search/Stranger Inbox tương ứng.*

Giữ feed và năm Bottom Navigation destinations. Community vẫn là feed-first, không tạo bottom tab thứ sáu/hub trùng.

Các đích nghiệp vụ riêng:
1. Community Feed: feed/tab hiện tại, bài viết và actions giữ nguyên.
2. Tin nhắn: inbox thông thường, chỉ ACCEPTED và legacy status null.
3. Stranger Inbox: màn hình riêng cho incoming Conversation PENDING; không phải filter tạm trong inbox thường.
4. Bạn bè: màn hình riêng có tab Bạn bè và Lời mời (incoming/outgoing).
5. Tìm người dùng: khu vực riêng, có thể đi từ Friends hoặc entry point Community.

Không cần hệ Navigator mới. Tái dùng repository, realtime client, profile route và design-system widgets. Màn hình/route riêng không đồng nghĩa tạo logic hoặc hệ state trùng lặp.

### Nút hình vuông cần xác định

Không xóa shortcut theo phỏng đoán. Cần screenshot hoặc mô tả chính xác vị trí/icon, sau đó trace callback và xác nhận chức năng. Source hiện có ba shortcuts nghiệp vụ riêng: tin nhắn, lời mời kết bạn, stranger inbox; Notifications là một route khác. Nếu control được chỉ ra là một shortcut này, phải có đường vào thay thế trong các màn hình tương ứng trước khi bỏ. Bảo toàn chức năng Notifications nếu đó là control được đánh dấu.

## 3. Hành vi màn hình

### Inbox thông thường
Mỗi row hiển thị avatar/fallback tròn, tên, public handle, preview tin mới nhất, thời gian local, unread count theo conversation; hỗ trợ tìm conversation đã tải và mở chat. Có trạng thái realtime khi cần. Không đưa PENDING/DECLINED vào đây. Khi recipient accept một message request, chính conversation canonical chuyển sang inbox thường.

### Stranger Inbox
Hiển thị incoming PENDING nơi viewer là recipient, avatar, full name/handle, tin gần nhất, thời gian, unread per-row. Mở thread không mark-read; recipient có thể accept, decline hoặc block. Chỉ Accept tường minh chuyển cùng conversation sang inbox thường và cập nhật read cursor; không tạo conversation khác. Decline giữ lịch sử sender-side, ẩn tin cũ với recipient, cho phép gửi lại sau 1 ngày trên canonical conversation. Người gửi được gửi nhiều tin khi policy là EVERYONE.

### Bạn bè và lời mời
Tab Bạn bè: danh sách phân trang, tìm trong danh sách, mở profile, bắt đầu chat, unfriend theo API hiện tại. Tab Lời mời: received/sent, profile, accept/decline/cancel. Kết bạn độc lập với việc đã có chat hay messaging privacy; server vẫn kiểm tra block, account status và friendship state.

### Tìm người dùng
Tìm theo tên hiển thị fullName và định danh công khai handle (@handle). Không tìm hoặc trả username/email đăng nhập. Search độc lập với danh sách bạn bè; tìm thấy người lạ có thể gửi friend request mà không cần họ nhắn trước.

Đề xuất UX/API: chỉ cho user đăng nhập search; debounce khoảng 300 ms; query tối thiểu 2 ký tự; page mặc định 20, tối đa 50; stable ordering, infinite scroll, bỏ response cũ sau query mới, clear query reset trang. Server lọc ACTIVE users. Chuẩn hóa hoa/thường và dấu tiếng Việt nhất quán. Dùng prefix/full-text strategy có index evidence; tránh wildcard scan toàn bảng. Kết quả: userId, avatar, fullName, handle và relationship/action flags.

Các trạng thái: self (ẩn action), chưa kết bạn (Thêm bạn), outgoing pending (Đã gửi/Hủy), incoming pending (Chấp nhận/Từ chối), accepted friend (Bạn bè/chat/unfriend), blocked/inactive/không khả dụng. Backend là nguồn quyết định và kiểm tra lại trên mutation; UI không tự suy ra quyền. Để tránh lộ ai block ai, đề xuất trạng thái tổng quát Không thể thao tác hoặc ẩn quan hệ bị block.

## 4. API, database và realtime

*API search/badge trong mục này là đề xuất trước baseline. `GET /api/users/search` và unread request count đã có source; revision tiếp theo xem §9.5.*

### Tái sử dụng API
- Public profiles: GET /api/users/{id}/public-profile và GET /api/users/by-handle/{handle}
- Friends: GET /api/users/me/friends?page=&size=
- Requests: GET /api/users/me/friend-requests?direction=received|sent&page=&size=
- Friendship mutations: routes hiện có gửi/accept/decline/cancel/unfriend/block
- Inbox: GET /api/conversations?page=&size=
- Stranger inbox/count: GET /api/conversations/message-requests và /count
- Unread accepted: GET /api/conversations/unread-total; giữ nguyên nghĩa tổng unread messages.

### Bổ sung cần review
User search chưa có API; đề xuất mở rộng PublicUserController/PublicUserService với GET /api/users/search?q=&page=&size=. Authenticated principal là viewer; không nhận viewerId từ client. Kết quả chỉ gồm public fields; page relationship state được nạp batch để tránh N+1.

Badge cần các metric riêng: unread messages trong accepted inbox, pending friend requests received, pending stranger requests, unread messages trong pending Stranger Inbox. Pending không đồng nghĩa unread: đã đọc message request nhưng chưa accept thì pending vẫn còn. Không cộng các loại metric vào một số. Giữ unread-total hiện tại; có thể tái sử dụng message-request count; thiết kế aggregate snapshot endpoint/response additive cho counts còn lại nếu cần tránh tải page để đếm. Không cộng/trừ badge từ WebSocket event; event chỉ invalidate và client fetch REST snapshot.

Community Bottom Navigation hiển thị dot khi có unread ordinary/stranger message hoặc pending incoming friend request. Số chi tiết đặt tại entry/tab tương ứng. Khi read/accept/decline/cancel/block, app resume, route return, login/account switch, hoặc event invalidation, refetch metrics liên quan. Logout/account switch xóa snapshot trước khi nạp account mới. Nhiều thiết bị dùng cùng REST source; event mất thì refresh/resume khôi phục.

Không thêm bảng: friendships, conversations/status, messages, conversation_read_states, user_blocks, settings đã đại diện các nghiệp vụ. Search dùng users hiện có. Chỉ đề xuất index sau khi query plan chứng minh cần và có DDL additive/review; không thêm migration/table trong plan này.

## 5. File map dự kiến

Mobile hiện tại cần review: social/community_feed_screen.dart (feed/navigation/badges), social/community_feed_notifier.dart (snapshot/invalidation), shared/navigation/main_navigation_shell.dart (dot trên icon Community), messaging/community_screen.dart (hiện gom bốn tab, tách thành destinations hoặc dispatcher mỏng), messaging_repository.dart (search/count calls), conversation_summary.dart/friend_request.dart (nếu contract cần), profile/public_profile_screen.dart (tái dùng relationship actions), messaging_realtime_client.dart (giữ shared owner).

Backend dự kiến review: PublicUserController, PublicUserService/Impl, UserRepository và DTO/projection search; friendship/conversation/message/read repositories/services cho batch state và aggregate counts. Không tạo entity/table. File mới chỉ khi pattern hiện tại đòi hỏi: search-result/count DTO, model Flutter, các route-level screens. Không tạo bốn repository/state systems.

## 6. Kiểm thử và acceptance

Backend: search fullName/handle, Unicode/case/diacritics, blank/short/long query, page bounds/order/dedup; chỉ ACTIVE; không lộ username/email/password; self/sent/received/friend/rejected/block states/action flags; privacy messaging không tự cấm friendship; mutations revalidate quyền; no N+1; counts phân biệt pending/unread; read request giữ pending nhưng unread giảm; rollback không phát event; duplicate event không double count.

Flutter: feed/posts không regression; bốn destination điều hướng độc lập; inbox thường không có PENDING; stranger không có ACCEPTED/DECLINED; accept chuyển cùng thread; search debounce/cancel stale response/pagination/dedup/empty/error; friend-request actions; status actions đúng; badge snapshot/dot OR/không cộng sai đơn vị/event+REST/account switch/resume/multi-device; accessibility labels, target size, text scaling và loading states.

Manual: hai tài khoản trên emulator + điện thoại cùng backend; tìm user, gửi/accept/decline friend request; gửi stranger request, đọc nhưng chưa accept, accept và xác nhận chuyển inbox; block; event/reconnect/refresh và badge trên từng device. Screenshot control bị bỏ phải được đối chiếu và lưu chức năng/entry point thay thế trước implementation.

## 7. Câu hỏi chờ review

*Câu hỏi được ghi trước baseline implementation. Các quyết định/đề xuất mới và hạng mục cần user review hiện nằm tại §9.6 và D-21.*

1. Screenshot/vị trí chính xác của icon hình vuông và shortcut cần bỏ.
2. Search matching exact/prefix/full-text; đề xuất prefix/full-text có index evidence, tránh wildcard scan.
3. Duyệt authenticated-only search và policy không tiết lộ bên block.
4. Duyệt metric aggregate độc lập và placement badge; giữ rõ pending khác unread.
5. Duyệt navigation destination và đường thay thế cho shortcut được xác định.

## 8. Kết quả triển khai và xác minh

- Đã giữ nguyên năm bottom destinations và chuyển các shortcut Tin nhắn, Bạn bè/Lời mời, Tin nhắn người lạ sang các màn hình route riêng; thêm dot ở Community khi có unread tin nhắn thường, unread tin người lạ hoặc lời mời kết bạn đến.
- Đã thêm `GET /api/users/search?q=&page=&size=` và màn hình tìm người dùng theo prefix `fullName`/`handle`, debounce, phân trang, bỏ response cũ và hiển thị các hành động quan hệ. Response chỉ trả public fields; backend lấy viewer từ principal và yêu cầu tài khoản ACTIVE. Relationship state được nạp theo batch.
- Đã thêm endpoint unread của pending message requests để dot Community không nhầm pending đã đọc với unread. Không thêm bảng hoặc migration.
- Đã sửa danh sách friends, inbox thường và Stranger Inbox thành các route riêng; giữ nguyên các API/actions hiện có và dùng shared `MessagingRepository`/realtime client.
- Chưa sửa icon hình vuông vì chưa có screenshot/định vị. Chưa chạy app với hai tài khoản, backend runtime/API thực hoặc xác minh trải nghiệm trên thiết bị.
- `PublicUserServiceTest`, `MessageRequestServiceTest`, `FriendshipPrivacyServiceTest`: PASS. Flutter `test/features/messaging` và `community_feed_test.dart` PASS tổng 20 tests; các màn hình mới (friends/inbox/stranger/search) analyzer PASS không issue. Phân tích rộng hơn các file đã sửa trước đó vẫn báo 17 lint mức info.
- Full backend `mvnw -q test`: 499 tests, 0 assertion failures, 175 errors; error log tập trung vào test setup xóa user còn được tham chiếu bởi `media_assets.uploaded_by` trong test schema đã có dữ liệu. Đây là lỗi isolation/cleanup suite, dù các test service liên quan chạy riêng đã pass.

**Điều kiện còn mở:** cần screenshot để xác định đúng control vuông; cần test runtime hai tài khoản và giải quyết/isolated test data trước khi đánh dấu nghiệm thu toàn bộ.

## 9. Revision 2 — Community, Explore, Public Profile, Privacy và Search (Plan-only, 2026-11-17)

Yêu cầu revision này là nguồn phạm vi mới cho các thay đổi tiếp theo. Chỉ cập nhật tài liệu; chưa sửa code/database. Nội dung §8 là lịch sử baseline đã làm, không có nghĩa revision này đã triển khai.

### 9.1 Audit source hiện tại (snapshot 2026-11-17; D-25 bên dưới supersedes messaging behavior)

- Active Community là `social/presentation/screens/community_feed_screen.dart`. Header hiện có các shortcut Tin nhắn, Bạn bè/Lời mời, Tin nhắn người lạ, Thông báo, Tìm người dùng và Quyền riêng tư tin nhắn. Do đó Stranger Inbox vẫn có một shortcut riêng trên Community; user search/privacy hiện cũng chưa ở vị trí Explore/Profile mong muốn.
- `MessagingInboxScreen` đã có đường vào Stranger Inbox và Bạn bè; đây là entry point cần giữ lại sau khi bỏ shortcut Stranger riêng trên Community.
- `ExploreScreen` hiện có tìm kiếm/lọc lịch trình riêng trong nội dung và action Thông báo trên AppBar; chưa có action tìm người dùng. Bổ sung icon người dùng cạnh Notifications nhưng vẫn giữ nguyên `SearchBarPill` và `ExploreNotifier` tìm lịch trình.
- `UserSearchScreen` cùng `GET /api/users/search` đã tồn tại, đang được mở từ Community/Friends. API trả `fullName`, public `handle`, avatar và action flags; không trả login `username`/email. Trong UI, “username” được hiểu là định danh công khai `@handle`, không phải credential username.
- Inbox search hiện tại ở `MessagingInboxScreen` là lọc tại client trên các conversation đã tải, theo tên/handle/preview tin cuối; không phải tìm user mới, không tìm toàn bộ lịch sử message và không có server query riêng. Không gộp nghiệp vụ đó với Explore user discovery.
- `PublicProfileScreen` chỉ render nút Nhắn tin khi `profile.canMessage` true. Backend profile/search context đang biểu diễn quyền bắt đầu chat qua flag này; chưa có flag riêng cho hội thoại accepted đã tồn tại. Vì vậy UI không thể hiện CTA để tiếp tục một thread cũ nếu privacy đổi làm `canMessage=false`, dù `openDirect` trả conversation có sẵn và backend cho accepted thread tiếp tục nếu không block/account inactive.
- Privacy không mất khỏi backend: `UserMessagingSettings`, repository, GET/PUT `/api/users/me/messaging-settings`, `MessagingSettingsScreen` và API Flutter đều còn. Tại thời điểm audit service mặc định `FRIENDS_ONLY`; D-22 sau đó đổi mặc định thiếu setting sang `EVERYONE`. Màn hình hiện có lối vào từ Profile AppBar và nội dung hồ sơ.
- Snapshot lịch sử: backend từng được mô tả theo D-16 với một opener và reply auto-accept. D-25 thay thế: `EVERYONE` cho phép nhiều tin pending; chỉ recipient Accept tường minh mới accepted; `FRIENDS_ONLY` cho phép sender ghi tin sender-only; accepted thread tiếp tục sau đổi policy/unfriend; block/inactive chặn tiếp tục.
- Search API hiện là prefix theo `fullName`/`handle`, dùng `lower` nhưng không có normalized-name field. Không thể khẳng định dấu tiếng Việt có/không dấu hoạt động nhất quán nếu chưa kiểm schema collation và query trên MySQL mục tiêu.

### 9.2 Navigation target

- **Community:** Feed; entry Tin nhắn; entry Bạn bè/Lời mời. Bỏ shortcut Tin nhắn người lạ khỏi header Community. Stranger Inbox chỉ mở bên trong Tin nhắn (từ `MessagingInboxScreen`). Không bỏ badge pending/unread, screen, API, service hay repository.
- **Explore:** giữ nguyên search lịch trình trong body; trên AppBar đặt icon Tìm người dùng ngay cạnh Notifications (đề xuất Search people sát bên trái Notifications), mở lại `UserSearchScreen` bằng auth/repository hiện có.
- **Public Profile:** giữ thao tác friendship hiện có; thêm trạng thái/CTA chat dựa trên quyền bắt đầu mới hoặc khả năng tiếp tục conversation accepted. Không bắt buộc friendship trước nếu recipient policy cho phép.
- **Privacy:** canonical route `Profile → Quyền riêng tư tin nhắn`, tái sử dụng `MessagingSettingsScreen` và API hiện tại. Shortcut Profile AppBar và nút nội dung cùng mở một screen/repository.
- Giữ 5 bottom destinations và search itinerary hiện tại. Không tạo Navigator/hub/repository mới.

### 9.3 Public profile và privacy contract cần làm rõ

Mở rộng profile/search relationship context theo hướng additive để tránh phá API consumers:

- `canStartConversation`: policy + friendship + active + nonblocked quyết định tạo conversation mới. Có thể giữ `canMessage` như alias tương thích trong migration.
- `canContinueConversation` (hoặc tên tương đương): true khi có conversation canonical ACCEPTED và cả hai account ACTIVE, không block; không phụ thuộc privacy hiện tại hoặc friendship hiện tại, theo D-16.
- Kết quả search/profile có thể trả thêm `hasAcceptedConversation`/continue flag. Query conversation state theo batch cho trang search; tránh N+1. Với PENDING request, hiển thị trạng thái request/entry Stranger Inbox, không coi như accepted chat.
- UI hiển thị “Nhắn tin” nếu có quyền bắt đầu mới hoặc tiếp tục thread accepted. Nếu không có quyền, hiển thị giải thích tổng quát như “Hiện không thể bắt đầu cuộc trò chuyện”; không tiết lộ ai đã block ai. Backend luôn revalidate khi `POST /api/conversations/direct` và khi gửi message.
- Existing accepted conversations tiếp tục sau đổi `EVERYONE → FRIENDS_ONLY/NOBODY` hoặc unfriend. Request PENDING đã được tạo hợp lệ vẫn giữ nguyên để recipient accept/decline; privacy mới chặn request mới và retry sau decline. Block thắng mọi state; không xóa lịch sử nhưng cấm gửi/nhận. Self-chat và inactive users luôn bị từ chối.

### 9.4 Search contract: user discovery và conversation search là hai nghiệp vụ

1. **Explore → tìm người dùng:** tìm user mới hoặc bạn hiện tại, gửi/accept/cancel lời mời, mở profile/chat. Reuse `GET /api/users/search`; không tìm itinerary/place. Response giữ public `handle`, không expose login `username`/email/password.
2. **Inbox → tìm cuộc trò chuyện:** chỉ lọc các hội thoại của viewer. Không tìm user chưa có conversation; không tìm toàn bộ nội dung lịch sử. Nêu rõ giới hạn của filter client trên page đã tải. Nếu số lượng conversation cần server-side search, thêm filter vào conversation-list query theo peer fullName/handle, vẫn chỉ trong membership của viewer.

Tìm theo prefix đủ cho v1 và tránh `%query%` scan. Để hỗ trợ phần tên/handle nhập dần và không dấu, đề xuất normalize Unicode NFD, bỏ combining marks, map `đ→d`, lowercase; đồng bộ normalized full name lúc create/update và backfill dữ liệu cũ. Public `handle` vốn có unique index; normalized full-name prefix hiện không có cột/index. Đề xuất column `full_name_search` + index cho prefix query, chỉ chốt DDL sau `EXPLAIN`/benchmark trên MySQL mục tiêu. Nếu bắt buộc substring giữa từ, đánh giá full-text ngram/index phù hợp MySQL và dữ liệu trước; không implement `LIKE '%q%'` tùy tiện hoặc tải toàn bộ users về mobile. Page size mặc định 20, max 50; debounce 300–350 ms; từ khóa 2–50 ký tự; stable order; hủy response query cũ; trạng thái loading/empty/error/retry.

### 9.5 API/database impact dự kiến

- Không cần DB mới cho friendship discovery, public profile CTA, inbox navigation hoặc privacy settings reuse.
- `UserMessagingSettings`/`user_messaging_settings` đã là mô hình persistence; không thêm settings table. Không backfill schema; default hiện tại khi thiếu setting là `EVERYONE` theo D-22, còn policy lưu sẵn giữ nguyên.
- API user search đã có; chỉ mở rộng matching normalization và response flags nếu cần. Không tạo endpoint tìm itinerary/user dùng chung sai nghiệp vụ.
- Cần thêm batch conversation lookup/DTO flags để phân biệt can-start với can-continue. Ưu tiên query/repository bổ sung trên `conversations`; không thêm conversation table.
- Chỉ cần schema migration nếu được duyệt `full_name_search` + index; backfill an toàn, index-only/nullable-first rollout, kiểm tra rollback và không làm mất user data. Nếu MySQL collation/query plan hiện tại chứng minh hỗ trợ accent-insensitive prefix đạt yêu cầu, có thể bỏ cột; điều này chưa được xác minh.

### 9.6 Roadmap/acceptance cho revision này

1. Chốt API semantics và D-16 compatibility, migration/search strategy dựa trên MySQL query plan.
2. Backend: can-start/can-continue batch context, user search partial/diacritic behavior, membership/block/account status và privacy enforcement.
3. Flutter: Community bỏ Stranger shortcut; Explore thêm user-search action cạnh notification; Profile settings route; Profile CTA theo hai quyền độc lập; giữ Inbox search riêng.
4. Tests: mọi case tại §7 yêu cầu revision này, backend/API, widget/navigation, migration/query plan nếu có.
5. Manual 2 accounts + emulator/device: đổi privacy, accepted/pending transition, direct profile search/chat, block và realtime inbox refresh.

Revision 2 chưa được triển khai. Chờ người dùng review/duyệt Plan trước khi sửa source hoặc database.

> **Cập nhật trạng thái:** câu trên mô tả thời điểm lập revision 2. Người dùng sau đó yêu cầu cập nhật Plan và triển khai code; trạng thái source hiện tại được ghi ở cuối tài liệu và Implementation Report.

## 10. Yêu cầu bổ sung — Privacy, Block, Timestamp và Chat Header (2026-11-17)

**Phạm vi:** Người dùng yêu cầu cập nhật Plan và triển khai code trong cùng lượt. Mục này audit baseline hiện tại và quyết định phạm vi; source implementation được ghi trong Implementation Report sau khi kiểm thử. Không thay đổi D-16.

### 10.1 Community và Stranger Inbox
- Tại thời điểm audit, `CommunityFeedScreen` (`features/social/presentation/screens/community_feed_screen.dart`) có shortcut riêng “Tin nhắn từ người lạ” và pending badge; `MessagingInboxScreen` cũng có lối vào Stranger Inbox. `MainNavigationShell` dùng social `CommunityScreen` bọc Community feed; `messaging/presentation/screens/community_screen.dart` là màn legacy riêng có tab Người lạ, không phải route active của shell. Revision này chỉ bỏ shortcut ở feed, giữ các screen/API.
- Thay đổi UI: bỏ shortcut riêng khỏi header feed; không xóa screen/API/repository/service. Giữ và làm rõ lối vào từ Messaging Inbox; giữ số pending/unread ở nơi phù hợp để không mất trạng thái.

### 10.2 Tin nhắn người lạ, privacy và block
- Backend hiện có `InboundMessagePolicy` (`EVERYONE`, `FRIENDS_ONLY`, `NOBODY`), `UserMessagingSettings`/`user_messaging_settings`, GET/PUT `/api/users/me/messaging-settings`; Flutter đã có `MessagingSettingsScreen` và repository methods. Không thêm persistence mới.
- `MessagingServiceImpl.openDirect` kiểm tra policy khi tạo cặp conversation canonical; người lạ hợp lệ tạo một `PENDING`. Query ordinary inbox chỉ lấy `ACCEPTED`, Stranger Inbox lấy `PENDING` recipient. `acceptMessageRequest` đổi trạng thái chính conversation đó; không tạo conversation thứ hai. `send` giới hạn tin mở đầu và recheck policy/block; accepted thread theo D-16 tiếp tục sau đổi policy/unfriend.
- Block hiện đã có `UserBlock`/`user_blocks`, `FriendshipServiceImpl.block`, `POST /api/users/{userId}/block`, repository Flutter `block`, và kiểm tra block trong open/send/friend-request policy. Stranger Inbox đã có menu chặn. Chat Detail còn thiếu menu/challenge xác nhận, điều hướng hồ sơ, gọi block API, khóa composer và cập nhật UI mà vẫn giữ history. `ChatEventListener` hiện phát event sau commit mà chưa recheck block; bổ sung gate để event mới không đến hai user sau khi block đã commit. Gửi/sửa block phải không tạo friendship, conversation hay bảng block mới.
- Quyền “bắt đầu mới” và “tiếp tục accepted thread” vẫn khác nhau; privacy chỉ chặn start theo D-16. Block luôn chặn cả hai hướng gửi mới và hiển thị realtime, giữ lịch sử hiện có.

### 10.3 Định dạng timestamp thống nhất
- Hiện `ChatScreen` format riêng theo thiết bị, `MessagingInboxScreen` cắt `DateTime.toString()`, legacy `CommunityScreen` hiển thị `.toString()`, còn Stranger Inbox không hiện thời gian. Không có formatter chung trong messaging và `intl` chưa được khai báo là dependency trực tiếp.
- Thêm một formatter/parser dùng chung trong feature messaging, định dạng `HH:mm dd-MM-yyyy`, timezone hiển thị Asia/Ho_Chi_Minh (UTC+07:00), zero padding. Dùng cho inbox accepted, Stranger Inbox, chat bubble và last-message time; thay mọi formatter local liên quan.
- REST `LocalDateTime` hiện không kèm offset; parser phải nhận biết timestamp có offset/Z so với wall-clock từ backend để không convert hai lần. WebSocket dùng cùng event DTO/parse helper. Không thay đổi `LocalDateTime` hoặc dữ liệu DB. Nếu API hiện đã gửi time như local Vietnam thì chỉ format các thành phần đó; nếu có offset thì normalize đúng một lần.

### 10.4 Explore user search
- `UserSearchScreen`, `MessagingRepository.searchUsers`, `GET /api/users/search`, `PublicUserServiceImpl` và batch relationship context đã có; Explore vẫn giữ tìm itinerary trong body nhưng AppBar chỉ có Notifications + avatar. Mở user search bằng icon cạnh Notifications, dùng lại screen/repository/model/action flags, không can thiệp `SearchBarPill`.
- Backend hiện tìm prefix trên handle/fullName. Substring giữa từ và accent-insensitive tiếng Việt chưa được bảo đảm; cần kiểm collation/query plan trên MySQL thật trước khi chọn index/normalization. Không tải toàn users hay thêm bảng mới. UI đang dùng public handle `@handle`; không expose login username/email.

### 10.5 Chat Detail header
- `ChatScreen` AppBar hiện chỉ có tên. `ConversationSummary.peer` đã chứa `PublicUserSummary.avatar`, fullName/handle; không cần gọi API riêng. Thêm header leading/title thành avatar tròn + tên ellipsis, cùng menu `...` cho xem `PublicProfileScreen` và chặn có xác nhận. Avatar tái dùng logic ảnh/placeholder/fallback của chat; dành constraints để title không tràn dưới menu.
- Giữ yêu cầu avatar hai phía/bubble/grouping ở Plan 05; header avatar là bổ sung độc lập.

### 10.6 File/API/DB và acceptance
- Flutter: `social/presentation/screens/community_feed_screen.dart`, `messaging/presentation/screens/messaging_inbox_screen.dart`, `messaging/presentation/screens/chat_screen.dart`, `messaging/presentation/screens/stranger_inbox_screen.dart`, `messaging/presentation/screens/community_screen.dart`, `explore/presentation/screens/explore_screen.dart`, `messaging/data/models/chat_message.dart`, `conversation_summary.dart`, `messaging/data/messaging_repository.dart`; thêm formatter utility và tests khi cần. Reuse route/profile/settings/search classes.
- Backend khi cần: `service/ChatEventListener.java`, `service/CommittedChatEvent.java`, call sites trong `MessagingServiceImpl`/`FriendshipServiceImpl`, tests realtime; các privacy/block services hiện hữu giữ là policy authority.
- APIs tái dùng: `POST /api/conversations/direct`, message request list/accept/decline, conversation list/messages/send, settings GET/PUT, `POST /api/users/{id}/block`, `GET /api/users/search`.
- Không cần DB change: privacy, stranger status và block entity/table đã tồn tại; timezone chỉ là presentation/parser. Cột/index search không được thêm nếu chưa đo query plan và duyệt migration riêng.
- Acceptance chi tiết gồm policy matrix, một canonical conversation qua accept, block giữa REST/realtime/friend request/history, format thời gian trên cả bốn surface, tìm user từ Explore nhưng itinerary search không đổi, title dài/ảnh lỗi/screen hẹp. Chi tiết testcase ghi tại Plan 08.

### Trạng thái triển khai — 2026-11-17

- [x] Community feed không còn shortcut riêng mở Stranger Inbox; đường vào và pending badge vẫn nằm trong Messaging Inbox.
- [x] Explore có action tìm người dùng cạnh Notifications, tái sử dụng `UserSearchScreen`/repository; tìm lịch trình không đổi.
- [x] Profile có lối vào Quyền riêng tư tin nhắn, dùng lại `MessagingSettingsScreen`, API và persistence hiện có.
- [x] Public profile và user search trả cờ additive `canContinueConversation` riêng với `canMessage`; chỉ true khi có accepted conversation còn hợp lệ. Search tra cứu theo batch để tránh N+1.
- [x] Chat Detail có avatar peer + menu `...`; profile mở từ conversation summary, block yêu cầu xác nhận, gọi API hiện hữu, khóa gửi và giữ lịch sử.
- [x] Backend event listener kiểm tra quan hệ block ngay trước khi phát event tới hai user; nếu đã block thì suppress event. Không thêm endpoint/table/schema.
- [x] Formatter/parser chung hiển thị `HH:mm dd-MM-yyyy` theo UTC+07, dùng cho chat, inbox, stranger inbox và legacy community list; test wall-clock `LocalDateTime`, UTC/Z, offset `+07` và zero-padding.
- [x] Pending message request count hiển thị trong Messaging Inbox; danh sách stranger hiển thị timestamp.
- [x] Backend service tests: 16 pass; thêm 1 MySQL test xác nhận tìm `nguyen%` khớp `Nguyễn Huệ`; Spring/JPA context pass trên MySQL 8.0.44 test schema. Flutter profile + messaging + community: 37 tests pass. Analyzer 14 file không có lỗi/warning; 13 info-only brace-style lints trong `public_profile_screen.dart`.
- [ ] Chưa chạy manual hai tài khoản trên emulator/điện thoại, kiểm tra block/reconnect thực qua WebSocket hoặc đổi avatar khi server đang chạy.
- [ ] Search user hỗ trợ tiền tố không dấu theo MySQL 8 test schema; tìm substring bắt đầu giữa tên chưa được triển khai vì cần đánh giá query plan/chi phí trên dữ liệu mục tiêu.
- [x] Không có migration/schema/table mới; response profile và search chỉ được mở rộng bằng field `canContinueConversation` additive.

## Revision — Quản lý hội thoại D-24 (đã bị D-25 thay thế)

Revision này từng mô tả hide/delete và privacy recheck sau unfriend. D-25 bên dưới thay thế các hành vi đó; phần này chỉ còn là lịch sử triển khai.

### Hành vi đã chốt

- Xóa cuộc trò chuyện là ẩn mềm cho principal hiện tại, độc lập với người còn lại. Không xóa vật lý conversation/message và không thông báo người kia.
- Khi có tin mới, hội thoại chỉ hiện lại ở bên có quyền thấy tin. Tin `recipient_visible=false` vẫn chỉ hiển thị cho sender và không phát event tới recipient.
- Sau unfriend, tin tiếp theo tái đánh giá privacy: `EVERYONE` chuyển cùng conversation canonical sang `PENDING` và hiển thị như stranger request; `FRIENDS_ONLY` lưu sender-only. Lịch sử cũ giữ nguyên visibility. Khi người nhận reply trên request hiển thị, cùng conversation được accept.
- Nếu thread từng accepted, API history vẫn giữ những tin cũ vốn recipient-visible; query theo từng message tiếp tục loại tin sender-only. Thread pending bị policy hạn chế không xuất hiện trong các list.
- Stranger badge chỉ đếm tin chưa đọc. Đọc conversation gọi read cursor Backend; dấu đỏ mất khi unread count về 0 dù request đã đọc vẫn còn trong danh sách.
- Legacy `NOBODY` được giữ trong DB nhưng được diễn giải như `FRIENDS_ONLY`; không cần backfill phá dữ liệu.

### Audit và triển khai

- `ConversationReadState` đã là composite per-user/per-conversation và có read cursor; dùng lại mapping đó thay vì tạo bảng participant state.
- Backend thêm nullable `conversation_read_states.hidden_at`, lọc inbox/request/unread theo viewer và `DELETE /api/conversations/{id}` (204) với membership check + invalidation riêng user xóa. Conversation/messages giữ nguyên.
- Khi gửi trên accepted conversation sau unfriend, cập nhật status/requester/recipient ngay trên canonical thread theo privacy hiện tại. Send response thêm `conversationStatus` và `recipientVisible` để Flutter hiện privacy notice và không báo đã gửi/đọc cho tin sender-only.
- Flutter mở rộng `MessagingRepository`, Inbox thường và Stranger Inbox: menu theo row cho profile/block/delete, xác nhận block/xóa, reload sau action. Stranger badge không hiện chỉ vì pending request đã đọc.
- Không thêm bảng hoặc framework migration. Local `ddl-auto=update` là cơ chế schema hiện có; production cần reviewed additive DDL.

### File/API và xác minh

- Backend: `ConversationReadState`, `ConversationRepository`, `MessageRepository`, `MessagingService`, `MessagingServiceImpl`, `ConversationController`, `MessageResponse`; tests service trong `MessageRequestServiceTest`.
- Flutter: `messaging_repository.dart`, `messaging_inbox_screen.dart`, `stranger_inbox_screen.dart`, `chat_message.dart`, `chat_screen.dart`; tests Inbox/model trong `test/features/messaging`.
- Manual hai tài khoản/thiết bị chưa được xác minh: xóa A giữ B, privacy/unfriend, Stranger badge/read sync, và menu block/profile.
