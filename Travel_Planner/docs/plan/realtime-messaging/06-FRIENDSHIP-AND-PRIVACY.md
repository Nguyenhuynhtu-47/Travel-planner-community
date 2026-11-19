# 06 — Friendship, privacy và message requests

**Cập nhật:** 2026-11-18. D-25 là semantics hiện hành; phần D-16/D-23/D-24 phía dưới chỉ là lịch sử khi không mâu thuẫn.

**D-25:** Accept là trạng thái toàn Conversation, chỉ recipient accept; mở detail không mark-read. Accept và read cursor được commit nguyên tử. Decline giữ tin cho sender nhưng ẩn với recipient. Accepted thread giữ nguyên sau unfriend/privacy changes. Block pair chặn nội dung/tương tác trên mọi API và realtime nhưng không xóa history; unblock không tự thay đổi friendship/status. Inbox menus không có delete/hide.

## Quyết định lịch sử — D-23 (được D-25 điều chỉnh)

- Tài khoản mới mặc định `EVERYONE`. Stranger gửi được nhiều tin; recipient thấy trong Stranger Inbox. **D-25 supersedes:** chỉ nút Accept của recipient chuyển conversation sang accepted; reply không tự accept.
- Với `FRIENDS_ONLY`, stranger vẫn gửi được nhiều tin. Các tin được lưu sender-only; recipient không đọc được trong inbox, request list, history, preview, unread count, WebSocket hoặc read cursor. Sender thấy tin của mình và banner giải thích privacy.
- Khi kết bạn, tin sender-only cũ vẫn ẩn recipient; tin mới sau khi hai bên là bạn hiển thị bình thường. Block vẫn chặn hai phía.
- UI chỉ có `EVERYONE` và `FRIENDS_ONLY`. Giá trị `NOBODY` còn lưu ở các row cũ được backend xử lý như `FRIENDS_ONLY` để không làm hỏng dữ liệu và không tạo policy mà UI không còn cung cấp.
- Backend dùng `messages.recipient_visible` và lọc trong query trước pagination. Schema dev thêm cột qua `ddl-auto=update`, không reset dữ liệu hoặc thêm bảng.

## Điều chỉnh ngày 2026-11-18 — Sau khi hủy kết bạn (đã bị D-25 thay thế)

- Conversation canonical và lịch sử cũ vẫn được giữ. Tin mới sau khi friendship bị hủy phải xét lại trạng thái bạn bè và privacy hiện tại.
- Với `EVERYONE`, thread cũ chuyển thành `PENDING` request trong cùng conversation; người nhận thấy tin mới ở Stranger Inbox. Khi recipient reply, thread trở lại `ACCEPTED`.
- Với `FRIENDS_ONLY` (gồm legacy `NOBODY`), tin mới lưu sender-only; recipient không nhận nội dung, event, unread hoặc inbox entry. Các tin lịch sử cũ không bị phân loại lại.
- Nếu thread đã có lịch sử accepted, API history vẫn trả các tin cũ vốn recipient-visible; query per-message tiếp tục loại tin sender-only. Thread pending bị hạn chế không xuất hiện trong Inbox/Stranger Inbox.
- Block/inactive vẫn chặn send. Không tạo conversation trùng.

## 1. Hai quan hệ khác nhau

Friendship hiện là trạng thái quan hệ user-user (PENDING/ACCEPTED/REJECTED). Follow là quan hệ một chiều độc lập và không cấp quyền nhắn tin trừ khi service policy nói rõ. Message request là trạng thái tiếp nhận một cuộc trò chuyện; không dùng friendship row để giả lập stranger inbox.

## 2. Hiện trạng policy và settings (snapshot D-16, được D-23 thay thế)

- `EVERYONE` là mặc định hiện tại nếu user chưa có row (D-22); setting đã lưu không đổi. `UserMessagingSettings` lưu lựa chọn theo user. GET/PUT `/api/users/me/messaging-settings`, service, repository và Flutter `MessagingSettingsScreen` còn trong source.
- `MessagingSettingsScreen` hiện được mở từ Community headers (active feed và legacy messaging Community); Profile settings chưa có đường vào privacy messaging. Do đó phần persistence/API không bị mất, nhưng vị trí hiện tại khiến chức năng khó phát hiện.
- `canMessage` được dùng để quyết định bắt đầu chat mới. `EVERYONE` với nonfriend tạo `PENDING` Stranger Inbox request và sender có thể gửi nhiều tin chờ; chỉ recipient accept tường minh mới chuyển thành accepted.
- `FRIENDS_ONLY` cho bạn bè bắt đầu conversation mới; nonfriend không được. `NOBODY` chặn mọi conversation mới, kể cả giữa bạn bè.
- Accepted conversation dùng `canContinueConversation`: vẫn có thể nhắn sau policy change hoặc unfriend nếu hai account ACTIVE và không block. `send` revalidate membership/status/block. Vì vậy không đúng khi nói policy được check như start permission trên mọi tin accepted.
- Block kiểm tra hai chiều, xóa friendship nhưng giữ conversation/message history và chặn gửi/nhận. Request đã tồn tại giữ lifecycle theo D-16.
- Đây là semantics D-16 đã duyệt; revision 2 chỉ cần biểu diễn rõ trên profile/UI và giữ nguyên server authorization.

