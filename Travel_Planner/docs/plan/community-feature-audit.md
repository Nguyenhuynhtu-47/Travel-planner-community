# Rà soát nền tảng cộng đồng trước khi phát triển

Ngày rà soát: 08/11/2026  
Phạm vi: mã nguồn hiện có của backend Spring Boot và ứng dụng Flutter mobile; rà soát tĩnh entity/JPA, API, service, repository, security, UI/state và danh sách test. Đây là báo cáo phân tích, chưa triển khai tính năng.

## 1. Kết luận chính

Dự án đã có phần nền tảng để hình thành cộng đồng nhưng các mảnh hiện đang ở các mức hoàn thiện khác nhau:

- Bình luận theo lịch trình công khai đã chạy xuyên suốt từ API tới UI: người dùng xem danh sách và người đăng nhập có thể tạo bình luận. Chưa có sửa/xóa, trả lời, kiểm duyệt, giới hạn nội dung ở tầng request hay bộ test riêng.
- Quan hệ theo dõi đã có bảng follows, entity và repository. Chưa có service/controller/endpoint hay UI dùng nó; chưa có quy tắc ngăn tự theo dõi ở luồng ứng dụng.
- Hồ sơ hiện chỉ là hồ sơ cá nhân của tài khoản đang đăng nhập. Không có API hoặc màn hình hồ sơ công khai theo userId/username. UserResponse hiện chứa email, điện thoại, địa chỉ, role và status nên không được dùng trực tiếp cho hồ sơ công khai.
- Activity thuộc một itinerary day, nhưng Comment chỉ tham chiếu itinerary. Chưa thể bình luận trực tiếp một hoạt động hoặc tạo chuỗi trả lời.
- Cơ chế đọc itinerary công khai đã lọc visibility/status và trạng thái chủ sở hữu. Quyền sở hữu cho sửa/xóa itinerary, ngày và activity được xác minh trong service. Nên dùng các quy tắc này làm nền cho cộng đồng, không truy vấn repository thô để tạo trang công khai.
- Chưa thấy migration/schema SQL trong repository. Vì môi trường dữ liệu đang được bảo vệ, báo cáo không kết nối DB, không chạy SELECT/SHOW và không chạy test tích hợp. Các thông tin schema bên dưới là suy ra từ JPA/config, không phải DDL thực tế đã xác minh.

## 2. Kiến trúc hiện tại và dữ liệu

Backend nằm trong backend/src/main/java/Travel_Planner/Travel_Planner; ứng dụng Flutter mobile nằm trong frontend/mobile. Cộng đồng hiện được đặt tại frontend/mobile/lib/features/social, trong khi bình luận nằm riêng ở features/comments. Đây là phân tách hợp lý để tái sử dụng social primitives, nhưng hiện CommunityScreen chỉ là màn hình placeholder.

### 2.1. Các entity và bảng JPA

Các quan hệ ManyToOne dùng LAZY; các cột FK khai báo nullable=false trừ khi ghi chú khác. Entity không khai báo cascade xóa. Không có join table JPA riêng.

