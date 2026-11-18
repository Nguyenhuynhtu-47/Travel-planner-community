# 05 — Mobile UI và kiến trúc

**Cập nhật:** 2026-11-17. Tuân thủ Flutter feature structure hiện có, shared core/theme, DESIGN.md, CODEBASE_GUIDE và coding rules.

## Addendum — Block refresh và privacy-denied chat (2026-11-17)

Khi mở chat thật hoặc app quay lại foreground, tải danh sách block qua API hiện có trước khi bật composer; menu hiển thị “Bỏ chặn người dùng” cho peer đã block. Sau bỏ chặn, refresh direct-conversation permission từ backend. Profile AppBar có lối vào quyền riêng tư tin nhắn, đồng thời giữ nút trong nội dung hồ sơ; cả hai mở cùng `MessagingSettingsScreen`. Nếu mở chat mới bị privacy từ chối, điều hướng tới preview chat chỉ đọc có thông báo chung; không ghi conversation hay message. Với request pending chưa có opener mà policy đã đổi, chat hiển thị lý do không thể bắt đầu.

Mặc định `EVERYONE` chỉ áp dụng cho user mới/chưa lưu lựa chọn; không backfill hay ghi đè setting hiện hữu. `EVERYONE` cho người lạ tạo request trong Stranger Inbox, sender theo giới hạn opener đã duyệt.

## 1. Community

Giữ Community feed-first, tab bar 5 mục và routes hiện có. Trên feed, giữ shortcut Messages và Notifications; thêm badge Friends/Invites/Requests/Stranger requests theo design đã thống nhất. Không thêm bottom tab/hub trùng. Notifications hiện là empty state do chưa có backend notification history; không giả làm dữ liệu thật.

Trong messaging screen hiện có, tổ chức inbox, friends và friend requests; bổ sung Stranger Inbox như filter/tab/section theo kiến trúc đang dùng. Friend rows/request rows có thể điều hướng tới public profile và expose actions theo trạng thái hiện hữu. Không tạo repository/notifier song song cho cùng domain.

## 2. Chat screen

Bổ sung/hoàn thiện item chat để có avatar (ảnh + fallback initials), chiều gửi/nhận dễ phân biệt, timestamp, trạng thái pending/sent/read nếu contract hiện tại hỗ trợ. UI có connecting, connected, reconnecting, offline, failed rõ ràng. Không hiện “đang chờ đồng bộ” vô hạn: có affordance retry; khi REST thành công vẫn cho xem/gửi theo khả năng backend và reconcile event.

Tôn trọng optimistic message và idempotency key đang có; khi response REST và STOMP event cùng message ID/sequence chỉ render một item. Phân trang lịch sử bằng cursor/sequence. Không tự coi delivered/read nếu server không trả xác nhận.

## 3. Ownership và state

- Khắc phục stale banner: lúc listener bắt đầu, đọc `currentStatus` rồi subscribe; tránh race bằng API stream có initial snapshot hoặc subscribe-then-snapshot có quy tắc version.
- Không tạo WebSocket client mới cho mỗi mở profile chat nếu app đã có owner dùng chung; hoặc nếu scope theo route thì dispose chắc chắn sau pop. Tránh connect hai client cho một phiên.
- Ngăn callback sau dispose; hủy subscriptions/timers; xử lý logout, account switch, token expiry và app lifecycle.
- Community badges dùng notifier/repository sẵn có. Load đầu, pull-to-refresh, app resume, quay lại route và event invalidation sẽ refetch authoritative counts.
- Friend request và stranger request badge tách riêng; unread total là tổng tin, unread conversation count là số thread.

## 4. Thành phần và design system

Tái sử dụng ApiClient, auth/session provider, avatar widgets, loading/error/empty widgets, spacing/color/typography tokens và route conventions. Không hardcode màu/spacing khi token có sẵn. Hỗ trợ semantics labels, contrast, text scaling, target tap khoảng 48 logical px theo chuẩn dự án. Motion ngắn, không làm trạng thái kết nối chỉ biểu đạt bằng màu.

## 5. Màn hình và hành vi

