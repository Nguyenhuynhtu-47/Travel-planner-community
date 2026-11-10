# 05. Database và dữ liệu

## Persistence và giới hạn xác minh
Backend dùng Spring Data JPA với MySQL connector. Entity source cho biết mapping dự kiến, không xác nhận schema đang chạy. Không thấy Flyway/Liquibase migration trong resources/db. Nhưng UserHandleBackfillRunner chạy lúc startup và dùng JdbcTemplate/DatabaseMetaData để có thể ALTER TABLE users: thêm handle, backfill giá trị thiếu, đặt NOT NULL và unique key. Đây là startup DDL quan trọng; không chạy tùy tiện trên production.

## Entity inventory
User, Destination, Itinerary, ItineraryDay, Activity, Comment, Rating, Favorite, SavedItinerary, Follow, ItineraryShare, OfflineDownload, CachedRouteResult, WaypointCoordinate; enums trong model/enums. Cột/quan hệ chi tiết được trích ở file-level Java index và annotations của entity.

~~~mermaid
erDiagram
 USER ||--o{ ITINERARY : owns
 ITINERARY ||--o{ ITINERARY_DAY : contains
 ITINERARY_DAY ||--o{ ACTIVITY : contains
 DESTINATION o|--o{ ITINERARY : destination
 ACTIVITY }o|--|| DESTINATION : optional_catalog_link
 USER ||--o{ COMMENT : author
 ITINERARY o|--o{ COMMENT : scope
 ACTIVITY o|--o{ COMMENT : scope
 COMMENT o|--o{ COMMENT : parent
 COMMENT o|--o{ COMMENT : root
 USER ||--o{ RATING : creates
 ITINERARY ||--o{ RATING : receives
 USER ||--o{ FAVORITE : creates
 ITINERARY ||--o{ FAVORITE : target
 USER ||--o{ SAVED_ITINERARY : saves
 ITINERARY ||--o{ SAVED_ITINERARY : target
 USER ||--o{ FOLLOW : follows
~~~
Sơ đồ khái quát; nullable, cascade/fetch, indexes và constraint phải kiểm tra annotation/database.

## Lịch trình và địa điểm
Itinerary có nhiều ngày; mỗi ngày có activities và thứ tự. Activity có thể tham chiếu Destination catalogue hoặc custom location fields như tên/address/lat/lon/place/provider id. Custom map search không bắt buộc tạo Destination chung. Route cache/waypoints có entities riêng.

## Comment và community
Comment có author, itinerary/activity scope, parentComment và rootComment. Reply giữ parent cụ thể để đúng quan hệ trả lời, root để query cả thread. Rating/Favorite/SavedItinerary/Follow biểu diễn quan hệ user-target; counters aggregate trên itinerary được services cập nhật.

## Handle và schema startup
User.handle khác private login username. UserHandleBackfillRunner có thể thêm cột handle, sinh handle cũ dựa fullName/userId, rồi thử đổi NOT NULL và unique index. Constraint exceptions được ghi log theo implementation. DB migration chưa version hóa; trước khi thay runner cần backup, xem DB thật và startup logs.

## Xác minh database thật
Cần xem DB URL/profile, SHOW CREATE TABLE, FK/index và metadata ở môi trường được phép. Không kết nối hoặc sửa DB trong task viết tài liệu.
