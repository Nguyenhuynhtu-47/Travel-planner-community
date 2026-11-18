# 08 — Kiểm thử và hồi quy

**Cập nhật:** 2026-11-17. Các phần unit/widget đã chạy được liệt kê trong Implementation Report; DB/API/runtime matrix vẫn còn chờ.

## Revision — Stranger messaging theo D-23 (2026-11-18)

- EVERYONE: requester gửi nhiều tin; recipient thấy chúng trong Stranger Inbox; recipient reply tự accept cùng conversation và chuyển sang inbox thường.
- FRIENDS_ONLY: stranger gửi nhiều tin, requester đọc được lịch sử của chính mình kèm privacy notice; recipient không nhận message qua list/detail/REST/WebSocket/count/preview.
- Sau khi friendship accepted, history sender-only vẫn bị lọc khỏi recipient kể cả reload/pagination; tin mới gửi khi đã là bạn được hiển thị bình thường và không có privacy notice.
- Chuyển policy khi request đang mở, mở lại app, REST pagination, reconnect WebSocket, unread counters, read cursor và public-profile CTA phải giữ cùng visibility rule.
- Settings PUT với row mới `@MapsId` dùng persist; GET/PUT round-trip cho EVERYONE/FRIENDS_ONLY; row cũ vẫn đọc được.
- UI chỉ render hai policy; legacy NOBODY không còn là radio option.

## Bổ sung kiểm thử block và privacy (2026-11-17)

- User chưa có messaging setting: backend/Flutter mặc định `EVERYONE`; legacy `NOBODY` phải tương thích như `FRIENDS_ONLY`.
- Block rồi rời và mở lại chat: menu phải là “Bỏ chặn người dùng”, composer khóa; unblock thành công làm mới quyền gửi.
- Privacy từ chối mở chat mới từ hồ sơ: hiển thị preview chỉ đọc, thông báo tổng quát, không tạo conversation và không tiết lộ trạng thái block.
- Policy đổi khi request pending chưa có opener: người gửi thấy thông báo inline và không gửi được.

## 1. Backend unit/service

- Friendship: self request, duplicate, incoming/outgoing, accept/decline/cancel, block/unblock, inactive users, concurrency reverse requests.
- Privacy matrix theo D-23: EVERYONE/FRIENDS_ONLY × friend/stranger × new/pending/accepted × blocked/unblocked. Legacy NOBODY chỉ cần kiểm tra tương thích, không phải lựa chọn giao diện.
- Message requests: người gửi pending được gửi nhiều tin; recipient chỉ xem/accept/decline khi policy cho phép và có tin nhìn thấy; trả lời tự accept; repeated actions idempotent/conflict; decline/resend cooldown; legacy conversation accepted.
- Message: participant enforcement, sequence ordering, cursor monotonicity, idempotency key, validation/rate cap, privacy/block race, account inactive.
- Unread: count messages khác sender; read cursor; unread conversations là distinct thread; empty/large history pagination không trùng.
- Event: publish chỉ sau commit; rollback không phát; post-commit send failure không rollback stored message.

## 2. API/security integration

- Anonymous read/mutation behavior theo controller rules; JWT missing/expired/disabled/banned.
- Không giả mạo sender/participant; cross-user conversation/history/read/request access trả lỗi an toàn.
- WebSocket CONNECT bearer missing/invalid/expired, Origin config, SUBSCRIBE allowlist, SEND reject, reconnect, session cap 5 và disconnect cleanup.
- DTO/error contract và page bounds; no N+1 query trên inbox/counts.

## 3. Database integration

Dùng disposable MySQL tương thích, không DB người dùng. Áp dụng migration trên snapshot, kiểm constraints/FKs/indexes/legacy rows, rollback/restore. Test concurrent conversation open, friendship requests, accept-vs-decline, block-vs-send, sequence allocation và duplicate idempotency. Kiểm query plan với volume gần dự kiến. Ghi chính xác MySQL/version/schema/DDL/result; không dùng H2 làm bằng chứng tương đương MySQL locking/index behavior.

## 4. Flutter unit/widget

- Client tạo URL từ emulator/LAN config; CONNECT token không log; initial currentStatus không mất; reconnect timer không nhân đôi; dispose/route pop/logout/account switch dọn socket/subscriptions.
- Không có banner disconnected giả khi socket connected; transitions connecting→connected→reconnecting→offline→connected.
- REST response và STOMP event cùng message không render trùng; pagination giữ thứ tự; optimistic failure retry/idempotency.
- Avatar image failure fallback; timestamps/own-vs-peer/status semantics; accessibility/text scaling.
- Feed/inbox/friend/stranger badges: REST count chính xác, invalidate/refetch; lỗi badge không phá feed; resume/route return refresh.
- Accept/decline/block cập nhật đúng thread/list/badge; private data không rò qua cache khi đổi account.

## 5. Manual two-device matrix

