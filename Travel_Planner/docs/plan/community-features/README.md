# Kế hoạch thiết kế và triển khai chức năng cộng đồng

Ngày lập: 09/11/2026  
Cơ sở: docs/plan/community-feature-audit.md, yêu cầu Giai đoạn 2 và yêu cầu bổ sung bình luận/reply kiểu Facebook.  
Trạng thái: Kế hoạch community ban đầu được chốt trước khi sửa source; cập nhật 09/11/2026 bổ sung audit Git/JPA/design và phương án refactor theo Hibernate hiện có. Không chạy trên database.

## 0. Rà soát Git, quy định dự án và quyết định JPA — 09/11/2026

### Git trước khi refactor

- Nhánh hiện tại: `feature/test-changes`, tracking `origin/feature/test-changes`.
- Working tree có 21 file tracked đã sửa, 18 file mới/untracked, không có file staged. Không có thay đổi nào bị xóa hoặc reset.
- Thay đổi tracked nằm trong backend comment/profile repositories/security/services và Flutter comments/activity/detail/explore. File untracked gồm controller/DTO/service profile-comment, các test mới, hai tài liệu audit/plan, Flutter profile repository/screen/tests và file SQL ở mục database bên dưới.
- Tám commit trên nhánh kể từ merge-base với `develop` là các commit LocationIQ/TomTom; không chứa implementation community của đợt hiện tại. Không thấy commit community trong log của HEAD. Lịch sử toàn repository có baseline comment itinerary cũ ở commit `46ca43d` và UI ở `df2f9ab`.
- `pom.xml`, `application.properties`, README và cấu hình provider không bị sửa trong working tree. Không phát hiện secret mới trong các file community được thêm/sửa; không in credential values trong audit.
- Không chạy reset/clean/restore/checkout/commit/push/merge/rebase.

### Tài liệu quy định đã đối chiếu

- `AGENTS.md`; `DESIGN.md`.
- `docs/ai/00-project-context.md` đến `docs/ai/10-animation-guidelines.md`, gồm architecture, coding rules, API contract, design system, UX, feature specification, testing, workflow và development log; đọc các mục cộng đồng/liên quan trong `docs/Travel_Planner_Function_Specification.md`.
- `docs/promts/entity_generation.md`, `docs/plan/community-feature-audit.md` và kế hoạch community hiện tại.

Quy định áp dụng: giữ package Spring hiện tại; giữ Flutter feature structure, API client/repository/notifier; backend là lớp thực thi quyền; không thêm dependency; dùng Theme/AppColors/shared widgets và các trạng thái loading/error/empty hiện có; không tự thêm migration framework; development log phải được ghi bằng tiếng Anh.

### Bảng đối chiếu source và cách xử lý

| File/nhóm file | Vấn đề xác nhận | Quy định | Cách xử lý trong đợt này |
|---|---|---|---|
| `Comment.java`, `CommentRepository.java`, `CommentServiceImpl.java` | Root cũ có thể có `root_comment_id = NULL`; index JPA chưa khai báo; activity comment đang chỉ lưu `activity_id` nên yêu cầu `itinerary_id` nullable | Tương thích dữ liệu cũ, dùng JPA, phân trang DB, tránh full-table backfill | Giữ `root_comment_id` nullable; root cũ lấy bằng `parent_comment_id IS NULL` và fallback root ID từ chính comment; reply mới luôn ghi `root_comment_id`. Ghi cả itinerary FK và activity FK cho activity comment để không cần đổi nullability cột itinerary cũ. Khai báo các index cần thiết ở `@Table`.
| `V1__community_comment_threads.sql` | Không có Flyway/Liquibase và không có SQL init; file không tự chạy, còn chứa backfill | Không tạo script song song `ddl-auto=update`; không startup backfill | Service tests xác nhận backfill không cần; file đã được loại khỏi source. Không chạy DDL/DML trên DB.
| Flutter comments/profile screens | Dùng AppColors một phần nhưng còn raw `Colors.black54`, style/padding rải trực tiếp; profile và user-list cùng file, formatting quá cô đọng | Theme/design tokens, shared widgets, focused responsibility, readable Dart | Chuyển style sang Theme/AppColors và các token spacing cục bộ nếu dự án chưa có; tách follower/following list thành screen riêng; tái sử dụng loading/error/empty/shared button nơi phù hợp.
| Controller/service/DTO/repository | Đặt đúng package; kiểm tra lại validation, authorization, idempotency, N+1 và backward compatibility | Layer boundaries, server-side authorization, response allowlist | Giữ endpoint cũ; chỉ sửa lỗi được test hoặc audit chứng minh; không thay API ngoài cần thiết.