## 3. Ma trận hành vi D-16 (lịch sử, được D-23 thay thế)

| Tình huống | FRIENDS_ONLY | EVERYONE | NOBODY |
|---|---|---|---|
| Bạn bè bắt đầu chat mới | Cho phép/accepted | Cho phép/accepted | Chặn chat mới |
| Người lạ bắt đầu chat mới | Chặn | Tạo pending request ở Stranger Inbox | Chặn |
| Tiếp tục accepted thread | Cho phép | Cho phép | Cho phép |
| Bên bị block gửi/nhận | Chặn | Chặn | Chặn |

Đoạn ma trận trên là snapshot D-16 đã bị D-23/D-25 thay thế. Theo D-25, accepted conversation tiếp tục cho tới khi block/account inactive; `EVERYONE` cho phép nhiều tin trong Stranger Inbox trước explicit accept. Declined request giữ lịch sử requester-side, tin cũ bị ẩn recipient-side, và retry sau một ngày dùng lại conversation canonical.

## 4. Friendship request flows

Incoming request: PENDING → accept thành ACCEPTED hoặc decline thành REJECTED. Outgoing: cancel nếu còn pending. Friend badge chỉ đếm incoming PENDING của user hiện tại. Chống gửi trùng pair, race accept/decline, self-request, inactive/blocked accounts. Khi unfriend, lịch sử chat được bảo toàn; quyền tiếp tục thread theo quyết định privacy đã chốt.

## 5. Block và quyền truy cập

Block phải thắng friendship/privacy và chặn open/new/send theo cả hai hướng. API detail/history cần quyết định mức truy cập lịch sử sau block; giữ dữ liệu không có nghĩa tiếp tục cho phép giao tiếp. Không xóa message. Quy tắc unblock không tự khôi phục friendship hoặc tự accept request cũ trừ khi product quyết định rõ.

## 6. API/state invariants cần test

- Mỗi canonical user pair không tạo duplicate friendship/conversation ngoài chủ đích.
- Request sender không thể tự accept; recipient chỉ xử lý request pending đúng thread.
- Concurrent reverse request, accept/decline và block/send có kết quả xác định qua transaction/locking.
- Legacy conversations được coi accepted khi rollout để giữ tương thích.
- Client UI chỉ là affordance; service kiểm lại policy, status, participants, block trên từng mutation.

## Addendum — Friend discovery tách khỏi messaging privacy
Tìm theo fullName/public handle, không dùng login username/email. Người chưa kết bạn được tìm và gửi friend request mà không cần chat trước. Backend vẫn kiểm tra self, ACTIVE, relation/request, block và quyền mutation. Batch relationship context để tránh N+1; xem plan 12.

## Addendum — Revision 2: start-new, continue-existing và access path (plan-only)

- Public profile/search response hiện chỉ có `canMessage`, mô tả khả năng start; không có riêng `canContinueConversation`/existing accepted-thread state. `PublicProfileScreen` chỉ vẽ nút Nhắn tin khi `canMessage=true`, dù `openDirect` có thể trả thread cũ accepted và backend cho phép tiếp tục. Kế hoạch thêm additive flags, giữ `canMessage` alias trong giai đoạn tương thích, và dùng batch query cho result page.
- UI phải show Nhắn tin khi người xem có quyền bắt đầu mới hoặc thread accepted có thể tiếp tục. Khi không có quyền mới, giải thích tổng quát; không leak block identity. API/service vẫn là enforcement.
- Chuyển canonical entry point settings vào Profile > Cài đặt > Quyền riêng tư tin nhắn và reuse screen/API/storage hiện tại. Có thể giữ shortcut Community mở cùng route.
- Privacy transition: new starts/retries luôn theo policy mới; accepted existing thread tiếp tục theo D-16; PENDING request đã tạo hợp lệ vẫn recipient-actionable; block chặn mọi communication. `FRIENDS_ONLY` cho bạn bè khởi tạo mới; `NOBODY` chặn new thread kể cả friend nhưng không đóng accepted thread cũ.
- Không cần bảng/cột mới cho policy. Chỉ search normalization/index có thể cần migration additive; xem plan 03/12 và đo trước.
