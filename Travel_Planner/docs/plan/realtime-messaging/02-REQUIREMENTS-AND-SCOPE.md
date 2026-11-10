# 02 — Yêu cầu và phạm vi MVP

**Trạng thái:** phạm vi chat/friendship được chấp thuận để lập kế hoạch; các hành vi đánh dấu đề xuất vẫn cần quyết định sản phẩm trước khi code.

## 1. Mục tiêu

Cho phép người dùng đã đăng nhập kết nối với tác giả lịch trình, kết bạn hai chiều, nhắn tin riêng 1-1 bằng văn bản, nhận tin realtime khi hai app foreground/connected và xem đầy đủ lịch sử khi reconnect. Backend kiểm tra mọi quyền; REST/database vẫn dùng được khi WebSocket offline.

## 2. Vai trò và tiền điều kiện

- Guest: xem hồ sơ public và public itineraries; không tạo friendship/chat; nhấn CTA được yêu cầu đăng nhập.
- User ACTIVE: quản lý lời mời, bạn bè, privacy, block và hội thoại thuộc mình.
- User INACTIVE/BANNED: không được mở kết nối hoặc gọi thao tác chat/friend; dữ liệu lịch sử không bị xóa bởi trạng thái account.
- Admin: không tự động có quyền đọc tin nhắn riêng tư. Moderation/access riêng cần chính sách sản phẩm khác và audit trail.

## 3. MVP gồm

- Mở/mở lại 1-1 chat từ hồ sơ người khác; conversation list.
- Gửi text, timestamp, sender identity, trạng thái pending/sent/failed ở client.
- Server persist trước, sau commit broadcast message event.
- Keyset pagination lịch sử theo sequence riêng của conversation; dedupe retry/reconnect bằng client message UUID.
- Unread count và optional receipt/seen từ read cursor.
- Friendship request, accept, decline, cancel, unfriend, friend list, sent/received lists.
- Privacy EVERYONE / FRIENDS_ONLY / NOBODY.
- Block/unblock tối thiểu để chống quấy rối.
- Loading/empty/error/retry; đổi mạng, token hết hạn, đổi tài khoản, background/resume lifecycle.

### Đề xuất nghiệp vụ mặc định

- Privacy mặc định FRIENDS_ONLY; người dùng có thể đổi sang EVERYONE hoặc NOBODY.
- Nếu EVERYONE, người lạ có thể mở chat trực tiếp. Nếu FRIENDS_ONLY, phải có friendship ACCEPTED. Nếu NOBODY, không ai gửi được tin mới.
- Không có message-request inbox ở MVP. Friend request là con đường xin kết nối; có thể mở message requests sau nếu cần sàng lọc người lạ.
- Cài đặt được kiểm tra khi tạo direct conversation và trước mỗi lần gửi tin, kể cả conversation cũ. Đổi privacy không xóa hội thoại/lịch sử, nhưng có thể tạm chặn gửi đến khi điều kiện lại thỏa.
- Không hiển thị online/typing, không push khi app đóng, không voice/video/group chat, attachments, edit/unsend, search message, encryption E2E trong MVP.

## 4. Non-functional requirements

- REST/JWT authorization và conversation membership kiểm tra server-side; sender luôn lấy từ principal.
- WebSocket JWT được xác thực tại STOMP CONNECT; không token trong URL/query string.
- Tin nhắn persist trước event; DB là nguồn sự thật. Realtime không bảo đảm lưu/offline delivery; reconnect tải REST theo cursor.
- Client gửi retry cùng clientMessageId; DB unique guard ngăn duplicate. Event có messageId và clientMessageId để client dedupe.
- Keyset pagination, DB indexes và batch/projection queries; không N+1 participant/last message/unread.
- Rate limiting theo user cho send/friend invites, giới hạn body/frame/concurrent sockets, heartbeat, reconnect backoff, exact allowed origins.
- Nội dung chat không ghi vào log; không log JWT/CONNECT Authorization.
- REST mutating call không retry tự động trừ khi idempotency key được giữ nguyên.

## 5. Acceptance criteria MVP

1. Từ public profile A có thể gửi friend request hoặc vào chat nếu quyền cho phép.
2. B accept; cả hai thấy trạng thái bạn bè; A/B mở một direct conversation duy nhất.
3. Follow/unfollow API/count/UX vẫn độc lập và hồi quy pass.
4. User chỉ đọc/gửi/subscribe hội thoại mà mình là một trong hai thành viên.
5. Gửi REST thành công tạo đúng một row, trả message đã lưu; người nhận kết nối nhận event sau commit.
6. Offline/đóng app thì không nhận live; reconnect và REST sync trả đủ tin theo cursor không trùng.
7. Mất response rồi retry cùng clientMessageId không tạo hai tin nhắn.
8. Policy, block, friendship revoke, inactive/banned đều được enforce server-side; generic errors không làm rò block details.
9. Pagination ổn định, unread cursor không lùi; read state chỉ tăng khi đọc message hợp lệ của conversation.
10. Logout/account switch/401 đóng socket, bỏ subscription và xóa state của tài khoản trước.
11. App không thêm bottom-nav tab mới; 5 destination hiện tại và Web tests vẫn hoạt động.

Giới hạn body/rate/connection là giá trị cấu hình cần chốt khi implementation; đề xuất text 1–4,000 ký tự, payload JSON nhỏ và rate limit cấu hình được, không hardcode vào UI.


