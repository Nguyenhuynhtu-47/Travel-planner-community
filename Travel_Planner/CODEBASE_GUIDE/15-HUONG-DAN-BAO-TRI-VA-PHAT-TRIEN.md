# 15. Hướng dẫn bảo trì và lần theo lỗi

| Thay đổi | Bắt đầu | Kiểm tra ảnh hưởng |
|---|---|---|
| UI mobile | `features/<name>/presentation` | notifier/state → repository/model → widget tests |
| base URL/HTTP errors | `api_constants.dart`, `api_client.dart` | tất cả repositories, auth 401 |
| Backend endpoint | controller | DTO, service, repository/entity, `SecurityConfig`, tests, Flutter clients |
| Activity location | `ActivityFormDialog`, `LocationPickerSheet` | `LocationRepository`, request DTO, Activity service/entity, map; phân biệt snapshot với canonical Place |
| Place search/catalog | `LocationController`/`LocationService`, `PlaceController`/`PlaceService` | provider, resolve, geographic filters, rate/cache, env config, saved-place APIs |
| Comment reply | comments section/notifier/repository, `CommentServiceImpl` | scope, parent/root, paging, visibility, soft-delete |
| Profile/social/chat | Profile/PublicUser/Friendship/Conversation controllers | REST vs STOMP, auth, relationship scope, UI state |
| Database | entities và startup runners | backup, DDL, constraints, startup order, DB tests và schema thật |
| Web admin | `frontend/web` locations/moderation features | Place/admin APIs, server-side ADMIN check, forms; authenticated shell còn placeholder |

## Debug từ giao diện xuống DB
1. Ghi action và HTTP path/method/query/body, tuyệt đối không log token/secret.
2. Tìm widget/screen event và notifier/state transition.
3. Mở repository để xác nhận request serialization, ApiClient/base URL và response model.
4. Đối chiếu Controller, DTO validation, principal và SecurityConfig.
5. Theo Service tới Repository/entity hoặc provider ngoài.
6. So response DTO với parser/model rồi xem UI loading/error/success.
7. Tìm test tương ứng; kiểm tra fixtures/assertions và xác nhận test đã chạy ở môi trường phù hợp.

## Rủi ro và dấu hiệu cần thận trọng
- Mobile client còn `/api/destinations` legacy nhưng backend không có endpoint này; `getDestinations()` hiện không có call site. Activity DTO `destinationId` chỉ tương thích chuyển tiếp sang canonical Place ID.
- Place catalog, itinerary saved-place relation và Activity location snapshot là ba mô hình riêng.
- Notification thay đổi phải giữ `NotificationService`/`NotificationServiceImpl`, `SocialNotificationService`/`SocialNotificationServiceImpl`, JPA Entity/Repository schema, một Home/Explore bell và không gộp chat unread. FCM phải giữ messaging push-only; không dùng credentials thật trong test. Production schema/device delivery chưa xác minh.
- Location service có provider selection, rate limits, cache, query parsing/geographic ranking; kiểm tra runtime config thay vì đoán provider.
- Startup runners thay đổi schema/dữ liệu. Entity không chứng minh DB local đã có schema tương ứng; kiểm tra schema và backup trước thao tác production.
- Mobile/Web là hai app riêng; sửa client này không tự cập nhật app kia.