| Bảng | Cột và ràng buộc theo entity | Quan hệ / ý nghĩa |
|---|---|---|
| users | user_id PK; username varchar(50) NN, unique; password varchar(255) NN; email varchar(100) NN, unique; role varchar(20) NN; status varchar(20) NN; avatar varchar(500), full_name varchar(100), phone varchar(20), address varchar(255), bio TEXT đều nullable; created_at, updated_at NN | Tài khoản và hồ sơ. Không có collection quan hệ Follow/Comment trong entity User. |
| itineraries | itinerary_id PK; user_id NN FK; original_itinerary_id nullable self-FK; title varchar(150) NN; description TEXT nullable; location varchar(150) NN; cover_image varchar(500) nullable; total_days NN; budget decimal(15,2) NN; theme varchar(100) nullable; visibility/status varchar(20) NN; view_count, favorite_count, rating_count, comment_count, reuse_count NN; created_at/updated_at NN | Một User sở hữu nhiều itinerary; itinerary có thể tham chiếu itinerary gốc. Không khai báo index/unique ở cấp bảng. |
| itinerary_days | day_id PK; itinerary_id NN FK; day_number NN; title varchar(150) nullable; date nullable; created_at/updated_at NN; unique (itinerary_id, day_number) | Một itinerary có nhiều ngày. |
| activities | activity_id PK; day_id NN FK; destination_id nullable FK; name varchar(150) NN; description TEXT nullable; custom_location_name varchar(150), custom_address varchar(255), latitude/longitude decimal(10,7), place_id varchar(100), location_provider varchar(30), image_url varchar(500), start_time/end_time nullable; cost decimal(15,2) NN; display_order NN; created_at/updated_at NN; unique (day_id, display_order); index (latitude, longitude) | Một ngày có nhiều activity; destination catalog chỉ là tham chiếu tùy chọn. Tên/địa chỉ tọa độ tùy chỉnh cũng nằm trên activity. |
| destinations | destination_id PK; name varchar(150) NN; address varchar(255) NN; description TEXT, image_url varchar(500), latitude/longitude decimal(10,7) nullable; status varchar(20) NN; created_at/updated_at NN | Catalog địa điểm, không gắn với chủ sở hữu. |
| comments | comment_id PK; user_id NN FK; itinerary_id NN FK; content TEXT NN; status varchar(20) NN; created_at/updated_at NN | Chỉ thuộc itinerary. Không có activity_id, parent_comment_id hay quan hệ reply. |
| follows | follow_id PK; follower_id NN FK users; following_id NN FK users; created_at NN; unique (follower_id, following_id) | Đã có mô hình dữ liệu quan hệ theo dõi một chiều. |
| favorites | favorite_id PK; user_id NN FK; itinerary_id NN FK; created_at NN; unique (user_id, itinerary_id) | Yêu thích itinerary. |
| ratings | rating_id PK; user_id NN FK; itinerary_id NN FK; score NN; created_at/updated_at NN; unique (user_id, itinerary_id) | Mỗi user một rating trên một itinerary theo unique constraint. |
| saved_itineraries | save_id PK; user_id NN FK; itinerary_id NN FK; created_at NN; unique (user_id, itinerary_id) | Lưu itinerary. |
| itinerary_shares | share_id PK; itinerary_id NN FK; share_token varchar(255) NN, unique; created_at NN; expires_at nullable | Token chia sẻ có thời hạn tùy chọn. |
| offline_downloads | download_id PK; user_id NN FK; itinerary_id NN FK; downloaded_at NN | Ghi nhận itinerary tải offline. |

NN = không được null theo mapping JPA. PK/FK, kiểu vật lý, index phụ do Hibernate tạo ra và hành vi ON DELETE của database chưa được đối chiếu với schema thật. CachedRouteResult và WaypointCoordinate là kiểu dữ liệu hỗ trợ, không phải entity bảng.

### 2.2. ERD rút gọn

    users 1 ── N itineraries 1 ── N itinerary_days 1 ── N activities
      │               │                                  │
      │               ├── N comments                     └── 0..1 destinations
      │               ├── N favorites
      │               ├── N ratings
      │               ├── N saved_itineraries
      │               ├── N itinerary_shares
      │               └── N offline_downloads
      ├── N comments
      ├── N follows (follower_id)
      ├── N follows (following_id)
      └── N itineraries

    itineraries.original_itinerary_id ──> itineraries.itinerary_id

### 2.3. Ý nghĩa riêng cho comments, follows, user, itinerary và activity

Comments có FK tới user và itinerary, nội dung TEXT, trạng thái ACTIVE/HIDDEN/DELETED. Repository hỗ trợ danh sách phân trang theo itinerary và status, cùng bộ đếm tổng/ACTIVE. Entity không có index khai báo, giới hạn độ dài, reply hoặc đích activity. Không khai báo cascade xóa. Service tạo comment tăng comment_count itinerary; chưa thấy cơ chế giảm count vì chưa có API xóa comment.

