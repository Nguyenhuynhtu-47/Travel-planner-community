# 09 — Flutter Web

## Hiện trạng
Web là app Flutter riêng, dùng REST client/auth riêng nhưng gọi cùng backend. `main.dart` kiểm tra AuthNotifier; guest thấy LoginScreen; sau đăng nhập shell `WebPlaceholderScreen` mới cung cấp lối đến một số màn hình admin/profile và nêu dashboard đang phát triển. Vì vậy không mô tả Web như portal hoàn chỉnh.

Đã có implementation tập trung ở auth, profile, quản trị Place và moderation cộng đồng/media. Backend tương ứng gồm `/api/admin/places`, `/api/admin/community/...`, `/api/admin/media-assets` và `/api/user/profile`. Web không phải mobile client responsive và không có đầy đủ các feature mobile (itinerary authoring, chat, community feed).

## Bản đồ source
Danh mục chính xác theo từng Dart file được sinh từ `frontend/web/lib`; hiện có 27 source file và 6 test file. Các thư mục có thể tồn tại nhưng chưa có UI/flow hoàn thiện; hãy kiểm tra `main.dart`, file screen/repository và test trước khi coi là feature hoạt động.

## Hợp đồng backend
Auth dùng `/api/auth`; hồ sơ dùng `/api/user/profile`; admin Place dùng `/api/admin/places`; moderation dùng `/api/admin/community` và `/api/admin/media-assets`. Backend không còn admin Destination API. Web `features/locations` cần được hiểu theo implementation hiện tại: Place administration, không phải Destination catalog cũ.

Web map config/widget tồn tại nhưng không đồng nghĩa admin map/search workflow đã hoàn thiện. Cấu hình web tile/key phụ thuộc runtime. Xem tests `admin_moderation_test`, `admin_place_test`, `auth_401_test`, `username_validation_test`, `web_map_api_key_test`, `widget_test`.
