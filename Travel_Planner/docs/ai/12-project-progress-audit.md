# BÁO CÁO KIỂM TOÁN DỰ ÁN TOÀN DIỆN, TIẾN ĐỘ THỰC TẾ, CÁC VẤN ĐỀ KỸ THUẬT VÀ KẾ HOẠCH HÀNH ĐỘNG
## DỰ ÁN: TRAVEL PLANNER (KHÓA LUẬN / ĐỒ ÁN TỐT NGHIỆP)

---

## 1. Tóm tắt điều hành (Executive Summary)

Báo cáo kiểm toán này được thực hiện nhằm rà soát toàn diện hiện trạng mã nguồn, kiến trúc hệ thống, mức độ hoàn thiện tính năng, chất lượng kiểm thử và các rủi ro kỹ thuật của dự án **Travel Planner**. Dữ liệu kiểm toán được đối chiếu trực tiếp từ mã nguồn thực tế tại kho lưu trữ Git (nhánh `map`), tài liệu đặc tả chức năng ([`Travel_Planner_Function_Specification.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/Travel_Planner_Function_Specification.md)), tài liệu kiến trúc ([`01-architecture.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/01-architecture.md)), hệ thống thiết kế giao diện ([`04-ui-design-system.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/04-ui-design-system.md), [`DESIGN.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/DESIGN.md)), và kết quả thực thi các bộ kiểm thử tự động của cả ba thành phần: Backend (Spring Boot), Mobile (Flutter), và Web (Flutter Web).

### Tóm tắt kết quả kiểm toán chính:

1. **Về kiến trúc và động cơ cốt lõi (Core Engine):**
   Dự án đã xây dựng rất vững chắc và hoàn thiện phân hệ trung tâm của một nền tảng lập kế hoạch du lịch:
   - Hệ thống xác thực và ủy quyền bằng JWT không trạng thái (Stateless JWT Authentication & RBAC).
   - Quản trị hồ sơ cá nhân hoàn chỉnh trên cả Mobile và Web.
   - Luồng khám phá, tìm kiếm đa tiêu chí kết hợp bộ lọc (Keyword, ngân sách, số ngày, chủ đề, đánh giá), phân trang và sắp xếp.
   - Toàn bộ chu trình nghiệp vụ CRUD lịch trình cá nhân (Itinerary), quản lý ngày (Days) và quản lý hoạt động chi tiết (Activities) kèm thuật toán đổi thứ tự hai lượt (Two-pass Reordering) chống xung đột ràng buộc duy nhất trong cơ sở dữ liệu.
   - Hệ sinh thái Bản đồ & Định tuyến số hóa hoàn toàn miễn phí và độc lập (Decoupled Free-First Map Architecture): tích hợp bản đồ vector/raster thông qua `flutter_map` với CARTO Basemaps, định vị tọa độ và tìm kiếm địa điểm qua LocationIQ kèm bộ kiểm soát tần suất gọi (Token Bucket Rate Limiter), tính toán lộ trình từng ngày và toàn bộ chuyến đi qua OpenRouteService kết hợp bộ đệm in-memory và cơ chế tự suy biến dự phòng (Graceful Fallback), giải thuật phân tách tọa độ trùng điểm (Radial Jittering) và liên kết mở ứng dụng chỉ đường bản địa (Google Maps / Apple Maps).
   - Dịch vụ tải ảnh đám mây bảo mật qua Cloudinary API với cơ chế ký số SHA-1 ở backend.

2. **Chất lượng kiểm thử tự động (Automated Verification):**
   - **Backend (Spring Boot):** Đạt **157 / 157 bài kiểm thử thành công (100% pass, 0 lỗi, 0 thất bại)** với thời gian chạy 1 phút 32 giây.
   - **Mobile (Flutter):** Đạt **305 / 305 bài kiểm thử thành công (100% pass, 0 lỗi, 0 thất bại)** với thời gian chạy 51 giây.
   - **Web (Flutter Web):** Đạt **39 / 39 bài kiểm thử thành công (100% pass, 0 lỗi, 0 thất bại)** với thời gian chạy 6 giây.
   - **Tổng cộng:** **501 bài kiểm thử tự động toàn diện** bảo vệ hồi quy cho hệ thống.

3. **Hiện trạng mất cân đối và các mảng chức năng chưa hoàn thiện:**
   - **Phân hệ Web Admin còn sơ khai:** Web mới chỉ triển khai được phân hệ Đăng nhập, Hồ sơ và Quản lý danh mục Điểm đến (`AdminDestinationsScreen`). Toàn bộ các phân hệ quản trị then chốt khác gồm Dashboard thống kê số liệu, Quản lý người dùng, Kiểm duyệt lịch trình vi phạm, Kiểm duyệt đánh giá/bình luận, Xử lý vi phạm và Soạn gửi thông báo vẫn đang ở dạng thư mục trống (`.gitkeep`).
   - **Tính năng Cộng đồng & Tương tác xã hội trên Mobile chưa kết nối API:** Các tính năng Đánh giá (Rating), Lưu lịch trình (Saved Itineraries), Yêu thích (Favorites), Theo dõi người dùng (Follow), và Thông báo (Notifications) đã có sẵn Entity/Table trong MySQL và Seeder nhưng **hoàn toàn chưa có Controller/Service ở Backend** và giao diện Mobile mới chỉ hiển thị màn hình giữ chỗ (Placeholder Empty State).
   - **Tính năng cốt lõi Tái sử dụng lịch trình (Clone/Personalize Itinerary) chưa được hiện thực hóa:** Mặc dù bảng `itineraries` có trường `original_itinerary_id` và `reuse_count`, luồng nhân bản lịch trình của người khác để chỉnh sửa cá nhân hóa chưa có API xử lý.

4. **Cảnh báo an ninh và vận hành:**
   - Đã phát hiện thông tin xác thực bí mật của bên thứ ba (Cloudinary API Secret, OpenRouteService Key) bị lưu trữ dưới dạng văn bản thuần (plain text) trong tài liệu [`README.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/README.md#L11-L15). Cần lập tức thu hồi và đưa vào biến môi trường.
   - Cơ sở dữ liệu đang vận hành ở chế độ `hibernate.ddl-auto=update`, chưa có công cụ quản lý phiên bản lược đồ (Flyway/Liquibase).
   - Dự án chưa có cấu hình container hóa (Dockerfile / Docker Compose) và chưa thiết lập CI/CD pipeline.

---

## 2. Tổng quan tiến độ triển khai dự án (Overall Implementation Progress)

Dưới đây là bảng đánh giá chi tiết 13 module chức năng của dự án theo 4 mức độ chuẩn hóa:

| STT | Phân hệ / Module chức năng | Đánh giá hiện trạng | Ghi chú & Phạm vi hoàn thành |
| :--- | :--- | :--- | :--- |
| 1 | **Xác thực và phân quyền (Auth & RBAC)** | **Hoàn thành một phần (Partially completed)** | Hoàn tất đăng ký, đăng nhập JWT, giải mã phiên, phân quyền USER/ADMIN trên cả Backend, Mobile và Web. Thiếu quên mật khẩu, xác thực email, refresh token. |
| 2 | **Hồ sơ cá nhân (User Profile)** | **Hoàn thành một phần (Partially completed)** | Hoàn tất xem và cập nhật thông tin cá nhân (họ tên, bio, phone, address, avatar) trên Mobile và Web. Chưa có API xem hồ sơ người khác và chưa có cấu hình quyền riêng tư. |
| 3 | **Khám phá, Tìm kiếm, Lọc & Gợi ý (Explore)** | **Hoàn thành (Completed)** | Mobile & Backend hoàn chỉnh: Tìm kiếm từ khóa, lọc theo ngân sách/số ngày/chủ đề/rating, phân trang vô tận, gợi ý nổi bật, UI chuẩn Material 3 Airbnb-style. |
| 4 | **CRUD Lịch trình cá nhân (Itinerary CRUD)** | **Hoàn thành (Completed)** | Hoàn tất tạo, xem danh sách "Lịch trình của tôi", sửa, xóa mềm, đổi ảnh bìa, phân quyền chủ sở hữu. Chưa có tính năng Sao chép/Tái sử dụng (Clone). |
| 5 | **Quản lý Ngày, Hoạt động & Đổi thứ tự** | **Hoàn thành (Completed)** | Hoàn tất quản lý ngày, thêm/sửa/xóa hoạt động, gán chi phí, thời gian, đổi thứ tự hoạt động bằng thuật toán Two-Pass tránh xung đột Unique Constraint. |
| 6 | **Quản lý Điểm đến & Tìm kiếm vị trí** | **Hoàn thành (Completed)** | Hoàn tất trên cả 3 nền tảng: Backend API công khai và Admin CRUD; Mobile chọn điểm từ danh mục/tìm kiếm online/chấm trên bản đồ; Web quản trị điểm đến tương tác bản đồ. |
| 7 | **Tích hợp Bản đồ, Marker, Tuyến đường & Chỉ đường** | **Hoàn thành (Completed)** | Hoàn tất hiển thị bản đồ CARTO miễn phí, tính toán lộ trình từng ngày và toàn chuyến qua ORS, giải thuật Jitter chống đè marker, fallback đường chim bay, deep-link Google Maps. |
| 8 | **Bình luận, Đánh giá, Yêu thích & Lưu lịch trình** | **Hoàn thành một phần (Partially completed)** | Bình luận đã có API Đọc/Tạo và UI Mobile. Đánh giá (Rating), Yêu thích (Favorite), Lưu (Saved) mới chỉ có Database Entity/Seeder, chưa có API và UI. |
| 9 | **Theo dõi người dùng & Tính năng Cộng đồng** | **Chưa triển khai (Not implemented)** | Backend mới chỉ có Entity `Follow.java` và Seeder; Mobile chỉ có màn hình giữ chỗ `CommunityScreen`. |
| 10 | **Tải và lưu trữ hình ảnh (Image Upload)** | **Hoàn thành (Completed)** | Backend tích hợp Cloudinary có ký chữ ký bảo mật SHA-1, kiểm tra magic bytes; Mobile tích hợp upload ảnh bìa lịch trình và avatar; Web hỗ trợ nhập URL. |
| 11 | **Quản trị hệ thống trên Flutter Web** | **Hoàn thành một phần (Partially completed)** | Hoàn thành Quản lý Điểm đến (`AdminDestinationsScreen`); Chưa triển khai Dashboard thống kê, Quản lý người dùng, Kiểm duyệt nội dung, Xử lý vi phạm, Thông báo. |
| 12 | **UI/UX, Hiệu ứng chuyển động & Trạng thái lỗi** | **Hoàn thành (Completed)** | Áp dụng triệt để `DESIGN.md` và `10-animation-guidelines.md`. Đầy đủ Skeleton Shimmer, Empty State, Error Retry, Bottom Sheets, Button crossfading. |
| 13 | **Kiểm thử, An toàn bảo mật & Sẵn sàng triển khai** | **Cần xác minh / Hoàn thành một phần** | Bộ test đồ sộ (501 tests pass 100%). Tuy nhiên rủi ro lộ credential trong README, thiếu Docker, thiếu CI/CD và lược đồ DB phụ thuộc vào Hibernate update. |

---

## 3. Các tính năng đã hoàn thành và bằng chứng triển khai (Completed Features & Implementation Evidence)

### 3.1. Phân hệ Xác thực và Phân quyền (Authentication & Authorization)
- **Backend Implementation:**
  - Lớp điều khiển: [`AuthController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AuthController.java) cung cấp `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`.
  - Nghiệp vụ: [`AuthServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/AuthServiceImpl.java) mã hóa mật khẩu qua BCrypt (`PasswordEncoder`), kiểm tra trùng lặp email/username, cấp phát token JWT có thời hạn 24 giờ.
  - Bộ lọc bảo mật: [`JwtAuthenticationFilter.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/JwtAuthenticationFilter.java) và [`SecurityConfig.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java) thiết lập bộ lọc Stateless, bảo vệ các endpoint nhạy cảm qua `@PreAuthorize("hasRole('ADMIN')")`.
- **Frontend Mobile & Web:**
  - Mobile: [`login_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/auth/presentation/screens/login_screen.dart), [`register_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/auth/presentation/screens/register_screen.dart), lưu trữ token an toàn qua `FlutterSecureStorage` trong [`auth_storage.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/auth/data/auth_storage.dart).
  - Web: [`login_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/auth/presentation/screens/login_screen.dart), [`register_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/auth/presentation/screens/register_screen.dart), xử lý phân quyền điều hướng quản trị viên và người dùng thường.
  - Bắt lỗi phiên làm việc 401: Cả hai nền tảng đều có bộ đánh chặn lỗi `globalOnUnauthorized` tự động xóa token và chuyển người dùng về màn hình đăng nhập.
