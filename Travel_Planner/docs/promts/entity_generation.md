# Prompt Tạo Entity/Model cho Travel Planner

## Mục tiêu

Hãy làm việc trực tiếp trên backend Spring Boot hiện có của dự án Travel
Planner. Đọc cấu trúc package, `pom.xml`, `application.properties`, các
Entity/Model và cấu hình Security trước khi sửa.

Tôi muốn Hibernate tự kiểm tra các Entity khi backend khởi động và tạo
các bảng còn thiếu trong MySQL. Không yêu cầu tạo dữ liệu mẫu (seed
records). Cụm từ "sinh database" ở đây là sinh cấu trúc bảng và quan hệ
từ các Entity.

-   MySQL: `travel_planner`
-   Spring Boot backend: cổng `8080`
-   API kiểm tra: `GET /api/health` phải tiếp tục hoạt động.
-   Giữ nguyên cấu trúc dự án và package hiện có.
-   Không tạo file SQL/Flyway migration nếu dự án đang chọn cách sinh
    bảng bằng Hibernate `ddl-auto=update`.
-   Không xóa dữ liệu, không tạo tài khoản mặc định, không thay đổi chức
    năng không liên quan.

## 1. Cấu hình Hibernate và MySQL

Kiểm tra cấu hình hiện có và bảo đảm phù hợp:

``` properties
spring.datasource.url=jdbc:mysql://localhost:3306/travel_planner?createDatabaseIfNotExist=true&serverTimezone=Asia/Ho_Chi_Minh&characterEncoding=UTF-8
spring.datasource.username=${DB_USERNAME:root}
spring.datasource.password=${DB_PASSWORD:your_mysql_password}
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
```

Không ghi mật khẩu thật vào Git. `createDatabaseIfNotExist=true` yêu cầu
tài khoản MySQL có quyền tạo database. Hibernate `update` chỉ tạo/cập
nhật schema dựa trên Entity được quản lý; nó không thay thế việc thiết
kế Entity đúng.

Không dùng đồng thời `ddl-auto=update` và Flyway/Liquibase để cùng quản
lý schema. Nếu dự án đã dùng công cụ migration, hãy báo cáo và giữ một
cơ chế quản lý schema thống nhất thay vì tự ý trộn hai cách.

## 2. Quy tắc chung cho Entity

-   Dùng `jakarta.persistence.*` nếu dự án đang dùng Spring Boot 3 trở
    lên.
-   Dùng `@Entity`, `@Table`, `@Id`,
    `@GeneratedValue(strategy = GenerationType.IDENTITY)`.
-   Ánh xạ tên bảng/cột bằng `@Table(name = "...")`,
    `@Column(name = "...")`, giữ tên snake_case đúng như thiết kế.
-   Dùng `LocalDate` cho DATE, `LocalTime` cho TIME, và kiểu thời gian
    phù hợp với DATETIME hiện tại của dự án (`LocalDateTime` thường phù
    hợp).
-   Dùng `BigDecimal` cho DECIMAL, không dùng `double` cho tiền.
-   Tạo `created_at` và `updated_at` bằng cơ chế nhất quán, chẳng hạn
    `@PrePersist`/`@PreUpdate` hoặc auditing nếu dự án đã cấu hình.
    Không tạo nhiều cơ chế timestamp chồng chéo.
-   Khai báo quan hệ JPA hai chiều hoặc một chiều tùy nhu cầu hiện có;
    tránh quan hệ hai chiều không cần thiết.
-   Với `@ManyToOne`, dùng `fetch = FetchType.LAZY` phù hợp.
-   Không dùng `CascadeType.REMOVE`/`CascadeType.ALL` một cách tràn lan.
    Dữ liệu liên quan đến đánh giá, bình luận, lưu, tải xuống không được
    xóa dây chuyền ngoài ý muốn.
