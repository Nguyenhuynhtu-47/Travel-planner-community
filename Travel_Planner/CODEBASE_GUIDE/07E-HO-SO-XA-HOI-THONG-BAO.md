# 07E — Hồ sơ, follow, kết bạn và thông báo

`ProfileRepository` quản lý hồ sơ tài khoản hiện tại; `PublicProfileRepository`/social repository tải hồ sơ công khai, danh sách itinerary, followers/following và follow. Backend `ProfileController` và `PublicUserController` định nghĩa các API tương ứng. Follow một chiều khác friendship hai chiều; visibility của từng itinerary vẫn được backend kiểm tra.

Friendship request/accept/decline, friends, block/unblock và danh sách blocks đi qua `FriendshipController`; messaging preferences đi qua `MessagingSettingsController`. Mobile có repository/UI cho các luồng xã hội tương ứng. `MessagingInboxScreen`, `StrangerInboxScreen` và `FriendsScreen` là các destination riêng, dùng chung `MessagingRepository`; `UserSearchScreen` tìm prefix theo tên hiển thị/handle và hiển thị friendship actions từ backend. API `GET /api/users/search` chỉ trả public fields, yêu cầu active viewer và nạp relationship context theo batch.

Message request được lưu như trạng thái trên `Conversation`, không tạo bảng notification riêng. API list/count/accept/decline và unread-request-count nằm trong `ConversationController`; request pending vào Stranger Inbox và badge pending tách với unread count. Dot ở bottom Community báo unread tin accepted, unread tin stranger hoặc incoming friend request. Policy chỉ chặn chat mới; accepted chat tiếp tục trừ block hoặc tài khoản inactive. Decline giữ thread và cooldown gửi lại là một ngày.

`NotificationsScreen` hiện render empty state cố định. Trong backend hiện không có notification controller/service/API tương ứng; chưa có cơ sở để ghi nhận push/in-app notification delivery. Không suy ra notification từ unread chat count hoặc WebSocket chat events.

Test hồ sơ/social: xem `public_profile_screen_test`, `user_handle_test`, test social/friendship trong inventory mobile và backend. Số lượng/tên chính xác ở các tài liệu test 10–12.