- **Bằng chứng kiểm thử:**
  - Backend: [`AuthControllerTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AuthControllerTest.java) và [`JwtTokenProviderTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/security/JwtTokenProviderTest.java) pass 100%.
  - Mobile: [`auth_401_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/auth_401_test.dart) pass 100%.
  - Web: [`auth_401_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/test/auth_401_test.dart) pass 100%.

### 3.2. Quản lý Hồ sơ người dùng (User Profile)
- **Backend Implementation:**
  - Lớp điều khiển: [`ProfileController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ProfileController.java) cung cấp `GET /api/user/profile` và `PUT /api/user/profile`.
  - Nghiệp vụ: [`ProfileServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ProfileServiceImpl.java) bảo vệ tính toàn vẹn dữ liệu, chỉ cho phép sửa `fullName`, `phone`, `address`, `bio`, `avatarUrl`; cấm sửa đổi `username`, `email`, `role`, `status`.
- **Frontend Implementation:**
  - Mobile: [`profile_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/profile/presentation/screens/profile_screen.dart) hỗ trợ xem thông tin, chỉnh sửa qua Dialog có form validation, tích hợp upload ảnh đại diện lên Cloudinary, thống kê số lịch trình đã tạo.
  - Web: [`profile_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/profile/presentation/screens/profile_screen.dart) giao diện chuẩn web responsive cho quản trị viên/người dùng.