### Quyết định database cho MySQL mới và schema cũ

`pom.xml` không khai báo Flyway/Liquibase; `application.properties` dùng `spring.jpa.hibernate.ddl-auto=update`, không cấu hình `spring.sql.init`. README chạy `mvnw spring-boot:run`. Vì vậy file dưới `db/migration/` không tự chạy; Hibernate chỉ đồng bộ mapping, không chạy lệnh backfill `UPDATE`.

Không yêu cầu backfill toàn bộ comment cũ: dữ liệu cũ không có reply, root được nhận diện bằng `parent_comment_id IS NULL`; response dùng `commentId` khi `root_comment_id` null. Reply phát sinh từ root cũ vẫn truy vết root qua parent chain rồi ghi root ID trên reply mới. Phân trang replies tiếp tục query theo `root_comment_id`; không tải cây vào bộ nhớ. Không bỏ cột root.

Activity comment mới sẽ lưu cả `itinerary_id` của lịch trình chứa activity và `activity_id`; `activity_id` quyết định target hiển thị. Cách này giữ itinerary FK NOT NULL của schema cũ, tránh đổi nullability có thể không được Hibernate update an toàn. Khi activity/day bị xóa, activity comments chuyển thành itinerary comments trong transaction như hiện tại.

Hibernate `update` được dùng cho cột/quan hệ mới và index được khai báo trong Entity. Tuy nhiên, chưa có MySQL test service khả dụng trong môi trường hiện tại; do đó không tuyên bố đã chứng minh schema upgrade thực tế. Trước production cần kiểm tra schema thực bằng bản sao DB, đặc biệt FK/index tự tạo và cột itinerary đã bị nullable bởi lần chạy code thử trước đây (nếu có). Không chạy trên database chính.

### Files dự kiến sửa trong bước refactor

- Backend: `model/Comment.java`, `repository/CommentRepository.java`, `service/impl/CommentServiceImpl.java`, các test service hiện hữu; chỉ thêm test JPA khi có DB cô lập sẵn.
- Flutter mobile: comment widget, public profile screen, tách user-list screen, dùng shared theme/loading/error/empty components; tests tương ứng.
- Docs: kế hoạch này và cuối task append entry tiếng Anh vào `docs/ai/09-development-log.md`.
- File `V1__community_comment_threads.sql` đã được loại khỏi source sau khi kiểm tra tham chiếu và test xác nhận comment cũ/reply mới không phụ thuộc backfill.

### Kiểm tra nghiệm thu cho refactor

- Backend unit tests cho comment cũ có root null, reply nhiều cấp, activity target lưu đủ hai FK, activity isolation, profile/follow ACL; compile/test cô lập không kết nối MySQL chính.
- Flutter `dart format` trên file đã sửa, `flutter analyze`, targeted widget tests và full test suite. Kiểm tra Theme/AppColors, responsive/safe-area và composer với keyboard trong widget tests khi có thể.
- Kiểm tra `git diff --check`, không stage/commit, không sửa `pom.xml`, README, provider config hoặc dữ liệu DB.
- Motion analysis: không thêm animation tùy chỉnh; giữ motion Material mặc định cho bottom sheet/navigation, không tăng chuyển động lặp trong thread. Shared states đã có kiểm tra `MediaQuery.disableAnimations`.

## 1. Mục tiêu và phạm vi

Triển khai trên nền kiến trúc hiện tại bốn nhóm chức năng:

1. Bình luận itinerary, bình luận activity và thread reply nhiều cấp.
2. Hồ sơ công khai và danh sách itinerary công khai của tác giả.
3. Follow/unfollow, số đếm và danh sách follower/following.
4. Flutter UI/state/navigation và kiểm thử hồi quy cho cả ba nhóm.