-   Tránh lỗi vòng lặp khi serialize JSON. Không trả Entity trực tiếp từ
    API nếu điều đó gây vòng lặp; ưu tiên DTO ở tầng API.
-   Nếu dùng Lombok, kiểm tra dependency hiện có trước khi dùng; không
    thêm thư viện mới nếu không cần.
-   Đặt Entity trong package model/entity phù hợp với package gốc của
    ứng dụng để Spring Boot scan được.
-   Kiểm tra các ràng buộc miền giá trị. Dùng Bean Validation ở tầng
    API/service khi phù hợp và database constraint khi MySQL hỗ trợ.
    Không dựa riêng vào `@Column` để bảo đảm mọi quy tắc nghiệp vụ.

## 3. Các bảng và thuộc tính bắt buộc

### 3.1 `users` --- Entity `User`

-   `user_id`: INT, PK, auto-increment.
-   `username`: VARCHAR(50), NOT NULL, UNIQUE.
-   `password`: VARCHAR(255), NOT NULL; chỉ lưu mật khẩu đã hash.
-   `email`: VARCHAR(100), NOT NULL, UNIQUE.
-   `role`: VARCHAR(20), NOT NULL, mặc định `USER`; giá trị `USER` hoặc
    `ADMIN`.
-   `status`: VARCHAR(20), NOT NULL, mặc định `ACTIVE`; giá trị
    `ACTIVE`, `INACTIVE`, `BANNED`.
-   `avatar`: VARCHAR(500), nullable.
-   `full_name`: VARCHAR(100), nullable.
-   `phone`: VARCHAR(20), nullable.
-   `address`: VARCHAR(255), nullable.
-   `bio`: TEXT, nullable.
-   `created_at`: DATETIME, tự động ghi nhận lúc tạo.
-   `updated_at`: DATETIME, tự động cập nhật lúc sửa.

### 3.2 `itineraries` --- Entity `Itinerary`

-   `itinerary_id`: INT, PK, auto-increment.
-   `user_id`: FK đến `users.user_id`, NOT NULL.
-   `original_itinerary_id`: FK tự tham chiếu
    `itineraries.itinerary_id`, nullable.
-   `title`: VARCHAR(150), NOT NULL.
-   `description`: TEXT, nullable.
-   `location`: VARCHAR(150), NOT NULL.
-   `total_days`: INT, NOT NULL, \> 0.
-   `budget`: DECIMAL(15,2), NOT NULL, mặc định 0, \>= 0.
-   `theme`: VARCHAR(100), nullable.
-   `visibility`: VARCHAR(20), NOT NULL, mặc định `PRIVATE`;
    `PUBLIC`/`PRIVATE`.
-   `status`: VARCHAR(20), NOT NULL, mặc định `ACTIVE`;
    `ACTIVE`/`HIDDEN`/`DELETED`.
-   `view_count`, `favorite_count`, `rating_count`, `comment_count`,
    `reuse_count`: INT, NOT NULL, mặc định 0, không âm.
-   `created_at`, `updated_at`: DATETIME, tự động quản lý.
-   Quan hệ: một User sở hữu nhiều Itinerary; một Itinerary có nhiều
    ItineraryDay; một Itinerary có thể có một Itinerary gốc thông qua
    `original_itinerary_id`.

### 3.3 `itinerary_days` --- Entity `ItineraryDay`

-   `day_id`: INT, PK, auto-increment.
-   `itinerary_id`: FK đến `itineraries.itinerary_id`, NOT NULL.
-   `day_number`: INT, NOT NULL, \> 0.
-   `title`: VARCHAR(150), nullable.
-   `date`: DATE, nullable.
-   `created_at`, `updated_at`: DATETIME.
-   Unique `(itinerary_id, day_number)`.

### 3.4 `destinations` --- Entity `Destination`

