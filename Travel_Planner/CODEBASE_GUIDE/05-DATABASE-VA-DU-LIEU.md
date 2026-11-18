# 05. Database và dữ liệu

## Persistence và giới hạn xác minh
Backend dùng Spring Data JPA/MySQL, một số runner dùng JDBC. Entity mô tả mapping mà code kỳ vọng; nó không chứng minh schema của DB local đã được migrate. Trong source hiện không có Flyway/Liquibase migrations quản lý toàn bộ schema. Startup runners gồm chuyển Destination cũ sang Place, migration snapshot vị trí Activity, AdministrativeArea/Place links và backfill handle. Hành vi phụ thuộc điều kiện DB và profile; đọc từng runner trước khi chạy với DB quan trọng.

## Domain chính
`User`, `Itinerary`, `ItineraryDay`, `Activity`, `Place`, `PlaceProviderMapping`, `AdministrativeArea`, `ItineraryPlace`, `Comment`, `Rating`, `Favorite`, `SavedItinerary`, `Follow`, `ItineraryShare`, `OfflineDownload`, `CachedRouteResult`, `WaypointCoordinate`, `Friendship`, `Conversation`, `Message`, `ConversationReadState`, `UserMessagingSettings`, `UserBlock`, `Post`, `PostComment`, `PostLike`, `PostMedia`, `PostReport`, `MediaAsset` cùng enums. `Conversation` có status/requester/recipient/request timestamps nullable cho message request; legacy null được xem là accepted. Đây là JPA mapping, chưa xác minh trên MySQL thật. Danh mục đầy đủ theo source ở `04-BACKEND-DANH-MUC-FILE.md`.

~~~mermaid
erDiagram
 USER ||--o{ ITINERARY : owns
 ITINERARY ||--o{ ITINERARY_DAY : contains
 ITINERARY_DAY ||--o{ ACTIVITY : contains
 PLACE o|--o{ ACTIVITY : canonical_reference
 ITINERARY ||--o{ ITINERARY_PLACE : saves
 PLACE ||--o{ ITINERARY_PLACE : saved_place
 PLACE ||--o{ PLACE_PROVIDER_MAPPING : provider_alias
 ADMINISTRATIVE_AREA o|--o{ PLACE : classifies
 USER ||--o{ COMMENT : writes
 ITINERARY o|--o{ COMMENT : itinerary_scope
 ACTIVITY o|--o{ COMMENT : activity_scope
 COMMENT o|--o{ COMMENT : parent_and_root_thread
 USER ||--o{ FRIENDSHIP : participates
 USER ||--o{ CONVERSATION : participates
 CONVERSATION ||--o{ MESSAGE : contains
 USER ||--o{ POST : authors
 POST ||--o{ POST_COMMENT : contains
 POST ||--o{ POST_MEDIA : contains
~~~
Sơ đồ khái quát. Tên bảng, nullability, cascade, fetch, unique/index và khóa ngoại cần kiểm tra annotation/entity và schema thực.

## Activity location so với Place catalog
Activity lưu snapshot địa điểm/địa chỉ/tọa độ/provider/placeId và imageUrl; có thể gắn optional `canonicalPlaceId` tới `Place`. Chọn kết quả POI bên ngoài hoặc pin thủ công không có nghĩa tự tạo một hàng `Place`. `Place` là catalog nội bộ; Activity snapshot giữ vị trí đã chọn kể cả khi provider/catalog đổi. `destinationId` chỉ còn trong DTO tương thích; source model hiện không có entity/controller Destination.

## Comments và quan hệ xã hội
Comment có scope itinerary hoặc activity, parent trực tiếp và root để truy vấn reply theo thread. Post comments là miền riêng với comments itinerary/activity. Favorite, SavedItinerary, Rating, Follow và ItineraryPlace là các quan hệ khác nhau; không gộp. Messaging dùng Conversation/Message/read state; friendship/block/settings là miền liên quan nhưng không đồng nghĩa với follow.

## Schema ở startup
Các runner migration không phải migration tool có version history. Đặc biệt DestinationConsolidationMigrationRunner và ActivityLocationMigrationRunner xử lý dữ liệu schema legacy theo điều kiện; Hibernate DDL mode cũng ảnh hưởng. Không xóa/bỏ qua runner để chữa lỗi khởi động trước khi xem cấu trúc DB và log. Backup và kiểm tra trên DB sao chép trước khi thay schema production.

## Xác minh database thật
Entity và code không cho biết DB local hiện có cột/index nào. Để kết luận DB cụ thể cần kiểm tra URL/profile đang chạy, `SHOW CREATE TABLE`, metadata, migration logs và trạng thái runner. Tài liệu guide này không kết nối hay thay đổi DB.