1. ADB hiện nhận một Android device và một emulator. Chưa cài/chạy app do chưa xác định DB/backend an toàn. Khi có test backend, xác nhận `/api/health` và marker cùng deployment.
2. Đăng nhập hai user; log state + CONNECT/SUBSCRIBE success, không log JWT.
3. Gửi A→B và B→A; đối chiếu REST message id/sequence, STOMP event, UI timestamp/read/unread.
4. Tắt mạng một client, gửi tin từ peer, reconnect; xác nhận REST history catch-up không trùng.
5. Thử token expiry/logout/account switch, app background/foreground, router profile→chat/pop nhiều lần; xác nhận session count không tăng vô hạn.
6. FRIENDS_ONLY/EVERYONE, request accept/decline, block/unblock và friend request/badges theo D-23; legacy NOBODY được kiểm tra tương đương FRIENDS_ONLY.
7. Đổi API_BASE_URL sai để xác nhận chẩn đoán hữu ích; kiểm firewall/VPN/Wi-Fi và backend logs.

## 6. Tiêu chí hoàn tất

Lưu command, environment/device, commit, kết quả, failures/fixes. Báo cáo không được ghi PASS nếu chỉ phân tích code. Test hai thiết bị và schema MySQL phải có evidence riêng; mới xác nhận ADB thấy device/emulator, chưa có test app-to-app.

## Addendum — Acceptance Community Navigation/Search Revision 2 (plan-only)

### Navigation và mục đích search
- Community header không còn shortcut Stranger Inbox; từ Messaging Inbox vẫn mở Stranger Inbox, danh sách/badge/actions không mất.
- Explore AppBar có user search cạnh Notifications; itinerary search bar/result/filter đang có vẫn hoạt động độc lập.
- User discovery tìm bạn hiện tại và nonfriend; Inbox search chỉ tìm conversation của viewer đã tải, không trả user chưa có chat và không search toàn bộ message history. Không tải toàn bộ users về Flutter.
- Profile settings có entry tới existing messaging privacy screen; load/update/reopen xác minh persistence.

### Public profile và permission matrix
- A chưa friend B + B EVERYONE: profile CTA mở canonical `PENDING` request; A chỉ gửi opener; B thấy trong Stranger Inbox; accept biến cùng conversation sang accepted inbox.
- FRIENDS_ONLY: sender giữ được tin sender-only; recipient không đọc được qua detail, list, WebSocket, read cursor hay unread API. Sau khi kết bạn, tin cũ vẫn ẩn với recipient và tin mới được hiển thị.
- EVERYONE: nhiều tin stranger hiện trong Stranger Inbox; recipient trả lời thì cùng thread tự thành accepted và đi vào inbox chính.
- Accepted thread tiếp tục sau thay đổi privacy/unfriend; block hoặc inactive vẫn chặn send/receive dù thread tồn tại; self-chat luôn reject.
- Policy đổi sau khi PENDING đã tạo không tự xóa/decline request; recipient vẫn accept/decline. Declined retry sau 1 ngày phải recheck policy mới.
- Không leak blocked user identity qua profile/search/error response; API authorization luôn được test trực tiếp, không chỉ kiểm tra button visibility.

### User search / Vietnamese / persistence
- Prefix incremental fullName và public handle (không login username/email); test dấu/không dấu với dữ liệu tiếng Việt, Unicode normalization, hoa thường, ký tự escape, minimum/maximum length, ACTIVE filter, stable sort, page bounds, no duplicates.
- Test debounce, paging, stale response cancellation, clear query, loading/empty/error/retry, duplicate action, relation status self/sent/received/friend/blocked.
- Kiểm `EXPLAIN` và query latency ở MySQL với volume đại diện trước khi duyệt `full_name_search` column/index hoặc ngram. Nếu migration chọn, test backfill, write synchronization, rollback và không mất users.
- Inbox conversation filter test chỉ trên existing membership/loaded page; nếu server-side được chọn, test viewer isolation và peer partial search.

### Realtime/device
- Event invalidation refresh đúng badge và danh sách khi recipient accept/decline hoặc sender gửi request; pending count và unread count không bị trộn.
- Manual hai account trên emulator và máy thật: mọi scenario ở plan 12 §9.5, đổi settings giữa session, refresh/reconnect, kiểm cùng conversation chuyển Stranger→Inbox; cả hai device cùng backend.

## Addendum — Chat avatar, grouping và layout acceptance (plan-only, 2026-11-17)

**Đã kiểm chứng tự động:** 12 tests thuộc `flutter test test/features/messaging` pass; `flutter analyze --no-pub` trên `chat_screen.dart` và `chat_screen_test.dart` không có issue. Manual acceptance bên dưới chưa chạy.

