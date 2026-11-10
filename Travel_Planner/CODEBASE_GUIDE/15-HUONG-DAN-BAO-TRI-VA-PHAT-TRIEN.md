# 15. Hướng dẫn bảo trì và lần theo lỗi

| Thay đổi | Bắt đầu | Kiểm tra ảnh hưởng |
|---|---|---|
| UI mobile | features/<name>/presentation | notifier → repository/model → widget tests |
| base URL/HTTP errors | api_constants.dart, api_client.dart | all repositories, auth 401 |
| Backend endpoint | controller | DTO, service, repository/entity, SecurityConfig, tests, Flutter clients |
| Activity location | ActivityFormDialog, LocationPickerSheet | LocationRepository, request DTO, ActivityService/entity, map |
| Place search | LocationController/LocationServiceImpl | query parser, providers, geo filters, rate/cache, env config |
| Comment reply | CommentsSection/Notifier/Repository, CommentServiceImpl | scope, parent/root, paging, visibility, soft-delete |
| Profile/handle | ProfileController/ProfileService/UserHandleService | User entity, DTO, startup backfill, public profile |
| Database | entities and schema startup logic | backup, DDL, constraints, transaction, DB tests |
| Web admin | frontend/web locations feature | destination repository, server ADMIN check, forms |

## Debug từ giao diện xuống DB
1. Ghi nhận user action và HTTP path/method/query/body, tuyệt đối không log token.
2. Tìm callback trong widget, xem notifier/state transition.
3. Mở repository để xác nhận request serialization, ApiClient/base URL.
4. Đối chiếu Controller, validation, principal và security matchers.
5. Theo Service tới Repository/entity hoặc external provider.
6. So response DTO với parser/model rồi UI loading/error/success.
7. Tìm test tương ứng, đọc fixtures/assertions trước khi sửa.

## Rủi ro và dấu hiệu cần thận trọng
- Navigator hiện gọi trực tiếp; core/router placeholder.
- Mobile/Web là hai app độc lập, cùng backend nhưng code không tự đồng bộ.
- Destination catalog và custom activity location khác nhau.
- Location service có provider selection, rate limits, cache, query parsing/geographic ranking.
- Startup handle backfill có DDL; kiểm tra DB thật trước production.
- Một số docs cũ ghi auth permitAll/no JWT, trái với code hiện hành.
- PlaceholderHomeScreen, empty folders có thể là code chưa dùng; chưa chạy call graph đầy đủ, không xóa chỉ theo suy đoán.
