# 08 — Mobile core, shared và cấu hình

core/network/api_client.dart tập trung HTTP; api_exception.dart chuẩn hóa lỗi client. core/constants/api_constants.dart lưu API config; map_constants.dart và map_tile_provider_config.dart lưu cấu hình bản đồ. core/theme chứa color, spacing, text style và theme.

shared/navigation/main_navigation_shell.dart nối điều hướng. shared/widgets tái sử dụng map, marker, error/empty state, input/button, avatar, upload preview; shared/services/image_picker_service.dart bọc chọn ảnh.

Base URL phụ thuộc thiết bị: Android emulator thường truy cập host máy phát triển qua 10.0.2.2; browser/máy thật cần địa chỉ phù hợp. Backend URL và map tile key là hai cấu hình khác nhau. Không commit secret. Xem pubspec, README, hằng số cùng nhau trước khi nâng dependency hoặc đổi cấu hình.