Follows lưu cạnh follower → following và đã có unique constraint chống trùng theo cặp. Repository hỗ trợ kiểm tra tồn tại, tìm danh sách theo từng phía và đếm số lượng. Repository hiện không phân trang và chưa được gọi bởi luồng sản phẩm ngoài seeder. Unique constraint không ngăn một người theo dõi chính mình.

User có thông tin hồ sơ cá nhân và status ACTIVE/INACTIVE/BANNED. Profile API hiện chỉ tìm theo username từ principal xác thực. Không quan sát thấy API xóa tài khoản người dùng trong các luồng đã rà soát; chính sách xóa tài khoản hoặc xử lý các FK liên quan chưa được xác minh.

Itinerary có visibility PUBLIC/PRIVATE và status ACTIVE/HIDDEN/DELETED. GET chi tiết cho chủ sở hữu có thể xem itinerary của mình; người khác chỉ xem khi itinerary ACTIVE + PUBLIC và chủ sở hữu ACTIVE. Xóa itinerary là soft delete bằng cách chuyển status DELETED. Vì vậy comments/favorites/follows liên quan không bị xóa chỉ bởi thao tác này; comments không còn đọc được qua API công khai do kiểm tra itinerary trước khi truy vấn comment. Cần quyết định riêng về lưu giữ dữ liệu hoặc xóa cứng tài khoản, vì DDL và chính sách FK chưa rõ.

Activity nằm dưới itinerary_day, có thể trỏ destination catalog hoặc giữ custom location/tọa độ/place_id/provider/image. Không có chủ sở hữu trực tiếp; quyền sửa/xóa suy ra từ itinerary → day → activity. Service xác minh ngày thuộc itinerary, activity thuộc ngày và itinerary được sở hữu trước khi thay đổi. Xóa day hiện xóa cứng các activity của ngày đó trước khi xóa day; do chưa có activity-comment, chưa phát sinh quy tắc dọn bình luận activity.

## 3. Backend API, service, security và khả năng tái sử dụng

### Bình luận itinerary

- GET /api/itineraries/{id}/comments?page=&size= là public; POST cùng đường dẫn yêu cầu đăng nhập.
- GET giới hạn page/size, trả trang ACTIVE mới nhất trước và kiểm tra itinerary ACTIVE + PUBLIC cùng User ACTIVE.
- POST yêu cầu principal, trim và từ chối nội dung trống, lưu trạng thái ACTIVE, trả CommentResponse với creator summary (userId, username, fullName, avatar) và thời gian; sau đó tăng itinerary.comment_count.
- Request hiện chỉ có @NotBlank, không thấy @Size, rate limit hoặc lọc spam. Không thấy endpoint sửa/xóa/ẩn comment hoặc quyền moderator/admin để kiểm duyệt. Service không tự kiểm tra status ACTIVE của người comment; cần xác minh hành vi khóa tài khoản ở authentication provider trước khi dựa vào nó như lớp bảo vệ.
- Bảo vệ hiện tại phù hợp với bình luận công khai trên itinerary: người chưa đăng nhập đọc được, chỉ người đăng nhập tạo được. Private/hidden/deleted itinerary bị trả như không tìm thấy. Không hỗ trợ comments cho activity hoặc reply.

### Itinerary và quyền sửa

ItineraryController cung cấp danh sách/chi tiết công khai, tạo/cập nhật/xóa và CRUD ngày/activity. UserItineraryController cung cấp danh sách itinerary của chính người dùng. GET chi tiết cho phép optional auth để trả thêm trạng thái tương tác cá nhân; service kiểm soát private/hidden itinerary theo người xem. Các thao tác ghi nhận username hiện tại và service xác minh quyền sở hữu. Danh sách công khai lọc visibility PUBLIC, status ACTIVE và owner ACTIVE. Không dùng trực tiếp ItineraryRepository.findByUser_UserId để tạo hồ sơ công khai vì truy vấn này không mang bộ lọc công khai.

### Hồ sơ