Giữ nguyên endpoint GET/POST comment itinerary, GET/PUT hồ sơ cá nhân, CRUD itinerary/activity, các feature rating/favorite/save, LocationIQ/TomTom, CARTO, Cloudinary và điều hướng hiện hữu ngoài nơi cần mở hồ sơ tác giả. Không nhận userId tác giả từ client. Không tạo hệ thống comment hoặc follow trùng với entity/repository đã có.

## 2. Hiện trạng xác nhận lại trong source

- CommentController/CommentServiceImpl hỗ trợ GET trang comment ACTIVE công khai và POST comment itinerary khi đăng nhập. Comment gắn cứng itinerary_id NOT NULL, chưa có parent, activity target, edit/delete hay API replies.
- Follow và FollowRepository đã có unique (follower_id, following_id), nhưng chưa có service/controller/API/UI.
- Profile API chỉ phục vụ tài khoản đăng nhập. UserResponse chứa dữ liệu riêng tư; public profile phải dùng DTO riêng.
- Itinerary detail kiểm tra PUBLIC/ACTIVE và owner ACTIVE cho người xem công khai; quyền sửa itinerary/day/activity được kiểm tra trong service.
- Xóa itinerary là soft delete. Xóa day xóa cứng activities trước khi xóa day. Trước khi activity/day bị xóa, chuyển comments/replies của activity sang itinerary chứa nó để giữ nguyên nội dung và parent/root thread, đồng thời cộng số ACTIVE vào itinerary.comment_count. Không xóa nội dung comment khi hard-delete activity.
- Flutter có CommentsRepository/Notifier/ItineraryCommentsSection và ProfileScreen cá nhân. CommunityScreen là placeholder. Activity timeline được render trong Itinerary Detail.
- Không tìm thấy migration SQL/Flyway đang được cấu hình. Schema thật chưa được đọc; Hibernate mapping hiện tại không chứng minh được DDL production.

## 3. Quyết định thiết kế

### 3.1. Schema comments và JPA (quyết định cập nhật 09/11/2026)

Dùng chung bảng comments. Hibernate `ddl-auto=update` bổ sung các quan hệ nullable `activity_id`, `parent_comment_id`, `root_comment_id`; không đổi/drop tên hay kiểu cột hiện có. Giữ `itinerary_id` nullable ở mapping để tương thích các DB đã được Hibernate thử update trước đó; mọi comment mới do service tạo vẫn gắn itinerary. Activity comment ghi đồng thời itinerary FK và activity FK; `activity_id != null` xác định target activity. Reply sao chép cả target từ parent.

Root cũ có `parent_comment_id = NULL` và có thể `root_comment_id = NULL`. Root list dùng parent null; response fallback root ID về comment ID. Không chạy backfill toàn bảng. Reply mới truy vết root từ parent chain và lưu `root_comment_id`, nên phân trang root thread vẫn truy vấn DB theo root ID. Không bỏ cột này. Entity khai báo composite indexes cho root itinerary, root activity và thread page; Hibernate tạo index theo khả năng của dialect. Các FK/index vật lý cần đối chiếu trên bản sao MySQL trước khi tuyên bố schema cũ đã nâng cấp an toàn.

Không dùng `V1__community_comment_threads.sql`: file này không được cấu hình để chạy, và quy tắc `entity_generation.md` yêu cầu giữ một cơ chế schema duy nhất trong khi `ddl-auto=update` là cơ chế đang chọn. Sau khi xác nhận code, tests và tìm kiếm tham chiếu chứng minh backfill không còn cần, loại file untracked khỏi source. Không thêm Flyway/Liquibase, startup runner, hoặc chạy DDL/DML thủ công.

### 3.2. API comments

Giữ nguyên:
- GET/POST /api/itineraries/{itineraryId}/comments

Bổ sung:
- GET/POST /api/activities/{activityId}/comments: danh sách/tạo root comment thuộc activity.
- GET/POST /api/comments/{commentId}/replies: tải trang replies trong root thread và tạo reply vào commentId làm parent trực tiếp.
- PUT/DELETE /api/comments/{commentId}: sửa và soft delete.

