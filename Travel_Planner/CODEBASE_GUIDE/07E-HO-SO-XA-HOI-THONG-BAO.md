# 07E — Hồ sơ công khai, follow và thông báo

PublicProfileRepository tải hồ sơ công khai riêng với profile cá nhân; PublicUserListScreen trình bày danh sách tài khoản. Backend PublicUserController tra theo ID/handle; FollowRepository biểu diễn quan hệ theo dõi. Follow không mặc nhiên là quan hệ hai chiều. Hồ sơ công khai cũng không làm mọi itinerary của người dùng trở thành public; visibility vẫn kiểm soát từng itinerary.

Notifications hiện có màn hình mobile. Chỉ từ file inventory chưa thể kết luận backend delivery/realtime đầy đủ; trước khi mở rộng cần kiểm tra controller/service và API thực tế. Test hồ sơ: public_profile_screen_test, user_handle_test.
