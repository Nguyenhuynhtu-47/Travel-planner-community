# 06. Tổng quan Flutter Mobile

## Startup
main.dart khởi tạo binding rồi runApp(MyApp). MyApp tạo AuthNotifier, gắn ApiClient.globalOnUnauthorized, gọi checkAuthStatus, tạo MaterialApp với AppTheme và MainNavigationShell. initial hiển thị loading. Dispose gỡ callback và notifier do app sở hữu.

## Cấu trúc và state
Core: constants/network/theme/utils; shared: navigation/widgets/services; features theo chức năng. Router directory là placeholder; Navigator/MaterialPageRoute điều hướng trực tiếp. State dùng ChangeNotifier + ListenableBuilder ở nhiều module, không thấy framework state thống nhất ngoài pattern này. Repository có thể inject vào screen/notifier/test.

## Auth session
AuthRepository gọi register/login/me. AuthNotifier đọc token, check expiration, rồi GET /api/auth/me. 401/403 xóa session; network/500 giữ cache/session để không logout chỉ vì backend tạm lỗi. Login/register lưu token + user vào AuthStorage. Logout xóa storage. ApiClient 401 callback xử lý token hết hạn ở request bất kỳ.

## Network
ApiConstants lấy API_BASE_URL từ dart-define; Web mặc định localhost:8080, Android emulator 10.0.2.2:8080, platform khác localhost. ApiClient lo headers/query/body, timeout, response parsing, error normalization và multipart. Repository chuyển JSON thành model; notifier đổi state; widget rebuild.

## Map
flutter_map render tiles/layers. MapConstants điều khiển CARTO tile URL/attribution/key. Search gọi backend qua LocationRepository, không gọi CARTO. User chọn result hoặc manual pin; reverse geocode có thể gắn địa chỉ. Route API tạo waypoints/polyline để map render.