-   `destination_id`: INT, PK, auto-increment.
-   `name`: VARCHAR(150), NOT NULL.
-   `address`: VARCHAR(255), NOT NULL.
-   `description`: TEXT, nullable.
-   `image_url`: VARCHAR(500), nullable.
-   `latitude`: DECIMAL(10,7), nullable, từ -90 đến 90.
-   `longitude`: DECIMAL(10,7), nullable, từ -180 đến 180.
-   `status`: VARCHAR(20), NOT NULL, mặc định `ACTIVE`;
    `ACTIVE`/`HIDDEN`.
-   `created_at`, `updated_at`: DATETIME.

### 3.5 `activities` --- Entity `Activity`

-   `activity_id`: INT, PK, auto-increment.
-   `day_id`: FK đến `itinerary_days.day_id`, NOT NULL.
-   `destination_id`: FK đến `destinations.destination_id`, NOT NULL.
-   `name`: VARCHAR(150), NOT NULL.
-   `description`: TEXT, nullable.
-   `start_time`, `end_time`: TIME, nullable.
-   `cost`: DECIMAL(15,2), NOT NULL, mặc định 0, \>= 0.
-   `display_order`: INT, NOT NULL, \> 0.
-   `created_at`, `updated_at`: DATETIME.
-   Cân nhắc unique `(day_id, display_order)` để tránh trùng thứ tự
    trong cùng ngày.

### 3.6 `favorites` --- Entity `Favorite`

-   `favorite_id`: INT, PK, auto-increment.
-   `user_id`: FK đến `users.user_id`, NOT NULL.
-   `itinerary_id`: FK đến `itineraries.itinerary_id`, NOT NULL.
-   `created_at`: DATETIME.
-   Unique `(user_id, itinerary_id)`.

### 3.7 `saved_itineraries` --- Entity `SavedItinerary`

-   `save_id`: INT, PK, auto-increment.
-   `user_id`: FK đến `users.user_id`, NOT NULL.
-   `itinerary_id`: FK đến `itineraries.itinerary_id`, NOT NULL.
-   `created_at`: DATETIME.
-   Unique `(user_id, itinerary_id)`.

### 3.8 `ratings` --- Entity `Rating`

-   `rating_id`: INT, PK, auto-increment.
-   `user_id`: FK đến `users.user_id`, NOT NULL.
-   `itinerary_id`: FK đến `itineraries.itinerary_id`, NOT NULL.
-   `score`: INT, NOT NULL, từ 1 đến 5.
-   `created_at`, `updated_at`: DATETIME.
-   Unique `(user_id, itinerary_id)` để mỗi người có thể cập nhật đánh
    giá của mình thay vì tạo nhiều đánh giá.

### 3.9 `comments` --- Entity `Comment`

-   `comment_id`: INT, PK, auto-increment.
-   `user_id`: FK đến `users.user_id`, NOT NULL.
-   `itinerary_id`: FK đến `itineraries.itinerary_id`, NOT NULL.
-   `content`: TEXT, NOT NULL.
-   `status`: VARCHAR(20), NOT NULL, mặc định `ACTIVE`;
    `ACTIVE`/`HIDDEN`/`DELETED`.
-   `created_at`, `updated_at`: DATETIME.

### 3.10 `follows` --- Entity `Follow`

-   `follow_id`: INT, PK, auto-increment.
-   `follower_id`: FK đến `users.user_id`, NOT NULL.
-   `following_id`: FK đến `users.user_id`, NOT NULL.
-   `created_at`: DATETIME.
-   Unique `(follower_id, following_id)`.
-   Không cho phép người dùng theo dõi chính mình; kiểm tra ở service và
    thêm database constraint nếu phiên bản MySQL/cách triển khai phù
    hợp.

### 3.11 `itinerary_shares` --- Entity `ItineraryShare`

-   `share_id`: INT, PK, auto-increment.
-   `itinerary_id`: FK đến `itineraries.itinerary_id`, NOT NULL.
-   `share_token`: VARCHAR(255), NOT NULL, UNIQUE.
-   `created_at`: DATETIME.
-   `expires_at`: DATETIME, nullable.

