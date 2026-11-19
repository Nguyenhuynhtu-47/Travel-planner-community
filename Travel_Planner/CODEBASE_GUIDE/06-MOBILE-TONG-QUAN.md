# 06. Tổng quan Flutter Mobile

## Startup và navigation
`main.dart` khởi tạo Flutter, AuthNotifier và ApiClient unauthorized callback, kiểm tra session rồi dựng `MaterialApp`/`MainNavigationShell`. Shell có năm tab: Khám phá, Cộng đồng, Tạo lịch trình, Bộ sưu tập, Lịch trình của tôi. Profile và các màn hình feature được mở bằng Navigator/MaterialPageRoute; `core/router` chưa phải router tập trung.

## Cấu trúc và state
`core` chứa constants/network/theme/utils; `features` chia theo auth, collection, comments, explore, itinerary, location, messaging, notifications, profile, reviews, saved itineraries, social; `shared` chứa shell/widgets/services. Nhiều luồng dùng repository + `ChangeNotifier` và `ListenableBuilder`, chưa phải một state framework thống nhất toàn app.

## Auth session
AuthRepository gọi register/login/me; AuthNotifier cùng AuthStorage đọc/lưu token và người dùng. ApiClient tập trung bearer token, JSON/multipart, timeout và lỗi. Callback 401 xóa session và điều hướng về trạng thái đăng nhập. Chi tiết chính xác xem auth notifier/client.

## Hợp đồng API
Mobile và Web dùng client riêng, gọi chung backend. Đường đi là widget/screen → notifier/state → repository → ApiClient → JSON model. Phải đối chiếu path, HTTP verb, query/body keys, null handling, pagination và response fields với DTO/controller backend. Một điểm lệch còn sót: client có `getDestinations()` trỏ `/api/destinations`, nhưng backend không còn endpoint đó và không có call site hiện tại; không dùng API này. Activity request vẫn gửi legacy `destinationId` khi có, trong khi luồng mới dùng `canonicalPlaceId` hoặc snapshot tọa độ.

## Map và media
`flutter_map` render tiles/layers. `MapConstants` cấu hình CARTO tile; location picker gọi backend `/api/locations` để search/reverse/nearby/details. Route được gọi qua itinerary route endpoint. Ảnh hoạt động có thể là URL được lưu hoặc URL upload; ảnh POI không tự có từ CARTO. Map tile, geocoding, routing, catalog Place, upload ảnh là các dịch vụ tách biệt.

## Notifications và realtime
Màn Notifications hiện chỉ hiển thị empty state; chưa thấy `/api/notifications` hoặc notification service ở backend. Chat dùng REST cho conversation/message/read và STOMP/WebSocket cho sự kiện realtime; không coi chat realtime là hệ thống notification đã hoàn thiện.
