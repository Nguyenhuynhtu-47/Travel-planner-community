# 07 — Roadmap triển khai tuần tự

**Trạng thái:** Plan cập nhật theo phê duyệt Giai đoạn 2; code chưa bắt đầu. Chỉ plan folder được phép chỉnh trong Giai đoạn 2.

## Phase 1 — Audit và thiết kế

Đối chiếu source, cấu trúc Flutter/Spring, API/security, dữ liệu hiện có, thiết kế nghiệp vụ/schema, test matrix. Không kết nối DB hoặc thay source. Hoàn tất các tài liệu 01–11 và review với người dùng.

## Phase 2 — Chốt hành vi sản phẩm và kiểm tra điều kiện Development

Các mặc định nghiệp vụ đã chốt ở Giai đoạn 3: FRIENDS_ONLY, EVERYONE gửi trực tiếp, không auto-accept request ngược, giữ history khi block/unfriend, unread/read receipt cơ bản và message tối đa 4.000 ký tự. Chỉ còn chốt cấu hình rate/payload/session cụ thể. Kiểm tra cấu hình đang dùng, phiên bản MySQL, schema/user id types, khả năng Hibernate mapping constraint và backup/restore. Không thay đổi schema manager đã chốt: Development JPA/Hibernate ddl-auto=update; không Flyway/Liquibase/baseline; giữ nguyên UserHandleBackfillRunner.

**Exit:** quyết định nghiệp vụ được ghi nhận; DB target đúng là Development; backup khôi phục được; không có xung đột entity/schema cần migration framework.

## Phase 3 — JPA model additive và persistence

Thêm sáu nhóm entity theo 03, repository và query projection. Không đụng entity/chức năng hiện hữu ngoại trừ quan hệ cần thiết đã review. Dùng sequence per conversation được cấp dưới row lock để đảm bảo thứ tự trong gửi đồng thời. Unique pair/idempotency/sequence là invariant. Giữ dev ddl-auto=update; không thêm migration dependency, file migration, baseline hay đổi DDL runner.

Kiểm tra schema trên Development có backup và DB integration test riêng; xác nhận mapping tạo objects cần thiết mà không xóa/đổi dữ liệu hiện hữu. Nếu Hibernate không thể biểu đạt invariant trọng yếu, dừng và cập nhật decision record trước khi chọn giải pháp.

## Phase 4 — Friendship, privacy và block backend

Triển khai state machine, API, contextual profile state và quyền server-side. Không thay Follow route/semantics. Transaction/unique guard cho cặp user, kiểm tra ACTIVE/block/privacy mỗi lần send.

## Phase 5 — REST conversation và messaging backend

Triển khai direct conversation, list, message history keyset theo sequence_number, REST send idempotent, read cursor. Sender lấy từ principal; mọi truy vấn kiểm membership. Lock conversation, cấp sequence, ghi message + summary atomic. Projection/batch tránh N+1.

## Phase 6 — STOMP post-commit

Thêm Spring WebSocket/STOMP dependency tương thích Boot hiện tại; xác thực JWT ở CONNECT interceptor; chỉ user queue subscribe, cấm client publish. Publish sau commit. Test rollback/delivery, reconnect/history repair, event recipient privacy. Simple broker chỉ phục vụ single instance/development; không hứa durability hoặc cluster.

## Phase 7 — Flutter data/session/realtime

Thực hiện REST repository, STOMP adapter, notifiers, event merge/dedupe theo messageId/clientMessageId và sequence_number, optimistic send, idempotent retry, socket một lần/account, teardown khi logout/401/account switch. On resume sync qua REST. Chốt package qua compatibility spike.

## Phase 8 — Mobile UI và tích hợp profile

Dùng Community tab hiện có làm connection hub; giữ nguyên 5 tab. Thêm inbox/chat/friends/requests/settings/block UI và profile CTA. Dùng design system/shared widgets hiện hữu. Không thêm web chat vào MVP. Follow tiếp tục độc lập.

## Phase 9 — Kiểm thử, regression và tài liệu

Chạy backend unit + MySQL integration trên DB cô lập; Flutter analyze/tests; Web regression/build; manual hai tài khoản/thiết bị. Kiểm dữ liệu/schema trước-sau, permissions, query/pagination, reconnect, logs, 5 tabs và các feature cũ. Cập nhật docs kỹ thuật chính thức trong phạm vi implementation được cho phép; không sửa/xóa UserHandleBackfillRunner.

## Thứ tự phụ thuộc và gate

Phase 2 là gate cho hành vi và môi trường. Phase 3 đứng trước API vì sequence/constraint cần kiểm chứng. Friendship và messaging có thể làm backend song song về mặt package nhưng acceptance cần privacy/block trước send. STOMP chỉ sau REST persistence. Flutter state/repository có thể bắt đầu sau khi API contract ổn định; UI nối sau. Không triển khai tất cả một lượt nếu gate dữ liệu chưa đạt.