GET/PUT /api/user/profile thao tác hồ sơ hiện tại, không nhận userId mục tiêu. UserResponse bao gồm email, phone, address, role, status và thông tin cá nhân; an toàn hơn khi chỉ trả cho chủ tài khoản như hiện nay. CreatorSummaryResponse trong itinerary/comment chỉ gồm userId, username, fullName, avatar, là nền DTO gọn hơn nhưng không nên mở rộng bằng cách dùng UserResponse cho người khác.

### Follow

Có Follow entity/repository nhưng không có FollowController, FollowService, endpoint, DTO hoặc mobile follow repository/state. Do đó chưa có nghiệp vụ follow/unfollow, kiểm tra trạng thái follow, danh sách followers/following hoặc số đếm trong profile. Nên tận dụng bảng follows hiện có; cần thêm kiểm tra user hiện hữu/ACTIVE và chặn self-follow ở service, xử lý cạnh tranh khi gửi follow trùng dựa trên unique constraint, và phân trang danh sách trước khi đưa vào UI.

### Ratings, favorites và saved itineraries

Các chức năng tương tác itinerary này đã có controller/service/repository và UI social tương ứng trong mobile. Có thể tham khảo kiểu đồng bộ optimistic/cập nhật summary trong Explore/Itinerary Detail để xây trạng thái follow. Chúng là quan hệ riêng biệt: favorite/save itinerary không tương đương follow user và không nên gộp chung bảng.

## 4. Flutter mobile: màn hình, repository, model, trạng thái và điều hướng

CommunityScreen hiện chỉ hiển thị thông báo tính năng cộng đồng đang phát triển; nút thông báo mở NotificationsScreen. MainNavigationShell đã có tab Cộng đồng và tab Hồ sơ cá nhân, nên có thể triển khai nội dung trong module hiện có mà không cần thêm điểm điều hướng cấp cao.

CommentsRepository gọi GET/POST của itinerary. ItineraryComment chứa commentId, content, creator fields và createdAt. CommentsNotifier quản lý tải trang, xem thêm, gửi comment, lỗi và trạng thái gửi. ItineraryCommentsSection được nhúng trong chi tiết itinerary khi itinerary là PUBLIC; người chưa đăng nhập thấy lời mời đăng nhập, người đăng nhập thấy composer. Mỗi comment hiện chỉ hiển thị avatar, tên, ngày và nội dung. Không có nút hồ sơ tác giả, trả lời, chỉnh sửa hay xóa. Model không phản ánh updatedAt/status/reply target.

ProfileScreen và ProfileRepository chỉ tải/cập nhật profile hiện tại, bao gồm thông tin cá nhân; màn hình có chế độ xem/chỉnh sửa và nội dung itinerary của chính tài khoản. Không có tham số userId/username mục tiêu, public profile model hay trang danh sách follower. Việc tap vùng tác giả ở màn hình Explore hiện dẫn tới ProfileScreen của người đăng nhập, không phải hồ sơ của tác giả itinerary; cần tránh hiểu đó là điều hướng public profile đã có.

Activity được trình bày trong itinerary detail/timeline, nhưng phần comments gắn ở cấp itinerary sau danh sách hoạt động. Chưa có UI hoặc state comment scoped theo activity.

## 5. Kiểm thử hiện có và khoảng trống

Backend có test cho itinerary CRUD/controller, rating, favorite, saved itinerary, seeder, auth/security và nhiều phần map/location. Không thấy test chuyên biệt cho CommentController/CommentService hoặc ProfileController/ProfileService. DataSeederTest tạo dữ liệu kiểm tra comments/follows, nhưng đây là test seeder, không xác nhận API/runtime behavior.

Flutter có itinerary_detail_test, rating_ui_layout_test và social_ui_sync_test cùng các test itinerary/navigation. Không thấy test riêng cho comments repository/notifier/widget, follow/profile công khai hay quyền truy cập hồ sơ người khác. Không chạy bất kỳ test nào trong lần rà soát này do một số test tích hợp/seeder có thể ghi DB; tránh dùng DB test cũng như DB ứng dụng.

