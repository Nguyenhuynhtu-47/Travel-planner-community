# 01 — Audit hệ thống hiện tại

## 1. Nền tảng và giới hạn audit

Dự án hiện có Spring Boot 4.1.1, Java 22, Spring Security/JWT, Spring Data JPA, MySQL; Flutter Mobile và Flutter Web dùng chung REST JSON backend. App đang là stateless JWT. Không thấy cấu hình Spring WebSocket/STOMP, WebSocket dependency, Firebase messaging hay client realtime trong source đã kiểm tra. pom.xml có JPA, Security, MVC, validation, Caffeine, Bucket4j; Mobile chỉ khai báo http, secure storage, map/image/url packages; chưa có STOMP dependency.

Các kết luận dưới đây dựa trên source/config/docs được đọc tại nhánh develop ngày 2026-11-10. Chưa chạy app, test, kết nối MySQL hay kiểm tra schema vật lý.

## 2. Tài sản có thể dùng lại

### Backend

- model/User.java: ID Integer; username đăng nhập, handle công khai, avatar, fullName; status ACTIVE/INACTIVE/BANNED. Không có friendship hoặc setting nhắn tin.
- model/Follow.java + repository/FollowRepository.java: quan hệ một chiều follower → following, unique cặp follower/following và truy vấn danh sách/count.
- PublicUserController, PublicUserServiceImpl: profile theo ID/handle, danh sách itinerary công khai, follow/unfollow, followers/following. Controller hiện cho GET /api/users/** public; service lọc target/viewer ACTIVE; follow dựa principal, cấm tự follow, idempotent qua unique guard.
- PublicProfileResponse: allowlist public fields và trạng thái isFollowing, isOwnProfile. Không trả email/phone/address/role/password. Có thể mở rộng contextual state nhưng không đặt preference riêng tư vào public DTO.
- JwtTokenProvider, JwtAuthenticationFilter, UserDetailsServiceImpl, SecurityConfig: JWT Bearer cho REST, stateless session, GET profile public; writes cần auth. UserDetails khóa account BANNED và disable account không ACTIVE.
- GlobalExceptionHandler, AppException subclasses, ErrorResponse: dùng lại convention lỗi.
- UserHandleBackfillRunner: ApplicationRunner hiện tự kiểm tra/ALTER users.handle, backfill và thêm unique key; schema lỗi được log và bỏ qua. Không nên tạo runner tương tự cho chat.

### Flutter Mobile

- PublicProfileScreen: hiển thị tên/avatar/bio/follow state và public itinerary; hiện có follow CTA, own profile edit CTA; nhận AuthNotifier? và repository inject được để test.
- PublicProfileRepository: dùng ApiClient cho profile, follow/unfollow, public itinerary, followers/following.
- AuthNotifier: ChangeNotifier, sở hữu trạng thái/token/current user, phát notifyListeners khi login/logout/session update; là điểm quan sát đổi tài khoản.
- ApiClient: HTTP wrapper gửi Authorization Bearer, timeout 15s, xử lý lỗi/401. Không phải WebSocket client.
- MainNavigationShell: 5 tab cố định và IndexedStack. CommunityScreen hiện là placeholder và AppBar có notification route. Không thêm tab thứ sáu.
- Điều hướng hiện dùng Navigator.push(MaterialPageRoute) trực tiếp; itinerary detail có đường mở profile creator; profile authorship dùng userId.
- Theme tokens ở core/theme; shared empty/error/button/input widgets; dùng lại khi triển khai UI.

### Flutter Web

frontend/web là app riêng, code hiện có auth, profile, quản trị destinations; không chia sẻ source với mobile. Backend APIs mới vẫn dùng chung. Web chat không thuộc MVP; duy trì test/build hiện tại và không tạo giả định rằng Mobile UI dùng được trên Web.

## 3. Gaps và điểm tài liệu đã cũ/mâu thuẫn

- Không có Conversation, Message, Friendship, block, messaging preferences hoặc push token entity/API.
- Follow đã có service/controller ở source hiện tại và public profile UI; một số plan cộng đồng cũ nói Follow chỉ có entity/repository, nên đó là mô tả lỗi thời.
- Mobile community screen vẫn là placeholder; đây là điểm tích hợp hợp lý, nhưng phải giữ bottom navigation 5 tab.
- Chưa có route/navigation framework riêng; tạo feature mới theo cấu trúc hiện tại thay vì thêm router layer lớn.
- Source hiện tại dùng API/JWT thật; docs/ai/01-architecture.md phần cũ mô tả permitAll/no JWT trái với code. Code + task-specific audit là căn cứ cho kế hoạch.
- docs/ai/12-project-status-and-next-steps.md liệt kê real-time chat ngoài scope. Main functional specification yêu cầu không suy diễn hạng mục chưa chốt thành yêu cầu; task hiện tại là yêu cầu mới chỉ để lập plan.
- docs/promts/entity_generation.md giới hạn schema cũ ở 12 bảng và cấm tự trộn schema manager. Quyết định Giai đoạn 2 đã cho phép bổ sung bảng chỉ cho chat/friendship trong Development; các giới hạn ngoài phạm vi đó vẫn giữ.

## 4. Database/schema hiện trạng

application.properties dùng spring.jpa.hibernate.ddl-auto=update; application-prod.properties dùng validate. Không tìm thấy migration file đã cấu hình chạy; resources/db/migration hiện không có SQL migration. Hibernate update không thay thế migration có version và không bảo đảm xử lý rename/rollback. Backfill handle là ngoại lệ DDL viết tay trong startup runner.

Không truy cập DB; chưa xác minh MySQL version, table definitions, FK/index, dữ liệu tồn tại hay schema drift. Trước schema implementation cần khảo sát snapshot/copy DB. Không chạy DDL/DML trong Giai đoạn 2; plan chưa truy cập database.

## 5. Tests hiện có liên quan

- Backend: PublicUserServiceTest, AuthControllerTest, JwtTokenProviderTest, cùng test profile/handle. Không thấy tests friend/chat/WebSocket.
- Mobile: features/profile/public_profile_screen_test.dart, features/profile/user_handle_test.dart, bottom_navigation_test.dart, auth_401_test.dart, social UI tests. Không thấy chat/friend tests.
- Web: auth/profile/admin tests; không có Web chat.
- Backend tests hiện có thể phụ thuộc MySQL test configuration; migration/concurrency test phải dùng schema/database cô lập, không dev data.

## 6. Nguồn đã đối chiếu

AGENTS.md, DESIGN.md, README.md, HELP.md, docs/ai/00–12, docs/Travel_Planner_Function_Specification.md, docs/plan hiện có, docs/promts/entity_generation.md, CODEBASE_GUIDE, POM/properties và các source/tests được liệt kê trên. Tài liệu lịch sử/plan có điểm stale; trước implementation cần cập nhật chính thức sau khi quyết định được duyệt.