CommentResponse giữ các trường cũ, thêm optional parentCommentId, rootCommentId, replyCount, deleted, target type/target ID và replyToCreator để client cũ bỏ qua được. GET roots phân trang parent_comment_id IS NULL; GET replies truy vấn root_comment_id = root của comment, comment_id != root, phân trang ở DB theo createdAt ASC/commentId ASC. Không tải cây vào bộ nhớ. replyCount đếm reply ACTIVE trực tiếp hay toàn thread? Quyết định: số replies hiển thị trên root là tổng comment ACTIVE trong thread, trừ root; các reply được phân trang phẳng, mỗi reply kèm creator của parent để UI hiển thị “trả lời @Tên”. Lưu trực tiếp parent nên cấu trúc sâu vẫn chính xác.

Quyền đọc comments theo target: target activity phải nằm trong itinerary PUBLIC + ACTIVE, owner ACTIVE. Authenticated owner có thể xem target của itinerary riêng thông qua cơ chế quyền chi tiết hiện hành nếu API detail hỗ trợ; hiện CommentService chỉ public, vì vậy phiên bản này giữ nguyên chính sách comments công khai, không mở private comments. Hidden/deleted itinerary và owner INACTIVE/BANNED trả not found. Tạo/sửa/xóa cần user ACTIVE; owner comment được sửa/xóa, admin dùng role hiện có để moderation. Xóa comment là soft delete và thay content bằng placeholder; root vẫn trả placeholder khi có reply ACTIVE để giữ thread. HIDDEN/DELETED không được liệt kê riêng.

Count: itinerary.comment_count tiếp tục đếm mọi comment ACTIVE thuộc itinerary, replies cũng được tính. Activity comments không ảnh hưởng itinerary.comment_count; activity count tính qua repository query khi cần. Create/delete cập nhật trong transaction và không cho count âm. Ẩn/xóa comment trừ count một lần; sửa không đổi count. Không thêm cached counter cho activity.

### 3.3. Public profile và follow API

Tạo PublicProfileResponse chỉ có userId, username, fullName, avatar, bio, createdAt, followerCount, followingCount, isFollowing, isOwnProfile. Không có email/phone/address/role/status/password.

API:
- GET /api/users/{userId}/public-profile
- GET /api/users/{userId}/itineraries?page=&size=
- POST/DELETE /api/users/{userId}/follow
- GET /api/users/{userId}/followers?page=&size=
- GET /api/users/{userId}/following?page=&size=

Follow dùng principal làm follower. POST/DELETE idempotent, reject self-follow và user đích không ACTIVE; unique key bảo vệ cạnh tranh. Danh sách chỉ trả user summary an toàn và phân trang DB. Profile cho anonymous trả isFollowing=false/isOwnProfile=false; authenticated nhận trạng thái viewer. Public itinerary query lọc user đúng ID + visibility PUBLIC + status ACTIVE + owner ACTIVE. Giữ /api/user/profile riêng tư hiện có.

### 3.4. Flutter

Comments: mở rộng model/repository/notifier hiện có với target abstraction, pagination root/replies, reply target state, create/edit/delete và guard chống gửi trùng. Dùng chung comment thread widget và composer. Root replies hiển thị phẳng dưới comment gốc (mức thụt lề hữu hạn); sâu hơn hiển thị nhãn “trả lời @parent”. Có thể hủy reply, focus composer, tải thêm/thu gọn thread. ActivityCommentsSection mở bottom sheet hoặc route có target activity ID, state theo target key để không rò dữ liệu giữa activity. Mỗi ActivityTimelineItem có nút comment/count nhưng giữ nguyên sửa/xóa/map/image behavior.

Profile/follow: thêm public profile repository/model/screen, follow button, paginated user list screen dùng chung cho followers/following, public itinerary list. Tác giả trong Explore/Itinerary Detail/comment mở đúng profile theo userId. ProfileScreen hiện tại tiếp tục là hồ sơ sửa của mình; không truyền UserResponse sang public UI.

### 3.5. Giới hạn và bảo mật