Trước khi phát triển nên bổ sung coverage có ý nghĩa cho: private/deleted itinerary không lộ comment; user không đăng nhập không tạo comment; chỉ tác giả hoặc moderator mới sửa/xóa; follow trùng và tự follow; danh sách profile chỉ trả itinerary PUBLIC + ACTIVE; public profile không serialize email/phone/address/role/status; activity comment chỉ truy cập khi activity thuộc itinerary hợp lệ; UI trạng thái lỗi/rỗng/phân trang.

## 6. Đánh giá và đề xuất cho bốn nhóm tính năng

### 6.1. Bình luận itinerary

Nền tảng đã có và có thể giữ nguyên API đọc/tạo. Bước tiếp theo hợp lý là bổ sung giới hạn độ dài/validation ở DTO và service, quy tắc sửa/xóa (tác giả trong khoảng thời gian hoặc bất cứ lúc nào theo sản phẩm; admin/moderator), cập nhật comment_count nguyên tử/chính xác, và UI menu chỉ hiện hành động cho đúng người. Cần xác định HIDDEN/DELETED được xử lý ra sao và có cần giữ bản ghi audit không. Không nên để client tự gửi userId người viết; backend phải lấy user từ token như hiện nay.

### 6.2. Hồ sơ công khai

Thêm endpoint đọc theo userId hoặc username và PublicProfileResponse tách biệt UserResponse. DTO công khai tối thiểu nên có userId, username, fullName, avatar, bio, createdAt hoặc thông tin tham gia phù hợp, số follower/following và trạng thái viewer-following (nếu có đăng nhập). Không trả email, phone, address, role, password/hash hoặc trạng thái moderation. Thêm truy vấn trang itinerary công khai theo owner với điều kiện itinerary PUBLIC + ACTIVE và user ACTIVE; không tái sử dụng truy vấn không lọc của trang “itinerary của tôi”. Bên mobile cần profile screen nhận user mục tiêu và repository endpoint riêng, giữ profile hiện tại cho chế độ sửa.

### 6.3. Follow/unfollow

Tận dụng follows hiện tại; không cần bảng mới cho hành động theo dõi một chiều. Bổ sung service/controller cho follow, unfollow, trạng thái theo dõi, follower/following list phân trang và các count. Ràng buộc unique hiện có bảo vệ cặp trùng ở DB nếu schema đang đồng bộ; service vẫn cần xử lý idempotency và self-follow rõ ràng. Quy định trước hành vi khi tài khoản bị INACTIVE/BANNED hoặc bị xóa, cũng như việc block/mute có nằm ngoài phạm vi phiên bản đầu hay không. UI có thể bắt đầu bằng nút Theo dõi trên public profile, đồng bộ số đếm và trạng thái sau phản hồi server.

### 6.4. Bình luận hoạt động / trả lời bình luận

Đây là thay đổi schema/API thực sự; bảng Comment hiện chỉ có itinerary_id. Trước khi triển khai phải chọn mô hình:

- Nếu cần comment trên cả itinerary và activity: thêm activity_id nullable và quy tắc đúng một target (itinerary hoặc activity), kèm index phục vụ truy vấn. Cách này ít bảng hơn nhưng làm quan hệ target đa hình bằng hai FK và validation khó biểu đạt chỉ bằng JPA.
- Nếu muốn tách rõ vòng đời và tải độc lập: tạo activity_comments riêng với FK activity_id/user_id; tránh một bảng comments có hai target nullable, nhưng phát sinh API/model/moderation trùng lặp.
- Replies có thể dùng parent_comment_id self-FK nullable trên comments, với kiểm tra cùng target và giới hạn độ sâu; hoặc bảng reply riêng nếu sản phẩm cần quyền/vòng đời khác. Không nên thêm reply chỉ để giả lập thread nếu UI chưa có yêu cầu.

