# 01. Đánh giá hiện trạng map trong lịch trình và hoạt động

Ngày: 05/11/2026. Đường dẫn mã bên dưới tính từ gốc Travel_Planner.

## 1. Luồng thực tế

~~~mermaid
flowchart LR
    A[Thêm hoặc sửa hoạt động] --> B[Chọn Destination]
    A --> C[LocationPickerSheet]
    C --> D[LocationRepository]
    D --> E[LocationController]
    E --> F[LocationServiceImpl và cache]
    F --> G[LocationIQ autocomplete hoặc reverse]
    C --> H[Ghim thủ công]
    B --> I[ItineraryServiceImpl.applyLocation]
    G --> I
    H --> I
    I --> J[Activity trong một ngày]
    J --> K[Timeline và bản đồ]
    K --> L[RouteService và OpenRouteService]
~~~

Bản đồ nền, tìm địa điểm, tính tuyến và ảnh là bốn năng lực khác nhau. Một bản đồ hiển thị đẹp không tự mang theo dữ liệu POI để tìm kiếm; kết quả geocoding không tự có ảnh.

## 2. Chức năng đã có và bằng chứng

| Hạng mục | Hiện trạng kiểm tra từ mã | File chính |
|---|---|---|
| Công nghệ | Spring Boot 4.1.1, Java 22 theo pom; hai frontend Flutter dùng chung backend | backend/pom.xml; frontend/*/pubspec.yaml |
| Danh mục địa điểm | Tên, địa chỉ, ảnh, tọa độ, ACTIVE/HIDDEN | model/Destination.java |
| Hoạt động | FK destination tùy chọn; customLocationName, customAddress, latitude, longitude, placeId, locationProvider | model/Activity.java |
| Quy tắc vị trí | Từ chối trộn catalog và custom; kiểm tra cặp tọa độ; chuyển trạng thái xóa trường cũ | service/impl/ItineraryServiceImpl.java, applyLocation |
| Tìm kiếm | GET /api/locations/search; autocomplete LocationIQ; quốc gia vn; ngôn ngữ vi,en | controller/LocationController.java; service/impl/LocationIqGeocodingProvider.java |
| Reverse geocoding | GET /api/locations/reverse-geocode; có fallback ghim tay phía mobile | LocationController; location_picker_sheet.dart |
| Cache và giới hạn | Caffeine 500 mục/cache, TTL 24 giờ; Bucket4j theo user/IP | LocationServiceImpl; service/LocationRateLimiter.java |
| Form hoạt động | Danh mục dạng dropdown và nút mở picker riêng | frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart |
| Map lịch trình | Marker theo ngày, điểm trùng được giãn hiển thị, chọn ngày, tuyến đường, chỉ đường ngoài app | itinerary_map_screen.dart; itinerary_map_helper.dart; navigation_launcher_helper.dart |
| Tính tuyến | ORS, driving/walking, cache kết quả tuyến 12 giờ, fallback đường thẳng | service/impl/RouteServiceImpl.java |
| Ảnh | Có upload Cloudinary; timeline hiển thị destination.imageUrl khi chọn danh mục | ImageUploadController; CloudinaryImageUploadService; activity_timeline_item.dart |
| Web | Có quản lý Destination và map; vai trò chính vẫn là quản trị | frontend/web/lib/features/locations; shared/widgets/web_map_view.dart |
| Kiểm thử | Có test địa điểm, chuyển trạng thái, route, picker, map, upload | backend/src/test và frontend/mobile/test |

Các file Java không ghi đầy đủ prefix trong bảng thuộc backend/src/main/java/Travel_Planner/Travel_Planner/. Các widget itinerary thuộc frontend/mobile/lib/features/itinerary/presentation/.

## 3. Các vấn đề cần ưu tiên

### P1 — Tính đúng của lựa chọn địa điểm

**Kết quả cũ có thể ghi đè lựa chọn mới.** Trong LocationPickerSheet, _searchRequestId chỉ tăng khi timer 400 ms thực sự chạy. Khi người dùng gõ truy vấn mới rồi xóa xuống dưới hai ký tự, request đang chạy chưa bị vô hiệu hóa ngay. Tương tự, chọn kết quả tìm kiếm không vô hiệu hóa reverse-geocode đang chờ; reverse cũ có thể đổi tên/ID nhưng giữ tọa độ của điểm vừa chọn.

Đây là nguy cơ suy ra trực tiếp từ mã bất đồng bộ, **chưa tái hiện trên thiết bị**. Cần regression test dùng Completer điều khiển thứ tự phản hồi rồi sửa generation chung cho lựa chọn.

**Không được biến tọa độ thiếu thành 0.** Provider parse lat/lon bằng asDouble(0.0); factory CustomLocationResult cũng có fallback 0.0. Nếu upstream thiếu dữ liệu, điểm có thể bị đưa về (0,0). _selectSearchResult còn giữ điểm trước đó khi kết quả mới không có tọa độ. Phải loại bỏ kết quả sai và không trộn metadata mới với tọa độ cũ. Tọa độ thực (0,0) vẫn hợp lệ về địa lý, không được cấm bằng quy tắc “0 là lỗi”.

### P1 — Hạn mức tổng và cấu hình

Limiter hiện giới hạn mỗi khách 30/phút hoặc người đăng nhập 60/phút. Nó không đảm bảo tổng lưu lượng nhiều người nằm dưới giới hạn của một tài khoản provider. Cache miss đồng thời cũng có thể tạo nhiều lệnh giống nhau.

Cần limiter toàn provider, gộp request trùng đang chạy, ngân sách ngày bền qua restart nếu muốn cam kết hard cap. Khi chạy nhiều backend replica, limiter chỉ trong RAM của từng máy là chưa đủ.

Provider chưa cấu hình đang trả danh sách rỗng. Người dùng không phân biệt được “không tìm thấy” và “chưa bật dịch vụ”. Thêm trạng thái dịch vụ rõ ràng trong contract mới, vẫn cho tìm danh mục và nhập vị trí thủ công.

### P1 — Trải nghiệm tìm kiếm chưa đúng trọng tâm

Picker gọi repository mà không truyền latitude/longitude mặc dù repository hỗ trợ hai trường này. Do đó chưa tận dụng bối cảnh khu vực. Adapter đang gửi lat/lon; cần đối chiếu tham số bias thực sự được hỗ trợ ở autocomplete, không mặc định nó hoạt động như reverse geocoding.

Chưa có luồng gợi ý theo nhóm điểm du lịch hoặc tìm trong vùng map. Địa điểm danh mục và địa điểm trực tuyến là hai thao tác riêng. Tên hoạt động chưa tự gợi ý từ địa điểm vừa chọn.

### P1 — Ảnh hoạt động còn thiếu

Activity, CreateActivityRequest, UpdateActivityRequest và ActivityResponse chưa có ảnh riêng. Timeline chỉ dùng ảnh của Destination; vị trí custom hiển thị icon ghim. Có upload ảnh ở hệ thống không có nghĩa ảnh đã gắn được vào Activity.

### P2 — Mô hình đọc vị trí và đồng bộ tuyến

ActivityDetail.effectiveLatitude/effectiveLongitude fallback theo từng trường; RouteServiceImpl chọn theo sự hiện diện của Destination rồi lấy cả cặp. Dữ liệu hợp lệ qua service thường không gây lệch, nhưng dữ liệu cũ hoặc sửa DB trực tiếp có thể khiến mobile và backend hiểu khác nhau. Chuẩn hóa một quy tắc chọn cả cặp, trả resolvedLocation từ backend ở giai đoạn nâng cấp.

Tên, địa chỉ và tọa độ của activity tham chiếu catalog được đọc từ Destination hiện tại. Admin sửa địa điểm có thể thay đổi hiển thị của các lịch trình cũ. Đây là ngữ nghĩa “tham chiếu sống”, không phải snapshot lịch sử; phải được ghi rõ.

Map dùng cache tuyến phía client theo dayNumber và request generation chung. Khi nâng cấp chỉnh sửa trực tiếp trên map, cần key theo dayId, mode, revision và kiểm thử đổi ngày nhanh. Không kết luận cache server đang sai: cache server đã chứa hash tọa độ theo thứ tự và chỉ lưu kết quả tuyến.

### P2 — Chất lượng ID và phân loại

Adapter ưu tiên ID OSM gồm loại và mã; nếu thiếu sẽ tạo loc_ theo thời gian. ID này không ổn định, có khả năng trùng cùng mili giây, không nên dùng làm khóa danh tính địa điểm. Category đang chọn class hoặc type, chưa giữ đầy đủ cả nhóm và loại chi tiết nên khó gợi ý riêng attraction/cafe/museum.

## 4. Chỗ tài liệu đã lệch mã

- docs/plan/01-map-integration-audit-and-plan.md phần đầu còn ghi Activity không có tọa độ, không có API search/route, chưa tích hợp flutter_map. Những câu này mô tả giai đoạn trước.
- docs/ai/01-architecture.md còn ghi SecurityConfig permitAll và chưa có JWT; mã hiện có JwtAuthenticationFilter và phân quyền.
- docs/ai/03-api-contract.md phần hoạt động chưa mô tả đủ trường custom location.
- docs/ai/12-project-status-and-next-steps.md ghi rating/favorite/saved chưa làm, trong khi controller/service tương ứng đã tồn tại và log cuối có các đợt triển khai sau.
- Đầu development log là ảnh chụp trạng thái lịch sử; không dùng để phủ định phần triển khai sau.

Bộ kế hoạch mới bổ sung đánh giá cập nhật; không xóa lịch sử hay giả định test cũ vẫn pass ở HEAD hiện tại.

## 5. Nhận xét tổng thể

Kiến trúc tách renderer, geocoding và routing là nền tốt cho ngân sách miễn phí. Quy tắc ba trạng thái vị trí có chủ đích và đã có test. Nên đầu tư vào tính đúng của picker, tìm kiếm theo ngữ cảnh, ảnh hoạt động, kiểm soát quota và đồng bộ tài liệu trước khi cân nhắc tái cấu trúc toàn bộ bảng.

Các module tài khoản, khám phá, xã hội và bộ sưu tập là ngữ cảnh phụ thuộc: nâng cấp map phải giữ quyền lịch trình, thứ tự ngày/hoạt động và phản hồi API hiện tại. Clone và offline toàn phần cần thiết kế tương thích nhưng không được đánh dấu đã có chỉ vì entity có trường liên quan.
