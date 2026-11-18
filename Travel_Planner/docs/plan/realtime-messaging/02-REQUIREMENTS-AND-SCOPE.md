# 02 — Yêu cầu và phạm vi

**Cập nhật:** 2026-11-17. Hành vi privacy/request đã được duyệt (D-16) và source đã triển khai một phần; runtime chưa nghiệm thu.

**Revision:** 2026-11-18. D-25 thay thế các quyết định mâu thuẫn trong revision 2026-11-18: accept là trạng thái toàn conversation, unfriend không hạ trạng thái, không có xóa hội thoại; block bảo vệ dữ liệu toàn hệ thống.

## 1. Mục tiêu

Hoàn thiện messaging/friendship theo source hiện hữu; xử lý lifecycle và trạng thái kết nối; làm rõ phân biệt unread message và unread conversation; bổ sung inbox yêu cầu tin nhắn từ người lạ; nối badge kết bạn; cải thiện trải nghiệm chat và điều hướng Community; giữ privacy enforcement ở backend.

## 2. Phạm vi

### Trong phạm vi kế hoạch
- Sửa lifecycle WebSocket: trạng thái UI phản ánh trạng thái client thực; sở hữu và đóng client nhất quán; tránh tạo nhiều session ngoài ý muốn; reconnect + REST resync.
- UI chat có avatar/fallback, phân biệt bubble, thời gian và trạng thái gửi/đã nhận/đã đọc theo khả năng backend hiện hữu.
- Community hiện hữu tiếp tục làm feed-first, giữ 5 tab. Nối unread messages, incoming friend requests và stranger requests bằng nguồn dữ liệu rõ ràng; thêm danh sách Friends/Invites và mở profile.
- Tách luồng bắt đầu hội thoại mới với tiếp tục hội thoại đã được chấp nhận. Người lạ có thể vào Stranger Inbox theo policy `EVERYONE`, chấp nhận để chuyển thành inbox thường, từ chối hoặc block.
- Backend API/DB additive, phân trang, kiểm soát privacy, account state, membership, block và chống trùng request.
- Kiểm thử backend, Flutter và kịch bản hai thiết bị.
- **D-24 superseded:** không có thao tác ẩn/xóa hội thoại khỏi Inbox; không xóa lịch sử dùng chung.
- Menu Inbox/Stranger Inbox chỉ có xem profile và block (xác nhận); không cung cấp xóa/ẩn hội thoại.
- Conversation đã ACCEPTED giữ trạng thái sau unfriend và privacy changes; chỉ block/account inactive chặn gửi và xem history.
- Stranger request chỉ được đánh dấu đã đọc khi recipient nhấn Accept; mở detail không cập nhật read cursor.
- Block được kiểm tra server-side với profile/search, feed/posts/comments, itineraries/ratings/comments, conversation/history/send và WebSocket. Quy tắc visibility tương thích với block hai chiều hiện tại; không xóa dữ liệu.

### Ngoài phạm vi hiện tại
Chat web, nhóm, file/media, typing/presence, push khi app đóng, mã hóa đầu-cuối, moderation nâng cao, notification history đầy đủ, broker phân tán nhiều instance. Những mục này cần quyết định riêng.

## 3. Hành vi đã chốt và triển khai

- `FRIENDS_ONLY`: chỉ bạn bè được bắt đầu hội thoại mới.
- `EVERYONE`: người lạ tạo message request trong Stranger Inbox và có thể gửi nhiều tin trước khi recipient chấp thuận tường minh.
- `NOBODY`: chặn bắt đầu hội thoại mới.
- Đổi policy hoặc unfriend không thu hồi accepted chat; block và tài khoản inactive chặn tiếp tục.
- `Accept` (recipient only) chuyển request thành accepted atomically với read cursor; `Decline` giữ thread/lịch sử sender-side, recipient-invisible tin cũ và cho phép gửi lại sau 1 ngày. Không tạo friendship khi accept message request. Reply không tự accept.
- Request nhận vào hai chiều đồng thời cần xử lý idempotent, tránh tạo hai conversation hoặc tự động accept ngoài quy tắc đã chọn.

Các hành vi trên được xác nhận trong Decision Record D-16 trước khi triển khai.

## 4. Badge và số liệu

- Tổng unread messages: tổng tin chưa đọc hiện có từ `/api/conversations/unread-total`.
- Unread conversations: chưa có badge riêng; không đồng nhất với unread messages.
- Friend requests badge: số incoming `PENDING` do backend trả hoặc endpoint count; không dùng `friendRequestsCount` chưa được nối hiện tại.
- Stranger requests badge: số inbound message request đang chờ.
- REST là nguồn số liệu chính. STOMP chỉ báo invalidation/refetch; không cộng trừ badge trực tiếp song song với REST để tránh đếm hai lần. Refresh khi app resume, vào Community/chat, và sau accept/decline/read.

## 5. Yêu cầu UI/UX và kiến trúc

Dùng component, notifier/repository và tokens hiện có; không nhân đôi hệ thống chat. Giữ Community 5-tab và route hiện hữu. Avatar luôn có fallback initials/default; bubble phân biệt chiều gửi/nhận; thời gian dễ đọc; connection state phân biệt connecting/connected/reconnecting/offline/failed. Trạng thái offline không chặn tải lịch sử local/network khi REST còn dùng được. Tuân thủ DESIGN.md, coding guide, spacing/color/typography, accessibility và target size của design system.

## 6. Yêu cầu phi chức năng

Mọi endpoint kiểm tra principal, account status, participant, privacy và block ở backend. Không tin userId gửi từ client làm identity. Danh sách và thread phân trang server-side; truy vấn batch, tránh N+1. Giữ tương thích dữ liệu đang có; không xóa/reset. Xử lý duplicate/retry bằng idempotency. Không log token/message nhạy cảm. Có thể quan sát CONNECT/SUBSCRIBE/rejection an toàn qua log correlation/session metadata.

## Addendum — Community Navigation và Friend Discovery (2026-11-17)
Baseline inbox/search/badge đã có source theo plan 12. Revision 2 tại plan 12 là scope kế tiếp, chưa implement: bỏ shortcut Stranger riêng khỏi Community nhưng giữ entry bên trong Tin nhắn; chuyển User Search sang Explore cạnh Notifications; đưa privacy settings vào đường Profile settings; phân biệt permission bắt đầu chat và tiếp tục accepted thread; nâng user matching cho tên/handle và tiếng Việt. Search conversation hiện tại và search user phải giữ thành hai nghiệp vụ. Không đổi 5 bottom destinations hoặc nhầm user search với itinerary/place search.