Khuyến nghị cho phiên bản đầu: giữ comments itinerary như hiện tại và hoàn thiện edit/delete/moderation trước; sau đó mới chốt activity comments/replies dựa trên phạm vi sản phẩm. Nếu cần comment activity ngay, chọn một trong hai mô hình trên trước khi viết migration để tránh API/schema thay đổi hai lần.

## 7. Rủi ro, phụ thuộc và quyết định cần chốt trước khi code

1. DDL production có thể lệch mapping do không thấy migration và dev đang dùng Hibernate update trong khi prod validate. Trước mọi thay đổi bảng cần lấy schema thật bằng quy trình DBA/read-only đã được chấp thuận, so sánh với entity rồi tạo migration có kiểm soát.
2. Xóa itinerary hiện là soft delete nhưng FK dữ liệu cộng đồng vẫn tồn tại. Cần quyết định khi xóa tài khoản: ẩn/ẩn danh dữ liệu, xóa mềm, hoặc xóa cứng có dọn comment/follow trước; không suy luận ON DELETE từ entity.
3. Profile API hiện có PII trong UserResponse. Tạo DTO công khai riêng là yêu cầu bảo mật, không chỉ là lựa chọn giao diện.
4. comment_count là counter lưu trên itinerary; create tăng bằng query update nhưng chưa có delete flow. Khi thêm xóa/ẩn comment cần bảo đảm count khớp và tránh cập nhật đồng thời sai.
5. Follow list hiện không phân trang; tải toàn bộ có thể tăng chi phí khi mạng xã hội lớn. Dùng page/cursor và index theo follower_id/following_id sau khi đối chiếu DDL thực tế.
6. Tài khoản bị khóa, moderation, rate limit/spam, giới hạn độ sâu reply và thông báo khi follow/comment chưa được thống nhất trong code hiện tại.
7. Không có bằng chứng UI hồ sơ tác giả là hồ sơ công khai; hiện navigation ở Explore mở hồ sơ của chính người dùng. Cần truyền creator id/username xuyên suốt card → route → repository.

## 8. Danh sách file liên quan đã rà soát

- Backend entity/schema mapping: backend/src/main/java/Travel_Planner/Travel_Planner/model/{User,Itinerary,ItineraryDay,Activity,Destination,Comment,Follow,Favorite,Rating,SavedItinerary,ItineraryShare,OfflineDownload}.java
- Comment API/logic: controller/CommentController.java, service/CommentService.java, service/impl/CommentServiceImpl.java, repository/CommentRepository.java, dto/request/CreateCommentRequest.java, dto/response/CommentResponse.java, dto/response/PageResponse.java
- Profile API/logic: controller/ProfileController.java, service/impl/ProfileServiceImpl.java, dto/response/UserResponse.java, dto/response/CreatorSummaryResponse.java
- Itinerary access and ownership: controller/ItineraryController.java, controller/UserItineraryController.java, service/impl/ItineraryServiceImpl.java, repository/ItineraryRepository.java, security/SecurityConfig.java
- Follow data layer: model/Follow.java, repository/FollowRepository.java; chưa có service/controller/client tương ứng.
- Mobile community/comments/profile/navigation: frontend/mobile/lib/features/social/presentation/screens/community_screen.dart, features/comments/{data, presentation}, features/profile/{data,presentation}, features/itinerary/presentation/screens/itinerary_detail_screen.dart, features/explore/presentation/screens/explore_screen.dart, shared/navigation/main_navigation_shell.dart.
- Test inventory: backend/src/test/java/...; frontend/mobile/test/features/social, itinerary_detail_test.dart, itinerary activity/profile/navigation tests.

## 9. Giới hạn xác minh

Không thực hiện kết nối database, SELECT/SHOW, chạy test, seeder hoặc lệnh có thể ghi dữ liệu. Không tìm thấy migration/schema SQL trong danh sách file repository đã rà soát. Vì vậy danh sách bảng/cột/unique/index trong tài liệu mô tả JPA mapping trong mã nguồn; cần đối chiếu database thật trước khi viết migration hoặc triển khai thay đổi schema.