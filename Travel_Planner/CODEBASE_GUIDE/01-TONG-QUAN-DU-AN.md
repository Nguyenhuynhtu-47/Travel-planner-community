# 01. Tổng quan dự án Travel Planner

## Mục tiêu sản phẩm
Travel Planner cho phép tạo lịch trình theo ngày/hoạt động, khám phá và lưu lịch trình, quản lý địa điểm, bản đồ, tương tác cộng đồng và nhắn tin. Backend Spring Boot là nguồn nghiệp vụ/API; Flutter Mobile là ứng dụng người dùng chính; Flutter Web hiện là portal quản trị còn nhỏ, chưa phải dashboard hoàn chỉnh.

## Thành phần và công nghệ
| Phần | Hiện trạng trong source | Entry point |
|---|---|---|
| Backend | Java 22, Spring Boot, Spring MVC, JPA, Security, Validation, JWT, Maven | `backend/src/main/java/Travel_Planner/Travel_Planner/TravelPlannerApplication.java` |
| Mobile | Flutter/Dart, REST, flutter_map | `frontend/mobile/lib/main.dart` |
| Web | Flutter Web/Dart, xác thực, hồ sơ và một số màn hình quản trị | `frontend/web/lib/main.dart` |
| Database | MySQL qua JDBC/JPA; entity chỉ mô tả mapping trong code | `backend/src/main/resources/application*.properties` |
| Cấu hình | `.env.example`, Spring properties, `--dart-define` | README và cấu hình từng app |

## Sơ đồ kiến trúc
~~~mermaid
flowchart LR
 M[Flutter Mobile] -->|REST JSON + JWT| API[Spring Boot API]
 W[Flutter Web] -->|REST JSON + JWT| API
 API --> SEC[Spring Security]
 API --> S[Services]
 S --> R[Spring Data repositories]
 R --> DB[(MySQL)]
 S --> GEO[Geocoding / POI providers]
 S --> ROUTE[Routing provider]
 S --> MEDIA[Cloudinary]
 M -->|map tiles| CARTO[CARTO]
~~~
CARTO chỉ cung cấp tile nền. Search POI, geocoding, routing và ảnh là luồng riêng. Provider nào được dùng phụ thuộc cấu hình backend; không suy ra provider đang hoạt động chỉ từ source.

## Tính năng hiện diện trong code
Auth/session; itinerary/day/activity; map search, reverse geocoding và routing; Place catalog và itinerary-scoped saved places; comment threads; explore, saved/favorite/rating; social feed/posts; profile/follow; chat REST + WebSocket/STOMP; friendships/blocks/messaging settings; upload/media và một phần admin moderation/Place. Notification gồm Core API, các producer social/moderation, announcement, Mobile Center, và Android messaging push-only; schema theo entity JPA/Hibernate. Admin announcement dùng Flutter Web hiện có. Full release regression, FCM device delivery và production schema chưa xác minh.

## Quy mô source tại 2026-11-16
| Phạm vi | Source | Test |
|---|---:|---:|
| Backend Java | 267 | 51 |
| Mobile Dart (`lib`) | 128 | 43 |
| Web Dart (`lib`) | 27 | 6 |
| Tổng | 422 | 100 |

Đây là số file source/test theo thư mục lúc kiểm kê, không phải số tính năng hoàn chỉnh hoặc kết quả test. `CODEBASE_GUIDE` giữ nguyên bộ file và thứ tự đánh số đã có; xem các trang chuyên đề và file catalogue để lần theo code.

## Lộ trình
02 cây thư mục → 03 backend/API/security → 04 Java index → 05 dữ liệu/schema → 06 Mobile → 07 feature catalogue và 07A–07F → 08 core/shared → 09 Web → 10–12 tests → 13 luồng liên ứng dụng → 14 cấu hình → 15 bảo trì → 16 mục lục.
