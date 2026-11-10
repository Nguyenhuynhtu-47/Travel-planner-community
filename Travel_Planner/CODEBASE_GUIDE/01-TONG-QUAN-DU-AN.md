# 01. Tổng quan dự án Travel Planner

## Mục tiêu sản phẩm
Travel Planner hỗ trợ người dùng tự lập lịch chuyến đi theo ngày và hoạt động, đặt vị trí lên bản đồ, khám phá lịch trình công khai do cộng đồng tạo, lưu/yêu thích, đánh giá/bình luận và theo dõi người tạo. Backend giữ quy tắc nghiệp vụ và dữ liệu; Flutter Mobile tập trung hành trình người dùng; Flutter Web hiện là portal nhỏ cho đăng nhập, hồ sơ và quản trị điểm đến.

## Thành phần và công nghệ
| Phần | Xác minh trong source | Entry point |
|---|---|---|
| Backend | Java 22, Spring Boot, Spring MVC, JPA, Spring Security, Validation, JWT, Maven | backend/src/main/java/Travel_Planner/Travel_Planner/TravelPlannerApplication.java |
| Mobile | Flutter/Dart; http, flutter_map, latlong2, image_picker | frontend/mobile/lib/main.dart |
| Web | Flutter Web/Dart (không thấy React/Vue/Angular) | frontend/web/lib/main.dart |
| Database | MySQL qua JDBC/JPA; model classes là entity mapping | backend/src/main/resources/application.properties |
| Cấu hình | .env.example + Spring properties + dart-define | root .env.example, application*.properties, Flutter constants |

## Sơ đồ kiến trúc
~~~mermaid
flowchart LR
  M[Flutter Mobile] -->|REST JSON + Bearer JWT| API[Spring Boot REST API]
  W[Flutter Web Portal] -->|REST JSON + Bearer JWT| API
  API --> SEC[Spring Security + JWT filter]
  API --> S[Services / business rules]
  S --> R[Spring Data repositories]
  R --> E[JPA entities]
  E --> DB[(MySQL)]
  S --> GEO[LocationIQ / HERE / TomTom]
  S --> ROUTE[OpenRouteService]
  S --> MEDIA[Cloudinary]
  M -->|Raster tiles| CARTO[CARTO Basemaps]
~~~

CARTO chỉ tải nền map. Search/reverse-geocode là dịch vụ khác gọi từ client qua backend; route directions cũng là provider riêng. Không gửi credential provider từ Flutter, ngoại trừ CARTO public client key qua dart-define.

## Tính năng nhìn thấy trong code
Auth/session; hồ sơ; public handle @handle và tra profile theo handle; CRUD itinerary/day/activity; explore/filter/recommendation; location suggest/search/details/reverse/nearby; map pin/route; comments/replies; rating/favorite/save/follow; image upload; Web admin destination; data seeder. Đây là hiện diện trong source, không xác nhận provider key/runtime hoặc test pass.

## Số lượng đã kiểm kê ở nhánh develop
Backend 149 Java production + 27 tests. Mobile 100 Dart lib + 32 tests. Web 22 Dart lib + 5 tests. Tổng 271 source và 64 test files, chưa tính config/assets/generated. Thời điểm khảo sát: 2026-11-10.

## Lộ trình
02 cây thư mục → 03 backend → 04 Java index → 05 DB → 06 Mobile → 07 feature map và 07A–07F → 08 shared → 09 Web → 10–12 testing → 13 luồng → 14 config → 15 bảo trì → 16 mục lục.