- Community feed: badge không nhấp nháy sai khi chưa tải; lỗi count không xóa feed, thể hiện trạng thái theo pattern chung.
- Inbox: unread marker + thời điểm tin cuối; empty/loading/error states; cập nhật sau read/send.
- Friends/Invites: received/sent, accept/decline/cancel; mở profile; tránh hiện CTA không hợp lệ.
- Stranger Inbox: badge riêng, người gửi/context/time/preview; mở request; Accept đưa vào inbox chính; Decline/Block xác nhận theo UX; sau action refetch authoritative lists/counts.
- Chat: nếu pending, thể hiện trạng thái và nút accept/decline ở recipient; composer tuân theo rule server. Khi bị block/declined, khóa composer và giải thích.
- Notifications: giữ empty state trung thực đến khi có API/storage.

## 6. Testability

Inject realtime client/provider và repositories; fake clock/timers/network để kiểm thử reconnect, duplicate events, token expiry và dispose. Không phụ thuộc thiết bị thật trong widget tests. Base URL: emulator Android mặc định `10.0.2.2:8080`; thiết bị thật cần LAN IP hoặc README `adb reverse`; luôn xác nhận cả hai về cùng backend.

## Addendum — Navigation revision 2 (plan-only)
Xem plan 12 §9. Community giữ feed, Tin nhắn và Bạn bè/Lời mời; bỏ shortcut Tin nhắn người lạ khỏi header. Stranger Inbox vẫn mở bên trong Inbox thường, giữ badge, screen và behavior. Explore AppBar thêm icon user search cạnh Notifications; `SearchBarPill`/ExploreNotifier vẫn chỉ tìm lịch trình. Không thêm bottom tab.

Mở `UserSearchScreen` hiện có qua Explore action, reuse auth/repository. User list hiển thị avatar, fullName, public `@handle` (không login username), relation status và Add/cancel/accept/message actions. Inbox search giữ scope là conversations viewer đã có; không dùng nó để tìm user mới, không tìm message history.

Profile > Cài đặt là canonical entry cho `MessagingSettingsScreen`; reuse GET/PUT persistence hiện tại. Community header shortcut settings có thể giữ làm shortcut vào cùng screen. `PublicProfileScreen` cần CTA dựa trên quyền start-new hoặc accepted-thread continue riêng; nếu không được phép, thông báo chung và không tiết lộ block state. Backend authorization là nguồn quyết định.

## Addendum — Chat Interface: avatar hai phía và nhóm tin (plan-only, 2026-11-17)

**Cập nhật triển khai:** Đã thực hiện ở `ChatScreen`; widget tests cho avatar hai phía, fallback peer, grouping, đổi avatar hồ sơ và màn hình hẹp đã pass. Kiểm tra thiết bị thật/emulator vẫn cần thực hiện thủ công.

## Addendum — Header actions, privacy navigation và unified time (2026-11-17)
Kế hoạch mới tại Plan 12 §10: `ChatScreen` AppBar dùng một title row gồm avatar peer 36px, tên ellipsis và `PopupMenuButton` bên phải. Menu mở public profile hoặc dialog xác nhận block. Sau block API success, giữ tin cũ nhưng đặt local blocked state, khóa composer, hiện trạng thái; lỗi giữ nguyên state và báo lỗi. Avatar header dùng `ConversationSummary.peer.avatar`, không request profile riêng.

Explore AppBar thêm icon tìm người dùng ngay cạnh notification; mở `UserSearchScreen` đã có với `AuthNotifier` và `MessagingRepository`, còn itinerary search giữ nguyên. Bỏ shortcut Stranger trực tiếp trên Community feed header; Inbox thường tiếp tục điều hướng Stranger Inbox và badge không bị mất.

Dùng formatter/parser messaging duy nhất cho ChatScreen, Inbox thường, Stranger Inbox và legacy Community lists. Display target `HH:mm dd-MM-yyyy`, Asia/Ho_Chi_Minh UTC+07, có zero padding. `LocalDateTime` backend không zone được diễn giải như wall-clock Vietnam; timestamps có zone normalize một lần. Không dùng `toLocal().toString()`/substring hoặc formatter trùng.

### Audit chính xác
Widget chịu trách nhiệm là `messaging/presentation/screens/chat_screen.dart`: `ListView.builder` tạo bubble cho từng message, `_messageAvatar` tạo avatar. Nhận diện own/peer đang dựa trên `message.senderUserId == _me`. Hiện incoming row có avatar trái + bubble; outgoing chỉ căn bubble phải nên thiếu avatar mình. `_messageAvatar` ưu tiên `ChatMessage.senderAvatar`, chỉ fallback về `AuthNotifier.currentUser['avatar']` khi sender là mình; peer chưa fallback về `widget.conversation.peer.avatar`. Optimistic message chỉ đặt senderUserId/name, chưa có senderAvatar. `ChatMessage.fromJson` đọc `senderUserId`, `senderAvatar`, `createdAt`; `MessagingServiceImpl.messageResponse` tạo avatar từ User hiện tại của sender và cùng `MessageResponse` được REST page/event dùng. Profile peer có `avatar` trong `PublicUserSummary`; profile hiện tại nằm trong `AuthNotifier.currentUser`. Chưa có chat bubble/avatar component dùng chung riêng; không cần tạo subsystem chat mới.

