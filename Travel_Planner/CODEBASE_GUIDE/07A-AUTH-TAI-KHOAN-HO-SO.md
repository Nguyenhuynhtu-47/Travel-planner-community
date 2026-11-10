# 07A — Đăng nhập, tài khoản và hồ sơ

Login/register UI gọi AuthNotifier; notifier điều phối trạng thái; AuthRepository gửi API; AuthStorage giữ phiên. Backend AuthController/AuthServiceImpl cấp token, JwtAuthenticationFilter xác thực request tiếp theo. Khi logout hoặc 401, UI và storage cần chuyển về trạng thái nhất quán.

Hồ sơ cá nhân và public profile có repository riêng. Public user có thể tra theo ID hoặc handle. UserHandleServiceImpl chuẩn hóa handle, loại dấu, kiểm tra độ dài/ký tự và duy nhất. UserHandleBackfillRunner bổ sung handle lúc backend startup; đây là cập nhật schema/dữ liệu khi khởi động, không phải migration Flyway.

Khi đổi hợp đồng API, đồng bộ DTO backend, repository mobile, model và test. Không đưa email/username riêng tư vào public DTO nếu API không định nghĩa công khai. Test tham khảo: user_handle_test, public_profile_screen_test, UserHandleServiceTest, PublicUserServiceTest.
