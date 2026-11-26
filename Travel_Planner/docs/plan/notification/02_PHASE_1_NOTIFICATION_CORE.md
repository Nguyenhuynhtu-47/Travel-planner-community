# Phase 1 — Database và Backend Notification Core

**Trạng thái:** Notification Core backend đã triển khai và kiểm thử trên `travel_planner_test` ngày 2026-11-26. C4 Like policy đã được người dùng chốt và triển khai ở Phase 4; production schema provisioning chưa xác minh.

## 1. Mục tiêu
Xây core personal notification: transactional create, bounded paging, read-one/read-all, unread count, event idempotency, grouped likes. Không bao gồm Center UI, event hooks rộng, announcement UI hoặc FCM implementation.

## 2. Phạm vi
Backend model/repository/service/controller/DTO, schema additive được duyệt, tests. Bổ sung shared types/mapper contract. Không tạo user-target endpoint để client tạo notification.

## 3. Những chức năng sẽ thực hiện
Thiết kế/implement `notifications` entity cho social/moderation; canonical type/target enum; create service gọi trong transaction; query own feed/count; mark one/all; Like group theo approved window; page stable; dedup; TTL/retention policy nếu được duyệt.

## 4. Những chức năng không được thay đổi
Messaging unread/request counts; Friendship/Follow/Post/Comment business semantics; audit history; FCM sending; announcement audience/read storage. D1/D2/D3 không được gọi create notification.

## 5. Phân tích trạng thái code hiện tại
Trước Phase 1 chưa có entity/repository/controller/service cho notification. Hiện core đã có các lớp nêu ở phần Implementation update; ID User là Integer còn ID nội dung đích khác nhau theo domain. Test schema xác minh qua MySQL 8.0.44; production schema và lịch sử migration thực tế vẫn CHƯA XÁC MINH. Chưa có lớp business event notification dùng chung.

## 6. Những file/class/component cần đọc
`model/User.java`, `model/PostLike.java`, `model/PostComment.java`, `model/Comment.java`, entity friendship/follow/post/report; quy ước trong `repository`; `dto/response/PageResponse`; exception handler; `SecurityConfig`; tài liệu `db_info`; test persistence/profile MySQL và cấu hình schema hiện hành.

## 7. Những file dự kiến cần tạo/chỉnh sửa
Đã tạo `model/Notification.java`, canonical enums, `NotificationRepository`, `NotificationService`/`NotificationServiceImpl`, `NotificationController`, response DTOs và unit/DB/HTTP/concurrency tests. Schema theo JPA/Hibernate của dự án; không duy trì SQL script riêng.

## 8. Database changes
Implemented `notifications` with recipient/optional actor FKs, recipient-scoped event unique key, feed and unread indexes. `target_id` is a bounded string to support Integer and Long source IDs. `travel_planner_test` was approved by the owner and verified on MySQL 8.0.44. Notification-specific SQL rollout files have since been removed; production schema/backup/rollout remain unverified. No message table/history/outbox-per-message. Like actor table is implemented as JPA mapping for the approved C4 behavior.

## 9. Backend implementation
Service chỉ cho phép caller nội bộ đáng tin cậy tạo record; danh sách dùng cursor/page size đã kiểm tra; unread count chạy aggregate SQL; read-one luôn lọc recipient theo principal. Read-all dùng watermark/snapshot để notification vừa đến đồng thời vẫn chưa đọc. Giữ transaction cho thao tác ghi/đọc; dùng projection hoặc tải actor theo lô để tránh N+1. Ghép announcement và social feed được chốt trong API Phase 2/3.

## 10. Flutter implementation
Không sửa Flutter ở Phase 1. DTO được thiết kế cho Mobile Phase 2; frontend không được tự tạo record notification tùy ý.

## 11. Flutter Web Admin scope
Không áp dụng theo source hiện tại vì chưa tìm thấy ứng dụng Angular. Quản lý announcement dự kiến tích hợp vào Flutter Web ở Phase 3, trừ khi người dùng duyệt stack khác.

## 12. API contract
Implemented: `GET /api/notifications?cursor&size&unreadOnly&type`; `GET /api/notifications/unread-count`; `POST /api/notifications/{id}/read`; `POST /api/notifications/read-all`. Feed uses a bounded keyset cursor `(createdAt,notificationId)`; recipient always comes from the authenticated principal. Detailed response is recorded in document 13.

