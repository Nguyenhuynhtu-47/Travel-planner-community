# 03. Tổng quan Backend

## Entry point và dependency
`TravelPlannerApplication` là entrypoint Spring Boot; package root legacy viết hoa `Travel_Planner.Travel_Planner` phải được giữ ổn định. Backend dùng Java 22, Spring MVC, Spring Data JPA, Security, Validation, REST clients, JWT, MySQL, cache/rate-limit và test starters. Chi tiết version ở `backend/pom.xml`.

## Request lifecycle
~~~mermaid
sequenceDiagram
 participant App as Flutter Mobile/Web
 participant Jwt as JWT/Security
 participant C as Controller
 participant S as Service
 participant R as Repository
 participant DB as MySQL
 App->>Jwt: HTTP JSON + Bearer token (nếu endpoint yêu cầu)
 Jwt->>C: SecurityContext/principal
 C->>S: request + actor
 S->>R: query/save và kiểm tra scope/quyền
 R->>DB: JPA/JDBC
 DB-->>S: dữ liệu
 S-->>C: response DTO
 C-->>App: HTTP status + JSON
~~~
Location/routing/media service có thể gọi provider ngoài; các luồng đó không nhất thiết truy cập DB.

## Packages
Backend hiện có 265 file Java production trong `src/main/java`; danh mục từng file xem `04-BACKEND-DANH-MUC-FILE.md`. Các nhóm chính gồm controller, service/service.impl, repository, model/model.enums, dto request/response, resolver, security, config, exception, seeder và util. Không dùng số lượng/package của tài liệu cũ; xem trực tiếp catalogue khi source đổi.

## Nhóm API hiện hành
| Nhóm | Base path tiêu biểu | Ghi chú |
|---|---|---|
| Auth/profile/users | `/api/auth`, `/api/user/profile`, `/api/users` | login/register/me, hồ sơ, public profile/follow |
| Itinerary/day/activity | `/api/itineraries`, `/api/user/itineraries` | CRUD, explore, clone, day/activity/reorder |
| Place và saved places | `/api/places`, `/api/itineraries/{id}/places` | catalog canonical `Place`, resolve provider place, lưu theo itinerary |
| Administrative areas | `/api/administrative-areas`, `/api/admin/places` | vùng hành chính và quản trị/liên kết Place |
| Map/routing | `/api/locations`, `/api/itineraries/{id}/days/{dayId}/route` | POI search/details, reverse, nearby, route |
| Comments/ratings | `/api/itineraries/{id}/comments`, `/api/activities/{id}/comments`, `/api/comments`, `/api/itineraries/{id}/ratings` | thread và đánh giá |
| Social/community | `/api/community`, `/api/user/favorites`, `/api/user/saved-itineraries` | feed/posts/like/comment/report và quan hệ itinerary |
| Messaging/friendship | `/api/conversations`, `/api/friend-requests`, `/api/users/me/...` | REST chat, unread, read state, friendship/block/settings; WebSocket/STOMP riêng |
| Upload/admin/health | `/api/media`, `/api/admin`, `/api/health` | Cloudinary upload, moderation/media, liveness |

Backend source hiện không khai báo controller `/api/destinations` hoặc `/api/admin/destinations`. Mobile còn `destinationsEndpoint`, `DestinationSummary`, `getDestinations()` và DTO activity còn `destinationId`; `getDestinations()` không có call site ngoài định nghĩa. `destinationId` trong request activity chỉ là tương thích cũ được service chuyển thành ID Place canonical, không khôi phục API Destination độc lập. Client không nên dùng endpoint cũ.

## Security
`SecurityConfig` dùng stateless JWT, filter JWT và quyền ADMIN cho `/api/admin/**`; một số GET công khai cho health/auth, explore, comments công khai, location/place/administrative areas và feed theo cấu hình cụ thể. Endpoint khác mặc định yêu cầu đăng nhập. WebSocket handshake `/ws` có cơ chế xác thực STOMP riêng qua interceptor. Service vẫn phải kiểm tra owner, visibility và scope; permit của HTTP không thay kiểm tra nghiệp vụ.

## Errors, validation và migration
Request DTO dùng Jakarta constraints và controller `@Valid` ở nơi khai báo. Exception handlers/security handlers chuẩn hóa lỗi; xem implementation để biết status thực tế. Không thấy Flyway/Liquibase quản lý schema. Các `ApplicationRunner`/startup runners thực hiện một số kiểm tra/backfill/chuyển đổi dữ liệu legacy; điều kiện và thứ tự nằm trong `config`. `spring.jpa.hibernate.ddl-auto` và schema runtime cần đối chiếu cấu hình DB thực, không kết luận chỉ từ entity.