## Addendum — Additional Requirements acceptance (2026-11-17)
- Community feed header không còn shortcut Stranger; từ Inbox vẫn mở Stranger Inbox, pending/unread count không mất.
- Policy EVERYONE/Friends/Nobody: stranger new direct denied/allowed đúng policy; allowed creates one PENDING; ordinary inbox excludes it; recipient sees contents and accepts same conversation; repeat/open/send does not create duplicate. Accepted conversation continues per D-16 after policy change/unfriend; block overrides.
- Settings GET/PUT persists after navigation/restart; block action requires confirm; cancel confirmation makes no request; success persists/reloads; both users cannot direct/open/send or send friend request through blocked pair; message history remains; no MESSAGE_CREATED event delivered after block state is committed. Verify listener race with block transaction.
- Chat header peer avatar source, circle placeholder/error, long title ellipsis, 320px/narrow layout, menu profile route, block confirm/success/error and composer state.
- Timestamp golden/unit tests: `14:55 17-11-2026`, `09:30 18-11-2026`, `20:05 01-12-2026`; device TZ differs from Asia/Ho_Chi_Minh; parse zone-less LocalDateTime and explicit `Z/+07:00`; verify no double conversion and unchanged DB/API values.
- Inbox, Stranger Inbox, legacy Community, chat bubble and latest message show same format; null timestamp does not crash.
- Explore user-search action adjacent to notifications; opens existing UserSearchScreen; add/cancel/accept/message actions and existing API reused; itinerary SearchBar behavior unchanged. Backend accent/no-accent and substring test only after query/collation behavior is verified; do not claim unsupported behavior.
- Existing message bubble tests continue: both sender avatars, grouping, REST/WebSocket sender identity, pagination/realtime reconciliation, narrow and long content.

### Widget/model tests
- Own message có avatar phía phải lấy từ Profile/AuthNotifier; thiếu avatar hiển thị placeholder mặc định, không lấy avatar peer.
- Peer message có avatar phía trái lấy từ senderAvatar; khi thiếu dùng `ConversationSummary.peer.avatar`; khi cả hai thiếu hoặc URL lỗi dùng placeholder.
- REST `ChatMessage.fromJson`, REST pagination, send response và WebSocket event giữ senderUserId/avatar/createdAt thống nhất; optimistic own message hiển thị đúng avatar trước server ack rồi reconcile thành cùng một message, không duplicate.
- Ảnh loading/error, URL rỗng, kích thước cố định, circle crop/BoxFit.cover, không đổi width bubble khi ảnh lỗi.
- Tin ngắn/dài nhiều dòng, multiline và narrow viewport: bubble không overflow, không bị avatar che, own/peer giữ đúng hai mép và khoảng cách.
- Cùng sender trong time window: gap nhỏ, avatar một lần ở cuối group và căn đáy; sender/date/time-window đổi: group/avatar mới, gap lớn hơn. Sequence/order/status per-message không bị mất.
- Tải thêm history ở đầu list giữ scroll offset; tin mới REST/realtime và optimistic send vẫn đặt đúng nhóm sau khi sort/reconcile.
- Profile avatar đổi URL trong phiên làm own avatar rebuild; peer avatar đổi được hiển thị sau khi response mới/reload. Không kỳ vọng realtime đổi ảnh tức thời nếu không có event contract.

### Manual acceptance
Kiểm tra ít nhất: own one message; peer one message; nhiều tin liên tiếp từng phía; thay phiên; nội dung dài nhiều dòng và ngắn; cuộn/tải lịch sử cũ; nhận realtime; đổi avatar own/peer rồi refresh hoặc nhận message tiếp theo. Thực hiện trên emulator và điện thoại với chiều rộng khác nhau, ghi ảnh/screen recording và kết quả. Xác nhận REST-loaded và WebSocket-delivered của cùng sender có avatar giống nhau; lỗi ảnh không làm bubble nhảy kích thước.

## Addendum — Acceptance quản lý conversation (D-24, superseded by D-25)

- D-25 removes delete/hide conversation; historical cases above are no longer acceptance criteria.
- After unfriend, accepted conversation remains ACCEPTED and stays in both eligible inboxes; both users can send without request/duplicate thread.
- Pending recipient opens detail: sequence/read cursor and unread badge remain unchanged until Accept.
- Accept status change and recipient read cursor update commit atomically; rollback both on read-state failure; emit acceptance/read events only after commit.
- Decline does not add requester messages to recipient Inbox/history/realtime; sender retains them; retry after one day reuses canonical conversation and new visible messages only.
- Mở Stranger Inbox và đọc tin gọi read-cursor API; badge đỏ đếm unread, mất khi mọi request đã đọc, còn nếu một request khác chưa đọc; tin mới làm badge xuất hiện lại.
- Inbox and Stranger Inbox menus contain only profile/block; ellipsis hit area does not open Chat Detail; block confirmation cancel has no API effect.
- Block matrix: blocked viewer receives not-found/no rows for target profile, search, posts, itineraries and chat history; blocked interaction denied through REST and WebSocket; unblocking does not restore friendship or mutate conversation status. Manual two-device/runtime remains separate.