## 13. Luồng end-to-end
Service nghiệp vụ xác định transition và recipient → core nhận event identity đáng tin cậy → database ghi/khử trùng trong cùng transaction → các API list/read/count chỉ truy vấn dữ liệu của principal. Phase này chưa gửi FCM; nếu transaction rollback thì không còn notification.

## 14. Business rules
Không thông báo cho chính actor; khử trùng theo transition nguồn, không khóa vĩnh viễn theo actor-target vì người dùng có thể comment lại. Type nằm trong allowlist; read không sửa dữ liệu nguồn; unread chỉ tính loại thuộc Center; announcement chỉ cộng khi API feed được ghép; message event bị loại tuyệt đối.

## 15. Validation và error handling
Validate type, target category, bounds, cursor, page size, content lengths. Missing/foreign notification response avoids owner enumeration. Duplicate event is idempotent. Unique conflict must be translated only where expected; unexpected DB failures remain visible in service logs without private body.

## 16. Security và authorization
JWT principal là nguồn xác định recipient duy nhất. Hàm tạo notification nội bộ không mở thành endpoint công khai. Role Admin không mặc nhiên cho phép đọc Center của người khác nếu chưa có chức năng được audit riêng. API của target tiếp tục kiểm tra quyền truy cập.

## 17. Realtime và Push behavior
Phase này chưa có bộ gửi Push. Có thể phát event sau commit để Phase 2 invalidate cache; client refetch count/list. STOMP Messaging không được cập nhật Notification badge.

## 18. Test plan
Verified: MySQL schema/FK/constraints/index and feed SQL; service self suppression, duplicate idempotency, owner-scoped reads, read-all snapshot; concurrent same-key create; HTTP authentication/ownership; cursor/type filters. C4 grouping was added after owner approval (UTC day; unlike removes only unread actor membership, read history immutable) and covered by focused MySQL integration tests. TTL policy, push or message send integration remain outside core.

## 19. Acceptance criteria
All core queries bounded and principal-scoped; unread count is one aggregate query; no N+1; retry does not duplicate; reads synchronize through DB; schema reviewed and additive; Messaging records/badges untouched; tests pass on MySQL not only H2.

## 20. Dependencies
Phase 0 decisions and safe DDL approval. Blocks Phase 2, 3, 4, 6; FCM Phase 5 can share infrastructure but is independent of Center rows.

## 21. Risks and mitigation
Target đa hình không thể có một FK thông thường; cần resolver allowlist và kiểm tra lại quyền tại domain. Cursor ghép hai bảng cần khóa phân trang kết hợp, chốt ở Phase 2. Like theo cửa sổ trượt dễ race; cần key xác định và lock/unique constraint phù hợp. Hibernate update không chứng minh migration production an toàn.

## 22. Completion checklist
- [x] Additive JPA schema tested against the owner-approved `travel_planner_test` MySQL 8.0.44. Production schema provisioning has not been performed.
- [x] Core type/API/cursor contract implemented; cursor is URL-safe Base64 over `(createdAt, notificationId)`.
- [x] Unit, MySQL persistence/query, HTTP authorization/ownership and concurrent idempotency tests pass.
- [x] No FCM, message-notification rows, or changes to Messaging unread.
- [x] Like aggregation semantics approved and implemented: UTC calendar day; unlike before read removes actor and deletes empty group; unlike after read preserves history; re-like joins/creates unread group.
- [ ] Production schema review/backup/rollout verified.

## Implementation update — 2026-11-26

- Added `Notification` with recipient/optional actor FKs, canonical type/target enums, bounded snapshot fields, nullable event key, read timestamp, composite idempotency key and feed/unread indexes.
- Added internal transactional create service. Recipient row locking serializes retries for the same recipient; self-notifications are suppressed. There is no client-facing create route.
- Added principal-scoped feed, unread count, read-one and snapshot read-all endpoints. Feed is bounded to 1–50 rows (default 20), sorted by `(createdAt, notificationId)` descending and supports an optional type/unread filter. Actor is fetched in one query to avoid N+1.
- Removed the notification-specific DDL script during architecture correction. Development/test Hibernate `update` creates and validates the JPA mappings in `travel_planner_test`; production uses `ddl-auto=validate` and requires schema provisioning through the existing database process.
- JPA-backed notification integration tests cover repository/feed/read behavior, authorization, concurrency and announcement policy. Tests that executed feature-specific SQL scripts were removed as part of this corrective pass.
- Grouped Like behavior is implemented after the approved C4 decision; additive actor-membership DDL is validated only in the isolated test DB and remains unapplied to development/production. Retention/TTL policy remains unchanged.