### 3.12 `offline_downloads` --- Entity `OfflineDownload`

-   `download_id`: INT, PK, auto-increment.
-   `user_id`: FK đến `users.user_id`, NOT NULL.
-   `itinerary_id`: FK đến `itineraries.itinerary_id`, NOT NULL.
-   `downloaded_at`: DATETIME.

## 4. Quy tắc cho enum và giá trị mặc định

Có thể dùng Java enum cho: - `Role`: `USER`, `ADMIN`. - `UserStatus`:
`ACTIVE`, `INACTIVE`, `BANNED`. - `Visibility`: `PUBLIC`, `PRIVATE`. -
`ItineraryStatus`: `ACTIVE`, `HIDDEN`, `DELETED`. - `DestinationStatus`:
`ACTIVE`, `HIDDEN`. - `CommentStatus`: `ACTIVE`, `HIDDEN`, `DELETED`.

Nếu dùng enum, ánh xạ bằng `@Enumerated(EnumType.STRING)` để lưu chuỗi
có ý nghĩa, không lưu ordinal dạng số. Đảm bảo giá trị mặc định trong
Java và trong schema nhất quán. Với Hibernate, không giả định
`columnDefinition` tự bảo đảm default trong mọi tình huống; kiểm tra DDL
thực tế.

## 5. Quan hệ bắt buộc

-   `User` 1--N `Itinerary`.
-   `Itinerary` 1--N `ItineraryDay`.
-   `ItineraryDay` 1--N `Activity`.
-   `Destination` 1--N `Activity`.
-   `User` 1--N `Favorite`; `Itinerary` 1--N `Favorite`.
-   `User` 1--N `SavedItinerary`; `Itinerary` 1--N `SavedItinerary`.
-   `User` 1--N `Rating`; `Itinerary` 1--N `Rating`.
-   `User` 1--N `Comment`; `Itinerary` 1--N `Comment`.
-   `User` tham gia `Follow` ở hai vai trò `follower` và `following`.
-   `Itinerary` 1--N `ItineraryShare`.
-   `User` 1--N `OfflineDownload`; `Itinerary` 1--N `OfflineDownload`.
-   `Itinerary.original_itinerary_id` tham chiếu một `Itinerary` khác.

Không tự ý thêm bảng ngoài 12 bảng đã liệt kê. Không thêm các trường
không có trong thiết kế nếu không cần thiết để tương thích mã nguồn hiện
có; nếu bắt buộc phải khác, báo cáo rõ lý do.

## 6. Kiểm tra và hoàn thành

1.  Kiểm tra Entity/package hiện có, tái sử dụng class hợp lý và không
    tạo class trùng.
2.  Tạo hoặc cập nhật đủ 12 Entity cùng quan hệ, tên bảng/cột, unique
    constraint và khóa ngoại.
3.  Đảm bảo entity được Spring Boot component/entity scan.
4.  Kiểm tra cấu hình MySQL và `ddl-auto=update`.
5.  Chạy build Maven, sửa lỗi biên dịch do thay đổi.
6.  Hướng dẫn khởi động backend và chạy `SHOW TABLES;` trong database
    `travel_planner`.
7.  Kiểm tra các khóa ngoại và unique constraint bằng
    `SHOW CREATE TABLE ten_bang;`.
8.  Gọi lại `GET /api/health`, xác nhận vẫn trả HTTP 200 và JSON.
9.  Không báo thành công nếu chưa thực sự chạy build/kiểm tra; nếu môi
    trường không cho phép chạy, ghi rõ lệnh người dùng cần chạy.
10. Cuối cùng liệt kê file đã tạo/sửa, bảng được ánh xạ và những điểm
    còn cần xử lý.

Hãy thực hiện trực tiếp trên dự án hiện tại, thay đổi tối thiểu, không
xóa dữ liệu và không viết lại phần frontend.