Giới hạn content ở 2,000 ký tự; không đặt giới hạn độ sâu reply ở phiên bản đầu để không làm mất khả năng trả lời nhiều cấp. Chống lạm dụng bằng request validation, authenticated writes và chống gửi trùng UI; rate limiter hệ thống chưa có nên không thêm hạ tầng ngoài phạm vi. Tất cả list phân trang trong DB, entity graph/projection để lấy user và tránh N+1. Mọi DTO công khai chỉ expose fields allowlist.

## 4. File dự kiến

### Backend sửa/tạo

- Sửa model/Comment.java; repository/CommentRepository.java; service/CommentService.java và service/impl/CommentServiceImpl.java; controller/CommentController.java và có thể thêm ActivityCommentController.java; dto/request/CreateCommentRequest.java và request update; dto/response/CommentResponse.java.
- Sửa ItineraryServiceImpl.java và CommentRepository.java để chuyển activity comments sang itinerary trước khi hard-delete activity/day, giữ thread và cập nhật counter trong cùng transaction.
- Dùng JPA `@ManyToOne` mapping và `@Table(indexes=...)`; không tạo migration SQL/framework. Kiểm thử schema cũ/trống chỉ trên MySQL cô lập khi môi trường đó được cung cấp.
- Tạo PublicProfileResponse, UserSummaryResponse nếu cần, FollowStateResponse; PublicUserController; FollowService/FollowServiceImpl/FollowController.
- Sửa UserRepository, FollowRepository, ItineraryRepository để thêm các truy vấn trang/projection.
- Sửa SecurityConfig cho GET public, writes authenticated.
- Test unit/service/controller/repository cô lập, không dùng app DB.

### Flutter sửa/tạo

- Sửa features/comments/data/models/itinerary_comment.dart, data/comments_repository.dart, presentation/comments_notifier.dart, presentation/widgets/itinerary_comments_section.dart.
- Tạo widget chung comment thread/item/composer, ActivityCommentsSection và activity comments sheet/route.
- Sửa itinerary/presentation/widgets/activity_timeline_item.dart và itinerary_detail_screen.dart để mở comment theo activity.
- Tạo public profile model/repository/notifier/screen; follow repository/state/button; paginated follower/following list screen.
- Sửa itinerary detail/explore/comment author navigation để truyền userId thật.
- Giữ ProfileScreen hiện tại cho tài khoản của mình.

Các đường dẫn sẽ được đối chiếu khi implement; không sửa map, upload, auth contract hay các module ngoài phạm vi trên.

## 5. Giai đoạn và tiêu chí nghiệm thu

1. Kế hoạch: hoàn tất tài liệu này và kiểm tra file trước khi source edits.
2. Database: JPA additive mapping/indexes; không backfill root cũ, giữ root nullable và không chạm DB.
3. Backend comments: tương thích endpoint cũ; activity roots; replies nhiều cấp/root pagination; edit/delete; access/count; tests.
4. Backend profile/follow: DTO allowlist; public itinerary pagination; follow idempotent; list pagination; tests.
5. Flutter comments: component dùng chung; activity sheet; reply focus/cancel/mention; pagination/expand; edit/delete; activity isolation; tests.
6. Flutter profile/follow: public profile, navigation từ Explore/detail/comment, follow, follower/following list, tests.
7. Hồi quy: chạy backend unit tests không chạm DB thật; Flutter analyze/test. Nếu test config hiện tại khởi động DB/seeder hoặc ghi test DB chưa cô lập được, dừng phần đó và báo rõ.
8. Báo cáo: liệt kê files, contract, migration chưa áp dụng, test pass/fail, giới hạn xác minh. Không khẳng định hoàn thành nếu test bắt buộc còn thất bại/chưa chạy.

## 6. Test plan bắt buộc

Backend: comment itinerary cũ; activity A không lẫn activity B; private/hidden/deleted bị chặn; reply A→B→C→D giữ parent/root; paginate roots và replies độc lập, thứ tự ổn định; reply khác target bị từ chối; edit/delete chỉ tác giả/admin; xóa parent vẫn placeholder và reply còn; activity/day delete dọn liên quan; count chính xác; profile allowlist; chỉ public itinerary; follow self/duplicate/repeated unfollow/blocked target/count/page; anonymous read và authenticated write.