### Bố cục đề xuất
Dùng cùng một `MessageRow` nội bộ trong `ChatScreen` cho hai chiều: row chiếm chiều ngang sẵn có, own đặt bubble rồi avatar ở mép phải, peer đặt avatar rồi bubble ở mép trái. Chốt kích thước avatar/spacing cố định theo design token (đề xuất avatar 28–32 logical px, gap 8 px) và tính max bubble width từ chiều rộng thực còn lại sau padding/avatar/gap; không lấy tỷ lệ toàn màn hình rồi cộng avatar khiến overflow. Bubble text wrap và giữ timestamp/status bên trong bubble như hiện tại. Hạn chế layout phụ thuộc `MediaQuery` ngoài giới hạn max width; test narrow phone và text scaling.

Nhóm liên tiếp theo cùng `senderUserId`, cùng ngày và khoảng cách thời gian ngắn (đề xuất 2 phút; giá trị cần chốt khi implement). Giữ mỗi message là item dữ liệu độc lập để pagination, optimistic reconciliation, retry, receipt và sequence không đổi; chỉ nhóm cách trình bày: gap nhỏ giữa bubble cùng nhóm, gap lớn hơn khi sender/ngày đổi. Hiển thị một avatar ở cuối nhóm, căn đáy avatar với bubble cuối (pattern quen thuộc của Messenger), các row trước giữ slot trống cùng kích thước để mép bubble thẳng hàng. Mỗi nhóm mới của người kia/mình có avatar tương ứng ở cạnh ngoài. Không lồng nhiều bubble vào một model hoặc gộp nội dung làm mất message identity/status. Tin quá xa nhau trong cùng sender vẫn tách nhóm.

### Avatar và cập nhật ảnh
Tạo helper/widget nội bộ có `url`, placeholder/loading, error fallback và kích thước cố định; ảnh hình tròn, `BoxFit.cover`. Own avatar lấy `AuthNotifier.currentUser['avatar']` làm nguồn hồ sơ hiện tại, kể cả optimistic message; peer lấy `message.senderAvatar`, fallback `conversation.peer.avatar`, rồi placeholder mặc định. Với thay đổi avatar khi đang ở màn hình: own profile update phải làm UI rebuild/cache URL mới; peer avatar mới được phản ánh khi REST/event có URL mới hoặc khi tải lại conversation. Chưa có avatar-change realtime event trong contract đã audit, nên không hứa cập nhật tức thời giữa hai client ở revision này. Nếu URL giữ nguyên nhưng nội dung ảnh thay đổi, implementation cần dùng cache policy/invalidation phù hợp, không thêm polling.

### Giới hạn phạm vi
Ưu tiên sửa `chat_screen.dart` và tái sử dụng model/contract có sẵn. Chỉ sửa `chat_message.dart` nếu optimistic/avatar refresh contract yêu cầu; chỉ sửa `conversation_summary.dart`/repository nếu thiếu peer fallback data. Không thêm package, endpoint, bảng hoặc chat UI độc lập nếu không có bằng chứng source/API thiếu dữ liệu.

## Revision — Quản lý hội thoại và Stranger badge (2026-11-18)

- Inbox thường và Stranger Inbox dùng menu ba chấm theo từng hàng, chỉ gồm xem profile và chặn có xác nhận. Không có mục xóa/ẩn conversation.
- Pending recipient có thể xem nội dung yêu cầu nhưng ChatScreen không gọi mark-read cho đến khi Accept thành công; Accept giữ màn hình ở chat thường và ẩn action bar request.
- Menu có vùng nhấn riêng; mở profile tái sử dụng `PublicProfileScreen`, block tái sử dụng endpoint hiện có, delete gọi repository API và tải lại list.
- Stranger badge chỉ hiện unread count từ Backend. Pending request đã đọc không giữ dấu đỏ; ChatScreen tiếp tục dùng read-cursor API hiện có.
- Mở rộng screen/repository hiện tại; không thêm dependency hoặc hệ thống UI/state mới.