### 3.3. Khám phá, Tìm kiếm, Lọc & Gợi ý (Explore & Search Engine)
- **Backend Implementation:**
  - Endpoints: `GET /api/itineraries` và `GET /api/itineraries/recommendations` trong [`ItineraryController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ItineraryController.java).
  - Nghiệp vụ: [`ItineraryServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java) kết hợp JPA Criteria/Specification ([`ItinerarySpecification.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/specification/ItinerarySpecification.java)) hỗ trợ lọc động đồng thời theo `keyword`, `location`, `theme`, khoảng ngân sách `minBudget` - `maxBudget`, số ngày `minDays` - `maxDays`, điểm đánh giá `minRating`, kèm trạng thái `ACTIVE` và chế độ `PUBLIC`.
- **Mobile Implementation:**
  - Giao diện: [`explore_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart).
  - Quản lý trạng thái: [`explore_notifier.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/explore/presentation/explore_notifier.dart) điều phối tìm kiếm có debounce chống spam request, phân trang cuộn vô tận (Infinite Scrolling), làm mới dữ liệu (Pull-to-refresh).
  - Thành phần UI chuyên sâu: [`filter_bottom_sheet.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/filter_bottom_sheet.dart) (chọn khoảng ngân sách, số ngày, rating), [`featured_itinerary_card.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/featured_itinerary_card.dart) (hiển thị thẻ nổi bật), [`compact_itinerary_card.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/explore/presentation/widgets/compact_itinerary_card.dart) (thẻ ngang cho danh mục chủ đề).
- **Bằng chứng kiểm thử:**
  - Mobile: [`explore_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/explore_test.dart), [`explore_sections_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/explore_sections_test.dart), [`filter_bottom_sheet_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/filter_bottom_sheet_test.dart) pass 100%.

### 3.4. Quản lý Lịch trình cá nhân (Itinerary CRUD)
- **Backend Implementation:**
  - Endpoints: `POST /api/itineraries`, `PUT /api/itineraries/{id}`, `DELETE /api/itineraries/{id}`, `GET /api/itineraries/{id}` trong [`ItineraryController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ItineraryController.java); và `GET /api/user/itineraries` trong [`UserItineraryController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/UserItineraryController.java).
  - Bảo mật quyền sở hữu: [`ItineraryServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java) xác thực người gửi request phải là chủ sở hữu hoặc quản trị viên; xóa lịch trình thực hiện theo cơ chế xóa mềm (`status = DELETED`).
- **Mobile Implementation:**
  - Giao diện: [`my_itineraries_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/my_itineraries_screen.dart) (danh sách chuyến đi của tôi, lọc theo trạng thái/quyền riêng tư), [`create_itinerary_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/create_itinerary_screen.dart), [`edit_itinerary_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/edit_itinerary_screen.dart), [`itinerary_detail_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart).
- **Bằng chứng kiểm thử:**
  - Backend: [`ItineraryControllerTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ItineraryControllerTest.java), [`ItineraryCrudTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ItineraryCrudTest.java) pass 100%.
  - Mobile: [`create_itinerary_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/create_itinerary_test.dart), [`my_itineraries_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/my_itineraries_test.dart), [`itinerary_edit_delete_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/itinerary_edit_delete_test.dart) pass 100%.

### 3.5. Quản lý Ngày, Hoạt động & Đổi thứ tự (Days, Activities & Reordering)
- **Backend Implementation:**
  - Quản lý Ngày: Thêm/sửa/xóa ngày với ràng buộc duy nhất `uk_itinerary_day_number (itinerary_id, day_number)`.
  - Quản lý Hoạt động: CRUD hoạt động trực thuộc ngày. Hỗ trợ đầy đủ chi phí (`cost`), thời gian bắt đầu/kết thúc (`startTime`, `endTime`), ghi chú (`notes`), liên kết điểm đến danh mục (`destination_id`) hoặc vị trí tùy chỉnh (`latitude`, `longitude`, `customLocationName`, `customAddress`).
  - Giải thuật đổi thứ tự hoạt động (Two-Pass Reordering): [`ItineraryServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java#L670-L730) giải quyết triệt để lỗi va chạm ràng buộc `uk_activity_order (day_id, order_index)` trong MySQL bằng cách gán chỉ số tạm âm ở lượt 1 và cập nhật vị trí chính thức ở lượt 2 trong cùng Transaction.
- **Mobile Implementation:**
  - Widgets: [`itinerary_day_card.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_day_card.dart), [`activity_timeline_item.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/activity_timeline_item.dart), [`activity_form_dialog.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart), [`reorder_activities_dialog.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/reorder_activities_dialog.dart).
- **Bằng chứng kiểm thử:**
  - Backend: [`ActivityLocationTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ActivityLocationTest.java) pass 100%.
  - Mobile: [`itinerary_day_management_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/itinerary_day_management_test.dart), [`itinerary_activity_management_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/itinerary_activity_management_test.dart) pass 100%.

### 3.6. Tích hợp Bản đồ, Định vị & Định tuyến (Decoupled Free-First Map Integration)
- **Kiến trúc bản đồ Decoupled Free-First:** Đã được thiết kế và triển khai hoàn hảo theo kế hoạch [`11-map-integration-audit-and-plan.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/11-map-integration-audit-and-plan.md).
- **Client Map Canvas:** Sử dụng `flutter_map: ^7.0.2` mã nguồn mở (MIT) trên cả Mobile và Web, không sử dụng Google Maps SDK thu phí hay platform view nặng nề. Nguồn tile raster kết nối trực tiếp đến CARTO Basemaps (`basemaps.cartocdn.com/rastertiles/voyager`) với hạn ngạch 5.000.000 tiles/tháng phục vụ nghiên cứu học tập, được cấu hình qua `--dart-define=CARTO_API_KEY=...`.
- **Geocoding & Reverse Geocoding Proxy:**
  - Backend: [`LocationController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/LocationController.java), [`LocationServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java), [`LocationIqGeocodingProvider.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationIqGeocodingProvider.java).
  - Kiểm soát giới hạn: [`LocationRateLimiter.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/LocationRateLimiter.java) áp dụng thuật toán Token Bucket (10 req/phút đối với IP khách vãng lai, 30 req/phút đối với người dùng đã đăng nhập) kết hợp phân giải IP tin cậy qua [`ClientIpResolver.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/ClientIpResolver.java).
- **Định tuyến Lộ trình (Routing Service):**
  - Endpoint: `GET /api/itineraries/{id}/days/{dayId}/route?mode=driving|walking|cycling` trong [`RouteController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/RouteController.java).
  - Tích hợp OpenRouteService: [`OpenRouteServiceRoutingProvider.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/OpenRouteServiceRoutingProvider.java) gọi API ORS chuẩn, lưu kết quả vào bộ đệm in-memory [`CachedRouteResult.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/CachedRouteResult.java) giảm thiểu tối đa quota API.
  - Tự động suy biến dự phòng (Graceful Fallback): [`RouteServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/RouteServiceImpl.java) tự động tính toán khoảng cách đường chim bay bằng công thức Haversine ([`HaversineUtil.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/util/HaversineUtil.java)) và trả về trạng thái `FALLBACK` khi thiếu API key hoặc vượt quá hạn ngạch, tuyệt đối không gọi trái phép máy chủ demo công cộng OSRM.
- **Hiển thị lộ trình đa ngày & Phân tách tọa độ trùng điểm (Sessions 81 & 82):**
  - Mobile: [`itinerary_map_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_map_screen.dart) hỗ trợ hai chế độ: "Tất cả" (hiển thị toàn bộ các ngày với màu sắc đa dạng riêng biệt $D1, D2,\dots$, tính tổng cự ly và thời gian của cả chuyến đi) và "Từng ngày" (chỉ hiển thị marker và tuyến đường của ngày được chọn).
  - Không nối dây ảo giữa các ngày: Tuyến đường cuối ngày $K$ hoàn toàn ngắt rời và không vẽ đường thẳng nối sang đầu ngày $K+1$.
  - Thuật toán Radial Jittering: [`itinerary_map_helper.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_map_helper.dart#L25-L65) tự động dịch chuyển góc lệch tâm khoảng 18m ($0.00018^\circ$) đối với các hoạt động có cùng tọa độ địa lý, giúp các marker ngày trước không bị ngày sau che khuất hoàn toàn.
  - Điều hướng ngoại vi: [`navigation_launcher_helper.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/navigation_launcher_helper.dart) mở trực tiếp ứng dụng Google Maps / Apple Maps qua Deep Link URL hoàn toàn miễn phí.
- **Bằng chứng kiểm thử:**
  - Backend: [`LocationServiceTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/LocationServiceTest.java) (33 tests), [`RouteServiceTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/RouteServiceTest.java), [`OpenRouteServiceRoutingProviderTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/OpenRouteServiceRoutingProviderTest.java) pass 100%.
  - Mobile: [`itinerary_map_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/itinerary_map_test.dart) (28 tests), [`itinerary_route_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/itinerary_route_test.dart) (20 tests), [`location_picker_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/location_picker_test.dart), [`map_api_key_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/map_api_key_test.dart) pass 100%.

### 3.7. Quản lý Điểm đến trên Flutter Web (Admin Destination Portal)
- **Backend Implementation:**
  - Lớp điều khiển: [`AdminDestinationController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdminDestinationController.java) cung cấp đầy đủ các thao tác CRUD: `GET /api/admin/destinations`, `POST /api/admin/destinations`, `PUT /api/admin/destinations/{id}`, `DELETE /api/admin/destinations/{id}` (xóa mềm với trạng thái `HIDDEN`), được bảo vệ bằng `@PreAuthorize("hasRole('ADMIN')")`.
- **Flutter Web Implementation:**
  - Giao diện: [`admin_destinations_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/locations/presentation/screens/admin_destinations_screen.dart) hỗ trợ quản trị viên tìm kiếm theo từ khóa, lọc theo trạng thái (`ACTIVE`/`HIDDEN`), xem chi tiết điểm đến trên bản đồ.
  - Form tạo/sửa: [`destination_form_dialog.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/locations/presentation/widgets/destination_form_dialog.dart) tích hợp bản đồ tương tác [`web_map_view.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/shared/widgets/web_map_view.dart) cho phép click chuột trực tiếp lên bản đồ để chọn tọa độ vĩ độ/kinh độ chính xác.
  - Dialog xác nhận ẩn: [`hide_destination_dialog.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/lib/features/locations/presentation/widgets/hide_destination_dialog.dart) cảnh báo an toàn trước khi ẩn điểm đến khỏi hệ thống công cộng.
- **Bằng chứng kiểm thử:**
  - Backend: [`AdminDestinationControllerTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AdminDestinationControllerTest.java) pass 100%.
  - Web: [`admin_destination_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/test/admin_destination_test.dart), [`web_map_api_key_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/web/test/web_map_api_key_test.dart) pass 100%.

### 3.8. Tải và Lưu trữ Hình ảnh (Cloudinary Image Upload)
- **Backend Implementation:**
  - Endpoint: `POST /api/media/images` (`multipart/form-data`) trong [`ImageUploadController.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ImageUploadController.java).
  - Nghiệp vụ: [`CloudinaryImageUploadService.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/CloudinaryImageUploadService.java) kiểm tra kích thước file $\le 5$ MiB, kiểm tra magic bytes của mảng nhị phân để xác định đúng định dạng ảnh (JPEG, PNG, WebP), tự động tính mã băm chữ ký số SHA-1 kết hợp `timestamp` và `api_secret`, tải trực tiếp lên Cloudinary REST API qua Spring 6 `RestClient`.
- **Frontend Implementation:**
  - Mobile: [`image_upload_service.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/shared/services/image_upload_service.dart) tích hợp `image_picker`, áp dụng trong việc tải ảnh bìa lịch trình và ảnh đại diện người dùng.
- **Bằng chứng kiểm thử:**
  - Backend: [`CloudinaryImageUploadServiceTest.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/CloudinaryImageUploadServiceTest.java) pass 100%.
  - Mobile: [`image_upload_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/image_upload_test.dart) pass 100%.

---

## 4. Các tính năng hoàn thành một phần và còn thiếu (Partially Completed and Missing Features)

Dưới đây là chi tiết các khoảng trống tính năng (Feature Gaps) được phát hiện khi đối chiếu mã nguồn thực tế với Đặc tả chức năng dự án:

### 4.1. Phân hệ Tài khoản và Xác thực (Auth)
- **Chưa có chức năng Khôi phục mật khẩu (Forgot/Reset Password):** Người dùng quên mật khẩu không có cơ chế tự đặt lại (chưa có endpoint `/api/auth/forgot-password` hay gửi mail OTP).
- **Chưa có Xác thực địa chỉ Email (Email Verification):** Tài khoản sau khi đăng ký được cấp quyền `USER` ngay lập tức mà không cần xác nhận hòm thư.
- **Chưa có Cơ chế Làm mới phiên (Refresh Token):** Khi JWT 24h hết hạn, người dùng bị đẩy về trang đăng nhập mà không có cơ chế gia hạn token tự động trong nền (Silent Refresh).
- **Chưa hỗ trợ Đăng nhập mạng xã hội (OAuth2/SSO):** Chưa có tích hợp Google Sign-in.

### 4.2. Phân hệ Hồ sơ và Quyền riêng tư (User Profile & Privacy)
- **Chưa có trang Xem hồ sơ công khai của người dùng khác:** Hệ thống thiếu endpoint `GET /api/users/{id}` để người dùng xem thông tin tác giả của một lịch trình (chỉ mới xem được hồ sơ chính mình qua `GET /api/user/profile`).
- **Chưa có Cài đặt quyền riêng tư (Privacy Settings):** Chưa có giao diện và API cho phép người dùng tùy chọn ẩn/hiện danh sách lịch trình đã lưu hoặc thông tin cá nhân đối với cộng đồng.

### 4.3. Phân hệ Tái sử dụng và Cá nhân hóa lịch trình (Itinerary Reuse / Clone)
- **Chưa hiện thực hóa tính năng Clone Lịch trình:** Mặc dù mô hình dữ liệu [`Itinerary.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/Itinerary.java) đã có cột khóa ngoại `original_itinerary_id` và bộ đếm `reuse_count`, hệ thống backend **chưa có endpoint** `POST /api/itineraries/{id}/clone` và frontend mobile chưa có nút hành động "Sao chép chuyến đi này". Đây là tính năng cốt lõi được nhấn mạnh trong mục tiêu của đề tài "Travel Planner Community".

### 4.4. Bình luận, Đánh giá và Tương tác yêu thích (Interactions)
- **Bình luận (Comments):** Mới chỉ hỗ trợ lấy danh sách (`GET`) và gửi bình luận mới (`POST`). Chưa có chức năng Chỉnh sửa (`PUT`), Xóa bình luận (`DELETE`) của chính mình, và chưa có API cho Quản trị viên xóa bình luận vi phạm.
- **Đánh giá (Ratings):** Mặc dù bảng `ratings` và [`RatingRepository.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/RatingRepository.java) đã tồn tại (phục vụ Seeder), **hoàn toàn chưa có Controller và Service** để người dùng gửi hoặc cập nhật số sao đánh giá (1–5 sao). Thư mục [`frontend/mobile/lib/features/reviews`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/reviews) chỉ chứa file rỗng `.gitkeep`.
- **Yêu thích (Favorites) & Lưu lịch trình (Saved Itineraries):** Bảng `favorites` và `saved_itineraries` đã có Seeder nhưng chưa có API endpoints (`POST /api/itineraries/{id}/save`, `DELETE /api/itineraries/{id}/save`, `GET /api/user/saved-itineraries`). Màn hình [`saved_itineraries_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/saved_itineraries/presentation/screens/saved_itineraries_screen.dart) trên mobile hiện tại là màn hình rỗng dạng placeholder.

### 4.5. Tính năng Cộng đồng và Theo dõi (Community & Social)
- **Theo dõi tác giả (Follow):** Bảng `follows` và [`FollowRepository.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/FollowRepository.java) chỉ dùng trong Seeder. Chưa có endpoint `POST /api/users/{id}/follow` hay danh sách người theo dõi.
- **Màn hình cộng đồng:** [`community_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/social/presentation/screens/community_screen.dart) trên mobile chỉ là giao diện giữ chỗ ("Tính năng đang phát triển").

### 4.6. Phân hệ Quản trị hệ thống trên Flutter Web (Web Administration)
Ngoài phân hệ Quản lý Điểm đến đã hoàn thành, toàn bộ các chức năng quản trị còn lại trên Flutter Web đều chưa được lập trình (thư mục chỉ chứa `.gitkeep`):
- **Bảng điều khiển & Thống kê (Dashboard):** Chưa có màn hình và API thống kê tổng quan (số người dùng mới, số lịch trình tạo theo tháng, biểu đồ hoạt động).
- **Quản lý người dùng (User Management):** Chưa có giao diện danh sách người dùng, chức năng khóa tài khoản (`LOCKED`), mở khóa hoặc đổi vai trò (`ROLE`).
- **Kiểm duyệt lịch trình (Itinerary Moderation):** Chưa có giao diện cho Admin duyệt, ẩn hoặc gỡ bỏ các lịch trình có nội dung phản cảm/vi phạm bản quyền.
- **Kiểm duyệt bình luận & Đánh giá (Review Moderation):** Chưa có giao diện xem xét và xóa bình luận độc hại.
- **Xử lý báo cáo vi phạm (Violation Handling):** Chưa có luồng tiếp nhận và xử lý báo cáo từ người dùng.
- **Hệ thống Thông báo (Admin Notifications):** Chưa có chức năng soạn thông báo và gửi đến toàn thể người dùng.

---

## 5. Các lỗi và vấn đề kỹ thuật hiện tại (Current Bugs & Technical Problems)

Dưới đây là bảng tổng hợp các vấn đề kỹ thuật thực tế được phát hiện, phân loại chi tiết theo 9 trường chuẩn hóa:

### 5.1. Vấn đề An ninh & Cấu hình Credential
| Trường | Chi tiết |
| :--- | :--- |
| **Vấn đề (Problem)** | Lộ thông tin bí mật (API Secret và API Key) của dịch vụ bên thứ ba trong tài liệu hướng dẫn. |
| **Hành vi hiện tại** | File [`README.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/README.md#L11-L15) chứa trực tiếp `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, và chuỗi token `OPENROUTESERVICE_API_KEY` dưới dạng văn bản thuần. |
| **Hành vi kỳ vọng** | File README chỉ nên chứa giá trị mẫu giả định (placeholder như `<your_api_secret>`), các khóa thật phải được lưu trữ trong biến môi trường bảo mật của máy cá nhân và không bao giờ commit vào Git. |
| **Nguyên nhân** | Lập trình viên viết tài liệu hướng dẫn khởi chạy local tiện lợi nhưng vô tình copy trực tiếp chuỗi credential thật vào file. |
| **Mức độ ảnh hưởng** | Nguy cơ bị quét mã nguồn công khai, lạm dụng tài khoản Cloudinary (chiếm dụng dung lượng) và làm cạn kiệt hạn ngạch OpenRouteService. |
| **Mức độ nghiêm trọng** | **Critical (Nghiêm trọng)** |
| **Biện pháp tạm thời** | Tài khoản hiện tại thuộc gói miễn phí cá nhân phục vụ phát triển. |
| **Giải pháp đề xuất** | Lập tức thu hồi (Revoke/Regenerate) API Secret trên Cloudinary và OpenRouteService, xóa chuỗi thật khỏi `README.md`, thay bằng placeholder. |
| **Cần GVHD can thiệp** | Không (Nhóm tự xử lý ngay). |

---

### 5.2. Vấn đề Tính năng Cốt lõi: Thiếu API & UI Tái sử dụng lịch trình (Clone Itinerary)
| Trường | Chi tiết |
| :--- | :--- |
| **Vấn đề (Problem)** | Người dùng không thể sao chép một lịch trình công khai của người khác về tài khoản của mình để chỉnh sửa cá nhân hóa. |
| **Hành vi hiện tại** | Khi xem lịch trình của tác giả khác trên mobile, người dùng chỉ có thể xem chi tiết và bình luận; không có nút "Sao chép lịch trình". Backend cũng chưa có API clone. |
| **Hành vi kỳ vọng** | Người dùng nhấn "Sao chép lịch trình", backend tạo một bản sao độc lập (`Itinerary` mới thuộc về người dùng hiện tại, kèm toàn bộ `Days` và `Activities` sao chép), lưu `original_itinerary_id` trỏ về lịch trình gốc, tăng `reuse_count` của lịch trình gốc thêm 1. |
| **Nguyên nhân** | Chưa được phân công lập trình ở các phiên trước (ưu tiên tập trung vào hoàn thiện Map Engine và CRUD cá nhân). |
| **Mức độ ảnh hưởng** | Ảnh hưởng trực tiếp đến mục tiêu cốt lõi của đề tài "Travel Planner Community" (nền tảng chia sẻ và tái sử dụng chuyến đi). |
| **Mức độ nghiêm trọng** | **High (Cao)** |
| **Biện pháp tạm thời** | Người dùng phải tự tạo thủ công lịch trình mới và nhập lại từng địa điểm. |
| **Giải pháp đề xuất** | Triển khai endpoint `POST /api/itineraries/{id}/clone` trong `ItineraryServiceImpl` (deep copy entities trong 1 transaction) và thêm nút "Sao chép" trên `ItineraryDetailScreen`. |
| **Cần GVHD can thiệp** | Cần trao đổi xác nhận quy tắc nghiệp vụ (bản sao có cho phép đổi số ngày không, có giữ lại chi phí ước tính không). |

---

### 5.3. Vấn đề Tính năng Cốt lõi: Thiếu API & UI Lưu lịch trình (Save/Favorite) và Đánh giá (Rating)
| Trường | Chi tiết |
| :--- | :--- |
| **Vấn đề (Problem)** | Người dùng không thể lưu lịch trình yêu thích để xem lại sau và không thể chấm điểm đánh giá số sao. |
| **Hành vi hiện tại** | Entity `SavedItinerary`, `Favorite`, `Rating` đã tạo trong MySQL và có dữ liệu seed. Tuy nhiên `SavedItinerariesScreen` trên mobile chỉ hiển thị thông báo rỗng "Đang phát triển", icon Bookmark/Heart chưa gọi API thực, không có modal chọn số sao. |
| **Hành vi kỳ vọng** | Người dùng nhấn Bookmark để lưu/hủy lưu lịch trình; mở tab "Lịch trình đã lưu" để xem danh sách chuyến đi đã bookmark; nhấn đánh giá để gửi điểm 1–5 sao và cập nhật điểm trung bình của lịch trình. |
| **Nguyên nhân** | Chưa xây dựng tầng Controller và Service cho các repository này. |
| **Mức độ ảnh hưởng** | Người dùng không lưu được chuyến đi tham khảo; dữ liệu rating hiển thị trên thẻ khám phá hiện tại là dữ liệu seed cố định. |
| **Mức độ nghiêm trọng** | **High (Cao)** |
| **Biện pháp tạm thời** | Hiển thị màn hình rỗng `AppEmptyState` trên mobile. |
| **Giải pháp đề xuất** | Xây dựng `SavedItineraryController` (`POST/DELETE /api/itineraries/{id}/save`, `GET /api/user/saved-itineraries`) và `RatingController` (`POST /api/itineraries/{id}/rating`). |
| **Cần GVHD can thiệp** | Cần xin ý kiến về điều kiện đánh giá (có cần quy định phải sao chép lịch trình rồi mới được đánh giá không). |

---

### 5.4. Vấn đề Phạm vi Phân hệ Web Admin chưa hoàn thiện
| Trường | Chi tiết |
| :--- | :--- |
| **Vấn đề (Problem)** | Phân hệ Web Admin mới chỉ có màn hình Quản lý Điểm đến, thiếu Dashboard thống kê, Quản lý người dùng, và Kiểm duyệt nội dung. |
| **Hành vi hiện tại** | Khi đăng nhập tài khoản ADMIN trên Flutter Web, chỉ có thể bấm vào menu "Quản lý điểm đến"; các mục khác trên Web chưa có giao diện. |
| **Hành vi kỳ vọng** | Web Admin phải cung cấp bảng điều khiển thống kê (Dashboard), danh sách quản lý người dùng (khóa/mở tài khoản), và danh sách duyệt/gỡ lịch trình vi phạm theo đúng Đặc tả chức năng §12. |
| **Nguyên nhân** | Thời gian phát triển trước đây tập trung phần lớn vào Backend và Mobile Native; Web Admin mới bắt đầu được tích hợp từ Session 76. |
| **Mức độ ảnh hưởng** | Quản trị viên chưa có công cụ quản trị nội dung người dùng trên nền tảng Web; ảnh hưởng đến tiêu chí đánh giá phân hệ Web của đồ án. |
| **Mức độ nghiêm trọng** | **High (Cao)** |
| **Biện pháp tạm thời** | Quản trị viên chỉ có thể quản lý điểm đến trên Web; việc xử lý người dùng/lịch trình vi phạm phải can thiệp trực tiếp vào database MySQL. |
| **Giải pháp đề xuất** | Lập trình bổ sung các màn hình Web Admin theo thứ tự ưu tiên: 1. Quản lý người dùng; 2. Kiểm duyệt lịch trình; 3. Dashboard thống kê. |
| **Cần GVHD can thiệp** | Cần GVHD xác nhận mức độ hoàn thiện tối thiểu của Web Admin để đáp ứng yêu cầu nghiệm thu đồ án. |

---

### 5.5. Vấn đề Quản lý Lược đồ Cơ sở Dữ liệu (Database Migration)
| Trường | Chi tiết |
| :--- | :--- |
| **Vấn đề (Problem)** | Cơ sở dữ liệu đang vận hành ở chế độ `hibernate.ddl-auto=update` thay vì sử dụng công cụ quản lý phiên bản lược đồ chuyên nghiệp. |
| **Hành vi hiện tại** | Khi Spring Boot khởi động, Hibernate tự động so sánh entity Java và sửa cấu trúc bảng trong MySQL. |
| **Hành vi kỳ vọng** | Lược đồ cơ sở dữ liệu phải được quản lý bằng các tệp migration script SQL tuần tự (Flyway hoặc Liquibase) để đảm bảo tính nhất quán giữa môi trường dev, test và production, tránh rủi ro mất dữ liệu khi sửa model. |
| **Nguyên nhân** | Thiết lập ban đầu để tiện cho việc thay đổi nhanh mô hình trong giai đoạn tạo mẫu (prototyping). |
| **Mức độ ảnh hưởng** | Hibernate `ddl-auto=update` không bao giờ tự xóa cột cũ, không đổi tên cột, có thể tạo ra các khóa ngoại hoặc chỉ mục rác qua nhiều lần refactor. |
| **Mức độ nghiêm trọng** | **Medium (Trung bình)** |
| **Biện pháp tạm thời** | Dữ liệu kiểm thử được kiểm soát qua bộ `DataSeeder` idempotent. |
| **Giải pháp đề xuất** | Đóng băng lược đồ hiện tại, trích xuất file `schema.sql` hoàn chỉnh và tích hợp Flyway Migration trước khi triển khai chính thức. |
| **Cần GVHD can thiệp** | Không (Nhóm tự thực hiện khi hoàn tất các tính năng). |

---

### 5.6. Vấn đề Tìm kiếm Tiếng Việt không dấu (Unaccented Search)
| Trường | Chi tiết |
| :--- | :--- |
| **Vấn đề (Problem)** | Tìm kiếm lịch trình và địa điểm phụ thuộc vào toán tử `LIKE %keyword%` của MySQL, chưa hỗ trợ triệt để tìm kiếm tiếng Việt không dấu. |
| **Hành vi hiện tại** | Nếu người dùng gõ từ khóa không dấu như "da lat", kết quả tìm kiếm có thể không khớp với các bản ghi lưu "Đà Lạt" nếu collation của cột không phải là `utf8mb4_unicode_ci` hoặc nếu tìm kiếm chuỗi tùy chỉnh. |
| **Hành vi kỳ vọng** | Người dùng gõ "da nang" hay "đà nẵng", "ha noi" hay "hà nội" đều tìm thấy kết quả chính xác như nhau. |
| **Nguyên nhân** | Truy vấn backend đang dùng `cb.like(cb.lower(...))` tiêu chuẩn của JPA Specification, chưa cấu hình hàm chuẩn hóa bỏ dấu tiếng Việt hoặc Full-Text Indexing. |
| **Mức độ ảnh hưởng** | Trải nghiệm tìm kiếm của người dùng trên thiết bị di động bị giảm sút khi gõ nhanh không dấu. |
| **Mức độ nghiêm trọng** | **Medium (Trung bình)** |
| **Biện pháp tạm thời** | Collation database mặc định là `utf8mb4` có hỗ trợ một phần case-insensitive. |
| **Giải pháp đề xuất** | Bổ sung hàm chuẩn hóa bỏ dấu (`removeAccents`) ở backend hoặc áp dụng Full-Text Search với bộ phân tích từ tiếng Việt. |
| **Cần GVHD can thiệp** | Cần thảo luận xem phạm vi đồ án có yêu cầu tìm kiếm nâng cao (Elasticsearch/Full-Text) hay chỉ cần xử lý chuỗi ở mức cơ bản. |

---

### 5.7. Vấn đề Cảnh báo Phân tích Mã tĩnh (Static Analysis Warning) trên Mobile
| Trường | Chi tiết |
| :--- | :--- |
| **Vấn đề (Problem)** | Lệnh `flutter analyze` trên `frontend/mobile` trả về exit code 1 do có 1 cảnh báo linter. |
| **Hành vi hiện tại** | File [`frontend/mobile/test/filter_bottom_sheet_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/filter_bottom_sheet_test.dart#L25) chứa `__` (hai dấu gạch dưới liên tiếp): `info - Unnecessary use of multiple underscores. Try using '_' - unnecessary_underscores`. |
| **Hành vi kỳ vọng** | `flutter analyze` chạy sạch hoàn toàn (0 errors, 0 warnings, 0 issues), exit code 0 tương tự như trên `frontend/web`. |
| **Nguyên nhân** | Khai báo tham số bỏ qua trong hàm callback test dùng `__` thay vì `_`. |
| **Mức độ ảnh hưởng** | Không ảnh hưởng đến logic thực thi hay kết quả test (305/305 tests vẫn pass), nhưng gây lỗi gián đoạn nếu cấu hình CI/CD bắt buộc `flutter analyze` phải exit 0. |
| **Mức độ nghiêm trọng** | **Low (Thấp)** |
| **Biện pháp tạm thời** | Đã ghi nhận trong báo cáo kiểm toán (tuân thủ nguyên tắc không chỉnh sửa code trong nhiệm vụ audit). |
| **Giải pháp đề xuất** | Đổi `__` thành `_` tại dòng 25 file `filter_bottom_sheet_test.dart` trong lượt task code tiếp theo. |
| **Cần GVHD can thiệp** | Không (Nhóm tự xử lý). |

---

## 6. Giới hạn kỹ thuật và các quyết định chưa chốt (Technical Limitations and Unresolved Decisions)

### 6.1. Giới hạn kỹ thuật và Phụ thuộc Dịch vụ bên ngoài
1. **Hạn ngạch miễn phí của các nhà cung cấp bản đồ & định tuyến:**
   - **CARTO Basemaps:** Miễn phí 5.000.000 tile requests/tháng cho mục đích nghiên cứu học tập phi thương mại (`TLCN`). Đây là hạn mức rất rộng rãi, hoàn toàn đủ cho nhu cầu thử nghiệm và bảo vệ đồ án. Tuy nhiên, nếu sau này thương mại hóa sản phẩm, chính sách CARTO giới hạn xuống 1.000.000 requests/tháng và yêu cầu đăng ký gói trả phí.
   - **LocationIQ Geocoding API:** Gói miễn phí giới hạn nghiêm ngặt **5.000 requests/ngày** và **tối đa 2 requests/giây**. Hệ thống đã phòng thủ bằng bộ đệm rate limiter ở backend (10 req/phút đối với khách vãng lai, 30 req/phút đối với người dùng đăng nhập), tuy nhiên nếu nhiều người dùng cùng tìm kiếm vị trí liên tục trong buổi bảo vệ thì có nguy cơ chạm ngưỡng 2 req/giây của LocationIQ.
   - **OpenRouteService (ORS) Routing API:** Gói tiêu chuẩn miễn phí giới hạn **2.000 requests/ngày** và **tối đa 40 requests/phút**. Hệ thống đã có cơ chế đệm in-memory và tự động suy biến về tính cự ly thẳng (Haversine fallback) khi gặp lỗi hoặc hết hạn ngạch.
2. **Khả năng hoạt động Ngoại tuyến (Offline Capabilities):**
   - Mặc dù database có bảng `offline_downloads`, ứng dụng hiện tại phụ thuộc hoàn toàn vào kết nối Internet để tải tile bản đồ và gọi API. Nếu thiết bị mất mạng, ứng dụng không thể hiển thị bản đồ raster và không thể đồng bộ lịch trình.
3. **Môi trường triển khai:**
   - Chưa có kịch bản Docker hóa cho cả 3 thành phần (Backend Spring Boot, MySQL, Nginx phục vụ Flutter Web). Hiện tại ứng dụng đang chạy cục bộ trên máy host qua lệnh `mvnw spring-boot:run` và `flutter run`.

---

### 6.2. Các quyết định chưa chốt (Unresolved Decisions) & Đánh giá phương án

Dưới đây là 5 quyết định nghiệp vụ và kiến trúc quan trọng nhất cần chốt định hướng với Giảng viên Hướng dẫn:

#### Quyết định 1: Định vị vai trò và phạm vi của nền tảng Flutter Web
- **Bối cảnh:** Đặc tả chức năng (§1 & §13) ghi nhận Flutter Web ưu tiên giao diện quản trị (Admin Portal). Tuy nhiên chưa chốt dứt khoát liệu Web có cần phục vụ cả người dùng cuối (End-User) để họ xem và tạo lịch trình trên trình duyệt máy tính hay không.
- **Phương án A (Chỉ làm Web Admin - Đề xuất của nhóm):** Web chỉ dành riêng cho Quản trị viên (Admin) để quản lý điểm đến, người dùng, kiểm duyệt nội dung và xem thống kê; toàn bộ trải nghiệm người dùng du lịch được tập trung tối ưu trên Flutter Mobile.
  - *Ưu điểm:* Tiết kiệm 50% khối lượng giao diện Web; tránh phân mảnh nguồn lực phát triển; tối ưu sâu cho trải nghiệm cảm ứng di động; rất phù hợp với thời gian còn lại của đồ án tốt nghiệp.
  - *Nhược điểm:* Người dùng không thể tạo lịch trình trực tiếp trên trình duyệt máy tính để bàn.
- **Phương án B (Web phục vụ cả User và Admin):** Xây dựng đầy đủ màn hình Khám phá, Tạo lịch trình, Chi tiết chuyến đi responsive trên cả Web.
  - *Ưu điểm:* Trải nghiệm đa nền tảng hoàn hảo cho người dùng.
  - *Nhược điểm:* Khối lượng công việc cực kỳ lớn, nguy cơ trễ hạn đồ án rất cao, việc xử lý bản đồ và reorder hoạt động trên web phức tạp hơn nhiều.

#### Quyết định 2: Cơ chế Nghiệp vụ khi Sao chép / Tái sử dụng Lịch trình (Clone Itinerary)
- **Bối cảnh:** Lịch trình sao chép từ người khác nên là một bản sao độc lập hoàn toàn hay giữ liên kết phụ thuộc với lịch trình nguồn?
- **Phương án A (Deep Copy độc lập - Đề xuất của nhóm):** Khi clone, hệ thống nhân bản toàn bộ thông tin chuyến đi, các ngày và các hoạt động thành các bản ghi mới trong database thuộc sở hữu của người sao chép, chỉ lưu `original_itinerary_id` để tri ân tác giả gốc và tăng `reuse_count`. Khi tác giả gốc sửa hoặc xóa lịch trình nguồn, bản sao của người khác không bị ảnh hưởng.
  - *Ưu điểm:* An toàn tuyệt đối về dữ liệu; người dùng tự do cá nhân hóa ngày giờ, xóa bớt hoặc thêm địa điểm mà không làm biến dạng dữ liệu người khác; logic xử lý sạch và đơn giản.
  - *Nhược điểm:* Tốn thêm dung lượng lưu trữ trong MySQL (không đáng kể với quy mô đồ án).
- **Phương án B (Liên kết tham chiếu mềm):** Chỉ tạo bản ghi ghi đè (overrides) các hoạt động bị thay đổi, các hoạt động không sửa vẫn tham chiếu về lịch trình gốc.
  - *Ưu điểm:* Tiết kiệm dung lượng.
  - *Nhược điểm:* Kiến trúc dữ liệu cực kỳ phức tạp; nguy cơ lỗi toàn vẹn khi lịch trình gốc bị xóa hoặc chuyển sang trạng thái ẩn (`HIDDEN`/`DELETED`).

#### Quyết định 3: Quy tắc ràng buộc điều kiện Đánh giá (Rating) và Bình luận (Comment)
- **Bối cảnh:** Trong tài liệu Đặc tả chức năng (§9 & §16), có lưu ý câu hỏi: *Có cần bắt buộc người dùng phải sao chép hoặc trải nghiệm lịch trình rồi mới được đánh giá/bình luận không?*
- **Phương án A (Đánh giá mở có điều kiện nhẹ - Đề xuất của nhóm):** Bất kỳ người dùng nào đã đăng nhập (`USER`) đều có quyền bình luận và đánh giá số sao cho một lịch trình công khai; tuy nhiên cấm tác giả tự đánh giá lịch trình của chính mình.
  - *Ưu điểm:* Kích thích cộng đồng thảo luận sôi nổi; dữ liệu đánh giá phong phú; dễ dàng kiểm thử và demo đồ án.
  - *Nhược điểm:* Có thể có đánh giá cảm tính từ người chưa thực sự đi chuyến đó.
- **Phương án B (Bắt buộc phải Sao chép/Sử dụng mới được đánh giá):** Chỉ những tài khoản đã nhấn nút "Sao chép chuyến đi" mới được phép mở khóa tính năng gửi Rating.
  - *Ưu điểm:* Chất lượng đánh giá rất chân thực và có tính xác thực cao.
  - *Nhược điểm:* Giảm tính tương tác ban đầu; luồng kiểm thử demo phức tạp hơn.

#### Quyết định 4: Chiến lược Xử lý khi Hết hạn ngạch Bản đồ / Ngoại tuyến
- **Bối cảnh:** Kiến trúc bản đồ hiện tại đang áp dụng nguyên lý Free-First Decoupled (CARTO + LocationIQ + ORS) kèm Fallback đường chim bay (Haversine).
- **Phương án A (Giữ nguyên kiến trúc Free-First hiện tại - Đề xuất của nhóm):** Tiếp tục duy trì giải pháp đã kiểm chứng: sử dụng dịch vụ miễn phí có hạn mức, khi ORS hết hạn ngạch thì tự động chuyển sang hiển thị đường chim bay kèm thông báo giải thích rõ ràng cho người dùng; chuyển hướng chỉ đường sang Google Maps app qua URL.
  - *Ưu điểm:* Không phát sinh bất kỳ chi phí nào; độc lập tuyệt đối; đã có 501 automated tests bảo chứng hoạt động ổn định.
  - *Nhược điểm:* Tuyến đường chim bay không bám theo mặt đường thực tế khi thiếu key ORS.
- **Phương án B (Chuyển sang Google Maps Platform chính thức):** Nhúng Google Maps SDK chính thức vào Flutter và dùng Google Directions API.
  - *Ưu điểm:* Bản đồ và lộ trình cực kỳ chuẩn xác tại Việt Nam.
  - *Nhược điểm:* Bắt buộc phải gắn thẻ tín dụng quốc tế (Credit Card); rủi ro phát sinh chi phí tự động nếu bị lộ key hoặc vượt quá mức 200$ credit hàng tháng của Google; vi phạm nguyên tắc "Strictly Free Services & Cost-Controlled" đã thống nhất trong tài liệu kiến trúc.

---

## 7. Kết quả kiểm thử và xác minh thực tế (Testing and Verification Results)

Các kiểm thử sau đây đã được thực thi trực tiếp trên hệ thống trong quá trình kiểm toán:

### 7.1. Kiểm thử Backend (Spring Boot)
- **Lệnh thực thi:**
  ```powershell
  cd Travel_Planner/backend
  .\mvnw.cmd test
  ```
- **Kết quả thực tế:**
  - **Trạng thái:** `BUILD SUCCESS`
  - **Tổng số test:** **157** bài kiểm thử
  - **Thành công (Passed):** **157**
  - **Thất bại (Failures):** **0**
  - **Lỗi (Errors):** **0**
  - **Bỏ qua (Skipped):** **0**
  - **Thời gian chạy:** 1 phút 32 giây (01:32 min)
- **Các phân hệ trọng tâm đã kiểm chứng:**
  - `ActivityLocationTest`: Xác thực tính hợp lệ của tọa độ hoạt động, chuyển đổi giữa Catalog POI và Custom Location.
  - `AdminDestinationControllerTest`: Xác thực toàn bộ CRUD quyền ADMIN và từ chối USER thường (403 Forbidden).
  - `AuthControllerTest`: Đăng ký, đăng nhập, JWT, xác thực trùng lặp username/email.
  - `CloudinaryImageUploadServiceTest`: Xác thực magic bytes, chặn file quá cỡ, sinh chữ ký số SHA-1.
  - `DataSeederTest`: Kiểm tra tính idempotent của seed data mẫu.
  - `DestinationControllerTest`: Đọc danh mục điểm đến công cộng.
  - `ItineraryControllerTest` & `ItineraryCrudTest`: Toàn bộ luồng CRUD, xác thực chủ sở hữu, đổi thứ tự Two-Pass.
  - `LocationServiceTest`: Kiểm tra tìm kiếm địa điểm, reverse geocoding, và bộ giới hạn tần suất Token Bucket.
  - `RouteServiceTest` & `OpenRouteServiceRoutingProviderTest`: Kiểm tra tính toán tuyến đường ORS, in-memory cache, và cơ chế fallback Haversine khi thiếu key.

---

### 7.2. Kiểm thử Frontend Mobile (Flutter Mobile)
- **Lệnh thực thi:**
  ```powershell
  cd Travel_Planner/frontend/mobile
  flutter test
  ```
- **Kết quả thực tế:**
  - **Trạng thái:** `All tests passed!`
  - **Tổng số test:** **305** bài kiểm thử
  - **Thành công (Passed):** **305**
  - **Thất bại (Failures):** **0**
  - **Thời gian chạy:** 51 giây
- **Phân tích mã tĩnh (Static Analysis):**
  - **Lệnh:** `flutter analyze`
  - **Kết quả:** Phát hiện 1 vấn đề nhỏ thuộc mức `info` tại [`test/filter_bottom_sheet_test.dart:25:43`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/filter_bottom_sheet_test.dart#L25) (`unnecessary_underscores`). Mã nguồn chính trong `lib/` đạt 0 lỗi, 0 cảnh báo.
- **Các phân hệ Mobile đã kiểm chứng:**
  - `itinerary_map_test.dart` & `itinerary_route_test.dart`: Kiểm tra hiển thị bản đồ toàn chuyến, đổi chế độ "Tất cả" và "Từng ngày", vẽ polyline đa màu, thuật toán phân tách tọa độ trùng điểm (Radial Jittering ~18m), fallback đường chim bay.
  - `location_picker_test.dart` & `location_repository_test.dart`: Kiểm tra sheet chọn vị trí, chuyển đổi 3 trạng thái (Catalog POI, Custom Pin, No Location).
  - `explore_test.dart` & `explore_sections_test.dart`: Tìm kiếm debounced, bộ lọc nâng cao, thẻ chủ đề.
  - `itinerary_activity_management_test.dart`: Thêm/sửa/xóa hoạt động, kéo thả sắp xếp lại timeline.
  - `auth_401_test.dart`: Bắt lỗi 401 tự động điều hướng đăng nhập.
  - `animation_enhancements_test.dart`: Crossfade hiệu ứng nút bấm, loading indicator.

---

### 7.3. Kiểm thử Frontend Web (Flutter Web)
- **Lệnh thực thi:**
  ```powershell
  cd Travel_Planner/frontend/web
  flutter test
  ```
- **Kết quả thực tế:**
  - **Trạng thái:** `All tests passed!`
  - **Tổng số test:** **39** bài kiểm thử
  - **Thành công (Passed):** **39**
  - **Thất bại (Failures):** **0**
  - **Thời gian chạy:** 6 giây
- **Phân tích mã tĩnh (Static Analysis):**
  - **Lệnh:** `flutter analyze`
  - **Kết quả:** `No issues found! (ran in 10.2s)` — Hoàn toàn sạch, 0 lỗi, 0 cảnh báo.
- **Các phân hệ Web đã kiểm chứng:**
  - `admin_destination_test.dart`: Xác thực DTO chuyển đổi dữ liệu điểm đến, form nhập liệu, dialog xác nhận ẩn, phân quyền truy cập (USER bị chặn "Access Denied", ADMIN vào danh sách quản trị).
  - `web_map_api_key_test.dart`: Kiểm tra hiển thị bản đồ quản trị và banner cảnh báo cấu hình key.

---

### 7.4. Các kịch bản chưa thể xác minh tự động (Unverified Scenarios)
1. **Trải nghiệm thực tế trên thiết bị di động vật lý (Physical Device Performance):** Kiểm thử tự động chạy trên môi trường giả lập headless của Flutter. Chưa đo đạc thực tế chỉ số FPS và độ trễ khi vẽ bản đồ đa điểm trên các máy Android/iOS cấu hình thấp.
2. **Khả năng chịu tải đồng thời (Load / Concurrency Testing):** Chưa thực hiện bài test tải (JMeter/K6) để kiểm tra khả năng xử lý của Spring Boot và MySQL khi có hàng trăm yêu cầu tìm kiếm vị trí và tính toán lộ trình diễn ra cùng lúc.
3. **Môi trường kết nối mạng chập chờn / Mất kết nối (Network Flakiness):** Chưa kiểm chứng hành vi của ứng dụng khi thiết bị mất kết nối mạng đột ngột trong lúc đang gửi form tạo lịch trình hoặc đang upload ảnh nhị phân dung lượng lớn.

---

## 8. Khó khăn gặp phải trong quá trình phát triển (Difficulties Encountered)

Trong quá trình xây dựng hệ thống, nhóm đã giải quyết bốn thách thức kỹ thuật lớn nhất sau:

1. **Thách thức kiến trúc Bản đồ không chi phí (Decoupled Free-First Map Architecture):**
   - *Khó khăn:* Để tránh việc phụ thuộc vào Google Maps SDK (vốn yêu cầu thẻ tín dụng và có nguy cơ phát sinh chi phí ngoài ý muốn), nhóm phải tự thiết kế giải pháp kết hợp giữa `flutter_map` (vẽ tile mã nguồn mở), CARTO Basemaps (cung cấp raster tile), LocationIQ (tìm kiếm địa chỉ) và OpenRouteService (vẽ tuyến đường thực).
   - *Xử lý:* Tách biệt hoàn toàn các tầng: Client tải tile trực tiếp không qua backend để tránh nghẽn băng thông server; Backend đóng vai trò Proxy bảo mật cho Geocoding và Routing; tích hợp bộ đệm in-memory và thuật toán Token Bucket chống cạn kiệt quota miễn phí.

2. **Thách thức hiển thị Tuyến đường Đa ngày và Trùng tọa độ (Multi-Day Route Visualization & Co-located Jitter):**
   - *Khó khăn:* Khi người dùng chọn chế độ xem "Tất cả các ngày" của một chuyến đi dài ngày, việc vẽ đường gặp hai lỗi nghiêm trọng: (1) Thư viện vô tình nối điểm kết thúc của ngày hôm trước với điểm bắt đầu của ngày hôm sau bằng một đường thẳng cắt ngang bản đồ; (2) Các địa điểm tham quan cùng một khu vực (ví dụ cùng ở Phố Cổ Hội An) có tọa độ giống nhau khiến marker của các ngày sau đè bẹp hoàn toàn marker của ngày trước, làm mất số thứ tự hoạt động.
   - *Xử lý:* Nhóm đã refactor cơ chế dựng lộ trình: phân tách các ngày thành các đối tượng `Polyline` độc lập có dải màu sắc riêng biệt; phát triển giải thuật **Radial Jittering** tự động phân tán tọa độ một bán kính nhỏ (~18m) theo góc lệch tâm để mọi điểm dừng đều hiển thị rõ ràng, tách bạch và bấm chọn được.

3. **Thách thức xung đột Ràng buộc Duy nhất khi Đổi thứ tự Hoạt động (Two-Pass Reordering):**
   - *Khó khăn:* Trong cơ sở dữ liệu MySQL, bảng `activities` có ràng buộc duy nhất `uk_activity_order (day_id, order_index)`. Khi người dùng kéo thả đổi chỗ hoạt động số 1 xuống số 2 và số 2 lên số 1, việc cập nhật trực tiếp khiến MySQL báo lỗi vi phạm khóa duy nhất (Unique Constraint Violation) ngay lập tức do vị trí số 2 đã tồn tại trong lúc cập nhật vị trí số 1.
   - *Xử lý:* Nhóm đã nghiên cứu và cài đặt thành công giải thuật **Two-Pass Reordering** trong `ItineraryServiceImpl`: lượt thứ nhất gán tạm các vị trí thành các số âm ($-1, -2,\dots$) để giải phóng chỉ mục dương, lượt thứ hai gán chỉ mục mới chính thức và commit toàn bộ trong cùng một Database Transaction.

4. **Thách thức Tải ảnh bảo mật không để lộ Secret trên Client:**
   - *Khó khăn:* Nếu để Flutter tải ảnh trực tiếp lên Cloudinary, bắt buộc phải lưu `api_secret` trong mã nguồn di động, dẫn đến nguy cơ bị dịch ngược ứng dụng (reverse engineering) và đánh cắp tài khoản.
   - *Xử lý:* Xây dựng endpoint trung gian `POST /api/media/images` tại Spring Boot. Backend tiếp nhận luồng nhị phân, kiểm tra magic bytes chuẩn định dạng ảnh an toàn, tạo chữ ký số SHA-1 bằng secret được giữ kín ở server, rồi mới đẩy lên Cloudinary và trả về đường dẫn `secure_url`.

---

## 9. Vấn đề và câu hỏi cần trao đổi với GVHD (Issues & Questions for Supervisor)

Dưới đây là 5 câu hỏi trọng tâm, có căn cứ kỹ thuật rõ ràng để xin ý kiến định hướng từ Giảng viên Hướng dẫn:

### Câu hỏi 1: Về Phạm vi của Nền tảng Flutter Web
- **Bối cảnh:** Hiện tại phân hệ Flutter Web mới hoàn thành phần Quản trị Điểm đến (`AdminDestinationsScreen`). Nhóm nhận thấy nếu làm cả giao diện tạo/sửa lịch trình của người dùng trên Web thì khối lượng công việc sẽ bị dàn trải và trùng lặp với Mobile.
- **Đề xuất của nhóm:** Xin phép Thầy/Cô cho phép nhóm **tập trung Flutter Web chuyên biệt làm Trang Quản trị (Admin Portal)** (gồm: Thống kê số liệu, Quản lý người dùng, Kiểm duyệt lịch trình và địa điểm), dành toàn bộ trải nghiệm khám phá và tạo chuyến đi của người dùng du lịch trên **Flutter Mobile**.
- **Câu hỏi cần hỏi GVHD:** *Dạ thưa Thầy/Cô, nhóm có thể chốt phạm vi phân hệ Flutter Web là cổng thông tin chuyên trách cho Quản trị viên (Admin & Content Moderation Portal), còn toàn bộ trải nghiệm End-User sẽ tập trung hoàn thiện tối ưu trên ứng dụng Flutter Mobile được không ạ?*

### Câu hỏi 2: Về Nghiệp vụ Tái sử dụng (Clone) và Điều kiện Đánh giá (Rating)
- **Bối cảnh:** Nhóm chuẩn bị triển khai tính năng Sao chép/Tái sử dụng lịch trình (`Clone Itinerary`) và Đánh giá số sao (`Rating`).
- **Đề xuất của nhóm:** Khi người dùng nhấn "Sao chép", hệ thống sẽ nhân bản lịch trình thành một bản sao độc lập (Deep Copy) để người dùng tự do cá nhân hóa. Về đánh giá, nhóm đề xuất cho phép mọi người dùng đã đăng nhập đều có thể đánh giá 1–5 sao cho các lịch trình công khai (trừ lịch trình của chính mình) để khuyến khích tương tác.
- **Câu hỏi cần hỏi GVHD:** *Dạ thưa Thầy/Cô, về tính năng Sao chép chuyến đi, việc tạo bản sao độc lập (Deep copy) có phù hợp không ạ? Và đối với Đánh giá số sao (Rating), hệ thống nên mở quyền cho tất cả người dùng đăng nhập hay bắt buộc người dùng phải nhấn sao chép/trải nghiệm chuyến đi rồi mới được đánh giá ạ?*

### Câu hỏi 3: Về Giải pháp Bản đồ và Lộ trình đường đi
- **Bối cảnh:** Nhóm đã xây dựng thành công giải pháp Bản đồ Decoupled Free-First (dùng `flutter_map` kết hợp tile CARTO Basemaps miễn phí, LocationIQ và OpenRouteService) kèm cơ chế tự suy biến dự phòng đường chim bay (Haversine) khi hết quota.
- **Đề xuất của nhóm:** Tiếp tục sử dụng kiến trúc hoàn toàn miễn phí này và tích hợp nút mở Google Maps native app để người dùng xem dẫn đường chi tiết khi cần di chuyển thực tế ngoài đường.
- **Câu hỏi cần hỏi GVHD:** *Dạ thưa Thầy/Cô, giải pháp tích hợp bản đồ mã nguồn mở kết hợp các API miễn phí và tự động fallback về đường chim bay khi hết hạn ngạch hiện tại đã đáp ứng đầy đủ tiêu chí đánh giá kỹ thuật của Hội đồng chấm đồ án chưa, hay Hội đồng có yêu cầu bắt buộc phải nhúng trực tiếp Google Maps SDK chính thức không ạ?*

### Câu hỏi 4: Về Mức độ Ưu tiên cho Tính năng Cộng đồng (Following, Feed) và Thông báo (Push Notification)
- **Bối cảnh:** Thời gian hoàn thiện đồ án có hạn. Các tính năng như Mạng xã hội theo dõi bạn bè (Following/Feed) và Thông báo đẩy thời gian thực (Push Notifications qua Firebase) hiện mới chỉ có database hoặc màn hình giữ chỗ.
- **Đề xuất của nhóm:** Nhóm đề xuất ưu tiên hoàn thiện trước các tính năng then chốt: (1) Lưu/Yêu thích lịch trình; (2) Sao chép/Tái sử dụng lịch trình; (3) Hoàn thiện các trang Quản trị trên Web. Các tính năng Mạng xã hội và Thông báo đẩy xin phép xem là tính năng mở rộng (Optional / Future Work).
- **Câu hỏi cần hỏi GVHD:** *Dạ thưa Thầy/Cô, trong giai đoạn nước rút tiếp theo, Thầy/Cô có đồng ý cho nhóm ưu tiên dồn lực hoàn thiện Tính năng Tái sử dụng lịch trình và Phân hệ Web Admin trước, còn tính năng Theo dõi bạn bè và Push Notification sẽ để ở giai đoạn phát triển nâng cao nếu còn thời gian không ạ?*

### Câu hỏi 5: Về Kế hoạch Triển khai (Deployment) và Môi trường Demo Đánh giá
- **Bối cảnh:** Hiện tại đồ án đang chạy rất tốt trên môi trường phát triển nội bộ (Localhost kết nối qua mạng LAN với dữ liệu Seed thực tế đầy đủ).
- **Đề xuất của nhóm:** Nhóm dự kiến đóng gói hệ thống vào Docker Compose để dễ dàng demo trên máy tính hoặc triển khai lên một máy chủ ảo Cloud miễn phí/giá rẻ.
- **Câu hỏi cần hỏi GVHD:** *Dạ thưa Thầy/Cô, đối với buổi báo cáo nghiệm thu và bảo vệ tốt nghiệp, Hội đồng yêu cầu bắt buộc phải triển khai ứng dụng trên máy chủ Cloud công cộng (kèm tên miền riêng) hay có thể demo trực tiếp trên máy trạm cục bộ kết nối thiết bị thật qua mạng nội bộ kèm bộ dữ liệu seed mẫu ạ?*

---

## 10. Giải pháp đề xuất và hỗ trợ cần thiết (Proposed Solutions and Required Support)

Nhóm phân loại rõ ràng các nhóm vấn đề theo thẩm quyền xử lý:

### 10.1. Vấn đề Nhóm phát triển tự chủ giải quyết độc lập (Self-resolvable)
- **Thu hồi và ẩn credential bí mật:** Xóa bỏ ngay các chuỗi secret trong `README.md`, thay bằng hướng dẫn đặt biến môi trường; tạo tài khoản API mới để thay thế khóa đã bị lộ.
- **Sửa cảnh báo phân tích tĩnh:** Sửa lỗi `unnecessary_underscores` trong `frontend/mobile/test/filter_bottom_sheet_test.dart` để đưa `flutter analyze` về 0 cảnh báo.
- **Xây dựng API Lưu & Yêu thích (Save & Favorite):** Viết `SavedItineraryController`, `FavoriteController` và hoàn thiện giao diện `SavedItinerariesScreen` trên Mobile.
- **Bổ sung chức năng Sửa/Xóa bình luận:** Bổ sung `PUT /api/itineraries/{itineraryId}/comments/{commentId}` và `DELETE` cho chính tác giả bình luận.

### 10.2. Vấn đề cần Nghiên cứu Kỹ thuật chuyên sâu (Technical Research)
- **Nghiên cứu Docker Compose cho toàn bộ hệ thống:** Xây dựng file `Dockerfile` tối ưu hóa đa tầng (multi-stage build) cho Spring Boot (dùng JRE 22 rút gọn) và Nginx phục vụ bản build Flutter Web.
- **Nghiên cứu chuẩn hóa lược đồ cơ sở dữ liệu:** Tạo kịch bản Flyway Migration để quản lý version database thay cho `hibernate.ddl-auto=update`.
- **Tối ưu hóa tìm kiếm tiếng Việt:** Nghiên cứu tích hợp hàm chuẩn hóa unaccented trên MySQL hoặc Spring Data JPA Criteria để hỗ trợ tìm kiếm không dấu chính xác hơn.

### 10.3. Vấn đề cần Quyết định từ GVHD (Supervisor Decision Needed)
- Chốt phạm vi phân hệ Flutter Web (giới hạn ở Admin Portal hay bắt buộc cả User Portal).
- Chốt quy tắc nghiệp vụ khi Clone Lịch trình (sao chép độc lập hay liên kết nguồn).
- Chốt điều kiện cho phép người dùng đánh giá số sao.
- Chốt yêu cầu triển khai thực tế phục vụ buổi bảo vệ (Cloud public vs Local demo).

---

## 11. Khối lượng công việc còn lại và lộ trình ưu tiên (Remaining Work & Prioritized Roadmap)

Lộ trình được cấu trúc thành 3 giai đoạn chặt chẽ:

```
[Giai đoạn 1: Khắc phục & Hoàn thiện Nền tảng] ──> [Giai đoạn 2: Tính năng Trọng tâm & Web Admin] ──> [Giai đoạn 3: Đóng gói & Nghiệm thu]
```

### Giai đoạn 1 — Immediate (Thực hiện ngay lập tức)
*Mục tiêu: Dọn sạch rủi ro an ninh, xử lý cảnh báo linter và hoàn thiện các chức năng tương tác cơ bản còn dang dở.*
1. **Thu hồi API Secret & Cập nhật README:**
   - *Ưu tiên:* P0 (Khẩn cấp).
   - *Nhiệm vụ:* Đổi secret Cloudinary/ORS, cập nhật `README.md` chỉ dùng placeholder.
   - *Files:* [`Travel_Planner/README.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/README.md).
   - *Nỗ lực:* Nhỏ (Small).
2. **Sửa cảnh báo linter Mobile Test:**
   - *Ưu tiên:* P1.
   - *Nhiệm vụ:* Đổi `__` thành `_` tại dòng 25 file test.
   - *Files:* [`frontend/mobile/test/filter_bottom_sheet_test.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/test/filter_bottom_sheet_test.dart).
   - *Nỗ lực:* Nhỏ (Small).
3. **Triển khai tính năng Lưu & Yêu thích Lịch trình (Saved & Favorite Itineraries):**
   - *Ưu tiên:* P1.
   - *Nhiệm vụ:* Viết Controller, Service, kết nối Repository có sẵn ở Backend; kết nối nút Bookmark/Heart trên Mobile và hoàn thiện màn hình `SavedItinerariesScreen`.
   - *Files liên quan:* Backend: `UserItineraryController`, `SavedItineraryRepository`, `FavoriteRepository`, `ItineraryService`; Mobile: `saved_itineraries_screen.dart`, `itinerary_card.dart`.
   - *Nỗ lực:* Trung bình (Medium).
   - *Tiêu chí nghiệm thu:* Người dùng nhấn bookmark ở bất kỳ đâu thì lịch trình xuất hiện trong tab "Lịch trình đã lưu"; nhấn lần nữa để bỏ lưu; test tự động kiểm tra đủ luồng.

---

### Giai đoạn 2 — Next (Tính năng Trọng tâm & Web Admin)
*Mục tiêu: Hoàn thiện tính năng cốt lõi của đề tài (Clone Lịch trình) và xây dựng phân hệ Quản trị Web.*
1. **Tính năng Tái sử dụng & Cá nhân hóa Lịch trình (Clone Itinerary):**
   - *Ưu tiên:* P1.
   - *Nhiệm vụ:* Xây dựng `POST /api/itineraries/{id}/clone` ở backend; thực hiện deep copy toàn bộ các ngày và hoạt động; tăng `reuseCount`; bổ sung nút "Sao chép chuyến đi" trên `ItineraryDetailScreen` mobile.
   - *Nỗ lực:* Trung bình (Medium).
2. **Phân hệ Web Admin: Quản lý Người dùng (User Management):**
   - *Ưu tiên:* P1.
   - *Nhiệm vụ:* Backend viết `AdminUserController` (`GET /api/admin/users`, `PUT /api/admin/users/{id}/status` để khóa/mở khóa tài khoản); Web xây dựng màn hình danh sách tài khoản, tìm kiếm, lọc theo vai trò và trạng thái.
   - *Nỗ lực:* Trung bình (Medium).
3. **Phân hệ Web Admin: Kiểm duyệt Lịch trình vi phạm (Content Moderation):**
   - *Ưu tiên:* P1.
   - *Nhiệm vụ:* Backend viết `AdminItineraryController` (`GET /api/admin/itineraries`, `PUT /api/admin/itineraries/{id}/status` để ẩn/gỡ lịch trình vi phạm); Web xây dựng màn hình kiểm duyệt nội dung.
   - *Nỗ lực:* Trung bình (Medium).
4. **Phân hệ Web Admin: Bảng điều khiển Thống kê (Admin Dashboard):**
   - *Ưu tiên:* P2.
   - *Nhiệm vụ:* Backend viết endpoint thống kê tổng hợp số liệu; Web hiển thị thẻ KPI số liệu người dùng, chuyến đi, địa điểm và biểu đồ trực quan.
   - *Nỗ lực:* Trung bình (Medium).
5. **Hoàn thiện tính năng Đánh giá số sao (Rating) & Quản lý Bình luận:**
   - *Ưu tiên:* P2.
   - *Nhiệm vụ:* Viết `RatingController` cho phép gửi số sao 1–5; tính lại điểm trung bình lịch trình; bổ sung Sửa/Xóa bình luận cho tác giả và Admin.
   - *Nỗ lực:* Trung bình (Medium).

---

### Giai đoạn 3 — Later (Nâng cao, Đóng gói & Nghiệm thu)
*Mục tiêu: Tối ưu hóa trải nghiệm, chuẩn bị môi trường triển khai và hoàn thiện tài liệu khóa luận.*
1. **Xem hồ sơ công khai của người dùng khác:** Thêm màn hình xem trang cá nhân tác giả từ chi tiết lịch trình.
2. **Tính năng Theo dõi người dùng (Following/Community):** Bổ sung kết nối API cho màn hình `CommunityScreen`.
3. **Hệ thống Thông báo trong ứng dụng (In-app Notifications):** Lưu thông báo khi có người bình luận, đánh giá hoặc sao chép lịch trình của mình.
4. **Container hóa Docker & Thiết lập Database Migration (Flyway):** Viết `Dockerfile` và `docker-compose.yml` chạy đồng bộ Backend, Web và MySQL.
5. **Đo lường hiệu năng trên thiết bị thật và hoàn thiện Báo cáo Khóa luận Tốt nghiệp.**

---

## 12. Đề xuất nhiệm vụ triển khai tiếp theo (Recommended Next Task)

Nhóm đề xuất lựa chọn **DUY NHẤT MỘT** nhiệm vụ trọng tâm sau đây để triển khai ngay khi được phê duyệt:

### Tên nhiệm vụ:
**Triển khai tính năng Lưu & Yêu thích Lịch trình (Saved & Favorite Itineraries) toàn diện từ Backend đến Frontend Mobile.**

### 1. Lý do ưu tiên số 1:
- **Nền tảng đã sẵn sàng:** Database MySQL đã có sẵn hai bảng `saved_itineraries` và `favorites`; Backend đã có sẵn hai JPA repository là [`SavedItineraryRepository.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/SavedItineraryRepository.java) và [`FavoriteRepository.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/FavoriteRepository.java); Seeder đã nạp sẵn dữ liệu mẫu thực tế.
- **Giao diện Mobile đã có sẵn vị trí:** Màn hình [`saved_itineraries_screen.dart`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/frontend/mobile/lib/features/saved_itineraries/presentation/screens/saved_itineraries_screen.dart) đang là màn hình giữ chỗ (empty state) trên thanh điều hướng chính (Bottom Navigation Bar); các thẻ lịch trình đã có sẵn icon Bookmark.
- **Rủi ro kỹ thuật thấp, giá trị thực tế cao:** Đây là mắt xích trực tiếp giúp hoàn thiện trải nghiệm của người dùng trước khi tiến hành tính năng Tái sử dụng (Clone) và Đánh giá (Rating).

### 2. Nội dung cụ thể cần thực hiện:
- **Backend:**
  - Viết Service methods trong `ItineraryService` / `ItineraryServiceImpl`: `saveItinerary(itineraryId, username)`, `unsaveItinerary(itineraryId, username)`, `getSavedItineraries(username, pageable)`, `isItinerarySaved(itineraryId, username)`.
  - Cập nhật bộ đếm `favoriteCount` / `savedCount` an toàn.
  - Viết các REST endpoints trong controller:
    - `POST /api/itineraries/{id}/save`: Lưu lịch trình.
    - `DELETE /api/itineraries/{id}/save`: Hủy lưu.
    - `GET /api/user/saved-itineraries`: Lấy danh sách lịch trình đã lưu của người dùng hiện tại (hỗ trợ phân trang).
  - Viết Unit/Integration Tests kiểm thử đầy đủ các kịch bản (lưu thành công, hủy lưu, ngăn chặn lưu trùng lặp, phân trang đúng).
- **Frontend Mobile:**
  - Xây dựng `SavedItinerariesRepository` và `SavedItinerariesNotifier` (hoặc tích hợp vào feature có sẵn).
  - Hoàn thiện `SavedItinerariesScreen`: hiển thị danh sách các thẻ lịch trình đã lưu kèm trạng thái loading, empty state khi chưa lưu chuyến đi nào, và pull-to-refresh.
  - Kết nối sự kiện click icon Bookmark trên `ItineraryDetailScreen` và `ItineraryCard` để gọi API lưu/hủy lưu theo thời gian thực kèm hiệu ứng thông báo Toast/SnackBar nhẹ nhàng.
  - Viết Widget Test cho màn hình và nút bookmark.

### 3. Những nội dung TUYỆT ĐỐI KHÔNG đưa vào phạm vi task này (Out of scope):
- Không làm tính năng Clone/Tái sử dụng lịch trình trong task này.
- Không làm tính năng Đánh giá số sao (Rating) trong task này.
- Không chỉnh sửa giao diện Flutter Web trong task này.

### 4. Các module và file dự kiến sẽ thay đổi:
- **Backend:**
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/UserItineraryController.java` (hoặc tạo mới `SavedItineraryController.java`)
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/ItineraryService.java`
  - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java`
  - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ItineraryControllerTest.java`
- **Mobile:**
  - `Travel_Planner/frontend/mobile/lib/core/constants/api_constants.dart`
  - `Travel_Planner/frontend/mobile/lib/features/saved_itineraries/data/saved_itineraries_repository.dart` (tạo mới)
  - `Travel_Planner/frontend/mobile/lib/features/saved_itineraries/presentation/saved_itineraries_notifier.dart` (tạo mới)
  - `Travel_Planner/frontend/mobile/lib/features/saved_itineraries/presentation/screens/saved_itineraries_screen.dart`
  - `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart`
  - `Travel_Planner/frontend/mobile/test/saved_itineraries_test.dart` (tạo mới)

### 5. Tiêu chí nghiệm thu (Acceptance Criteria):
1. Người dùng bấm icon Bookmark trên màn hình chi tiết lịch trình, hệ thống gọi API `POST /api/itineraries/{id}/save` thành công, icon chuyển sang trạng thái đã lưu, hiển thị SnackBar thông báo.
2. Mở tab "Lịch trình đã lưu" trên Bottom Navigation Bar, danh sách các chuyến đi đã bookmark hiển thị đầy đủ thông tin, bấm vào mở đúng chi tiết chuyến đi.
3. Bấm lại icon Bookmark một lần nữa, hệ thống gọi `DELETE /api/itineraries/{id}/save`, lịch trình biến mất khỏi danh sách đã lưu.
4. Kiểm thử Backend và Mobile mới viết pass 100%, bảo vệ toàn bộ 501 test hiện có không bị hồi quy (regression).

---

## 13. Trạng thái Git và tính nhất quán của tài liệu (Git Status & Documentation Consistency)

### 13.1. Hiện trạng Git
- **Nhánh hiện tại:** `map` (theo dõi nhánh từ xa `origin/feature/map`).
- **Trạng thái Working Tree:** Sạch hoàn toàn (`working tree clean`, không có commit dở dang hay file thừa chưa theo dõi).
- **Các commit gần nhất trên nhánh `map`:**
  - `fd26c19 fix(map): improve multi-day itinerary route visualization` (Session 82: phân tách tọa độ trùng điểm và hiển thị lộ trình đa ngày).
  - `45bc3fe feat: add map integration and shared map UI components` (Session 81: các thành phần bản đồ chia sẻ và banner cảnh báo key).
  - `4c8d7a5 feat: implement admin destinations management and web map integration` (Session 78: quản lý điểm đến trên web).
  - `417850e feat(map): add per-day route calculation and navigation` (Session 77: tính toán lộ trình ORS).
- **Các nhánh chức năng khác trong repository:**
  - `auth` (`origin/feature/auth`)
  - `develop` (`origin/develop` — đã merge PR #8 feature/explore)
  - `explore` (`origin/feature/explore`)
  - `itinerary` (`origin/feature/itinerary`)
  - `main` (`origin/main`)

### 13.2. Tính nhất quán của Tài liệu
- **Tài liệu kiểm toán mới:** Báo cáo kiểm toán này được lưu độc lập tại file [`docs/ai/12-project-progress-audit.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/12-project-progress-audit.md), không ghi đè bất kỳ tài liệu lịch sử nào.
- **Tài liệu nhật ký phát triển:** Tuân thủ đúng chỉ thị kiểm toán, file [`docs/ai/09-development-log.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/09-development-log.md) **không bị chỉnh sửa** chỉ để ghi chép lại nội dung kiểm toán. Nhật ký này hiện phản ánh trung thực lịch sử phát triển đến hết Session 82.
- **Tài liệu kế hoạch bản đồ:** File [`docs/ai/11-map-integration-audit-and-plan.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/11-map-integration-audit-and-plan.md) đã được cập nhật đầy đủ các kết quả nghiệm thu của toàn bộ 6 giai đoạn tích hợp bản đồ.

---

## 14. Tóm tắt ngắn gọn phục vụ buổi họp với GVHD (Short Meeting Briefing)

*(Phần này được thiết kế cô đọng, súc tích để sử dụng trực tiếp trong vòng 5–10 phút báo cáo tiến độ với Giảng viên Hướng dẫn)*

### Nhóm 1: Thành quả báo cáo (Achievements to Report)
1. **Động cơ cốt lõi hoạt động trơn tru:** Đã hoàn thành 100% các chức năng cốt lõi của người dùng: Đăng ký/Đăng nhập bảo mật JWT, Quản lý hồ sơ, Khám phá & Lọc lịch trình đa tiêu chí, Tạo/Sửa/Xóa lịch trình, Quản lý timeline từng ngày và từng hoạt động kèm giải thuật đổi thứ tự hoạt động Two-Pass chống lỗi unique key.
2. **Kiến trúc Bản đồ Free-First hoàn thiện xuất sắc:** Tích hợp thành công bản đồ mã nguồn mở `flutter_map` kết hợp tile CARTO Basemaps miễn phí, tính toán lộ trình từng ngày và toàn bộ chuyến đi qua OpenRouteService, giải thuật Radial Jittering chống đè marker trùng tọa độ, cơ chế tự suy biến dự phòng đường chim bay khi thiếu key, và mở ứng dụng Google Maps ngoài đời thực qua deep link.
3. **Phân hệ Quản trị Điểm đến trên Web:** Quản trị viên đã có thể tra cứu, tạo mới, chỉnh sửa và ẩn điểm đến với giao diện tương tác bản đồ trực quan trên Flutter Web.
4. **Chất lượng kiểm thử tự động vượt trội:** Toàn hệ thống có **501 bài kiểm thử tự động đạt tỷ lệ pass 100%** (Backend: 157/157 tests; Mobile: 305/305 tests; Web: 39/39 tests). Phân tích mã tĩnh Web đạt 0 lỗi 0 cảnh báo.

### Nhóm 2: Vấn đề cần trao đổi (Problems to Discuss)
1. **Sự mất cân đối giữa Mobile và Web:** Mobile đã hoàn thiện hầu hết luồng người dùng chính, trong khi Flutter Web mới chỉ có phần Điểm đến; các trang Quản trị người dùng, Kiểm duyệt nội dung vi phạm và Dashboard thống kê trên Web chưa được xây dựng.
2. **Hai tính năng tương tác cộng đồng còn thiếu:** Tính năng **Tái sử dụng lịch trình (Clone/Personalize)** và **Lưu/Đánh giá (Save & Rating)** đã có sẵn cấu trúc cơ sở dữ liệu và seed data nhưng chưa được kết nối API và giao diện hoàn chỉnh.
3. **Hạn ngạch dịch vụ bản đồ miễn phí:** LocationIQ (5.000 req/ngày, tối đa 2 req/giây) và OpenRouteService (2.000 req/ngày) là các gói miễn phí. Nhóm đã phòng thủ bằng rate limiter và in-memory cache, tuy nhiên cần sự đồng thuận của GVHD về giải pháp fallback khi demo.

### Nhóm 3: Quyết định xin ý kiến GVHD (Decisions to Request)
1. **Chốt phạm vi Web:** Xin phép GVHD chốt định hướng Flutter Web chỉ làm **Cổng Quản trị (Admin Portal)**, không làm giao diện End-User trên Web để tập trung chất lượng cho Mobile.
2. **Chốt cơ chế Clone & Rating:** Xin ý kiến GVHD về nghiệp vụ Clone (tạo bản sao độc lập Deep Copy) và điều kiện cho phép người dùng đánh giá số sao.
3. **Chốt mức độ ưu tiên kế tiếp:** Xin phép GVHD duyệt phương án ưu tiên hoàn thiện tính năng **Lưu lịch trình (Saved Itineraries)** và **Sao chép chuyến đi (Clone Itinerary)** trước, tiếp theo là hoàn thiện các màn hình Web Admin.