Flutter: repository request parsing, root/reply pagination no duplicate, reply không thành root, show/collapse thread, mention target, cancelled reply, edit/delete ownership, activity A/B isolation, comment sheet anonymous read, public profile không PII, follow state/auth/self, follower/following pagination, correct author navigation, old itinerary comments rendering.

## 7. Rủi ro và điều kiện chặn triển khai DB

Schema vật lý chưa được đọc và Hibernate `update` không phải migration tool đầy đủ; chưa xác minh nullability/foreign keys/indexes trên MySQL cũ. Mapping giữ tương thích với itinerary comments cũ và không yêu cầu backfill root. Trước khi rollout cần sao lưu, xác nhận DDL bằng database bản sao, kiểm tra Hibernate update có thêm đúng cột/FK/index và không tạo duplicate. Không áp dụng bất kỳ DDL/DML nào lên database chính trong task này.

## 8. Theo dõi triển khai — cập nhật 09/11/2026

- Phase 1: hoàn tất tài liệu này và đối chiếu source trước khi chỉnh code.
- Phase 2 (kế hoạch cũ đã được thay thế): không dùng `V1__community_comment_threads.sql`; JPA/Hibernate là schema manager duy nhất. Giữ `itinerary_id` hiện có, thêm nullable activity/parent/root associations và indexes trong Entity. Không backfill comment cũ.
- Phase 3: thêm activity comment, thread reply, update/delete soft, tombstone khi còn replies, xác minh parent chain/root, page roots và page replies trong repository. Khi xóa activity/day, chuyển comments/replies sang target itinerary để không mất dữ liệu và cộng counter chính xác. Endpoint itinerary cũ giữ nguyên, response chỉ được mở rộng trường.
- Phase 4: thêm public profile DTO allowlist, public itinerary page có lọc PUBLIC + ACTIVE, follow/unfollow idempotent, counts và page followers/following. GET công khai; POST/DELETE theo JWT.
- Phase 5: tái sử dụng CommentsNotifier/repository/section cho itinerary và activity; replies hiển thị phẳng dưới root, có mention người được trả lời, mở/thu gọn, phân trang, sửa/xóa. Activity mở sheet riêng và state được tạo riêng theo activity ID.
- Phase 6: thêm PublicProfileScreen, follow control, danh sách user phân trang, và điều hướng tác giả từ Explore/detail/comment theo userId.
- Phase 7: Maven compile thành công; 7 backend Mockito unit tests pass, không dùng database. Flutter analyze sạch; test mới cho comments/profile pass. Toàn bộ Flutter suite ghi nhận 341 pass và 2 test trong Inline Activity Reordering UX fail vì không thấy label sau thao tác sắp xếp. Code reordering không nằm trong thay đổi cộng đồng; cần rà riêng test/fixture này để xác định nguyên nhân nền.
- Phase 8: không có migration cần rollout; chưa chạy toàn bộ backend suite vì cấu hình Spring integration dùng MySQL `travel_planner_test`. Không thể xác nhận schema vật lý hoặc hành vi integration trước khi có MySQL thử nghiệm được xác nhận cô lập.

### Contract backend sau triển khai

- Giữ GET/POST /api/itineraries/{itineraryId}/comments.
- Thêm GET/POST /api/activities/{activityId}/comments.
- Thêm GET/POST /api/comments/{commentId}/replies; commentId trong POST luôn là parent trực tiếp, root được truy vết từ parent chain.
- Thêm PUT/DELETE /api/comments/{commentId}; DELETE là soft delete và trả placeholder trong thread còn reply.
- Thêm GET /api/users/{userId}/public-profile, GET /api/users/{userId}/itineraries, POST/DELETE /api/users/{userId}/follow, GET followers/following.

### Chưa xác minh

DDL thật, tên/định nghĩa FK/index hiện tại, Hibernate schema update trên đúng phiên bản MySQL, JWT/HTTP integration tests và các trường hợp concurrency follow. Các bước này cần DB bản sao an toàn; không áp dụng DDL/DML lên database đang chạy.
