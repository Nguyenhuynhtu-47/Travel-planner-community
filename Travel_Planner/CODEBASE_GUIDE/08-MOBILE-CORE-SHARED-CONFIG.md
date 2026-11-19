# 08 — Mobile core, shared và cấu hình

`core/network/api_client.dart` tập trung HTTP, multipart, timeout và xử lý lỗi/401. `core/constants/api_constants.dart` chứa backend paths; cần đối chiếu constant với controller vì còn `destinationsEndpoint` legacy không có backend/call site. `map_constants.dart` và `map_tile_provider_config.dart` cấu hình tile riêng với API backend. `core/theme` chứa color, spacing, typography và theme.

`shared/navigation/main_navigation_shell.dart` dựng năm tab chính. Shared widgets/services cung cấp map/marker, empty/error state, controls, avatar và image picker. Các feature có thể dùng Navigator trực tiếp; `core/router` chưa điều khiển toàn app.

Base URL phụ thuộc thiết bị: Android emulator thường gọi host qua `10.0.2.2`; browser/máy thật cần địa chỉ phù hợp. Backend URL, provider geocoding/routing và map tile key là các cấu hình khác nhau. Không commit secret. Xem README, `.env.example`, Spring properties, Flutter constants và runtime `--dart-define` cùng nhau trước khi đổi config.
