# 03 — Thiết kế dữ liệu

**Cập nhật:** 2026-11-18. Mô tả JPA mappings trong source; không phải introspection schema MySQL đang chạy.

## 1. Quy tắc an toàn

Source hiện dùng Hibernate `ddl-auto=update` ở cấu hình development/local và `validate` ở production; không thấy Flyway/Liquibase. Không đổi schema framework, không drop/reset bảng, không chạy app trên DB người dùng để “xem Hibernate tạo gì”. Trước migration cần xác định host/database/schema, backup có kiểm tra restore, kiểm tra `SHOW CREATE TABLE`/indexes và chạy thử trên disposable MySQL tương thích. Entity mapping không chứng minh bảng vật lý đã tồn tại hoặc cùng kiểu/collation/index.

## 2. Mapping hiện có

| Nhóm | Khóa/ràng buộc chính | Chỉ mục/ghi chú |
|---|---|---|
| `conversations` | BIGINT id; hai participant FK tới User Integer ID; unique canonical user pair | cặp unique; participant + activity/list ordering; last message sequence/id/time; timestamps |
| `messages` | BIGINT id; FK conversation/sender; sequence; client message ID; content TEXT; created time | unique (conversation, sequence), unique (sender, client_message_id), lookup conversation+sequence và sender+created |
| `conversation_read_states` | composite key (conversation,user); monotonic read cursor | index user+conversation; cursor chỉ tiến lên sau thao tác đọc hợp lệ hoặc accept request |
| `friendships` | canonical low/high user pair, requester, status/timestamps | unique pair; indexes low/high/requester; PENDING/ACCEPTED/REJECTED |
| `user_messaging_settings` | user id làm PK/FK; policy | policy + updated time; default ở service nếu chưa có row là EVERYONE |
| `user_blocks` | directed blocker/blocked pair | unique directed pair, reverse lookup; block thao tác hiện tại xóa friendship nhưng giữ chat history |

Kiểu số ID của user hiện là Integer; FK trong MySQL phải khớp kiểu signedness và engine/collation thực tế. Xác minh JPA column names, nullable, cascade, delete policy, precision/length và index names trực tiếp từ mapping + DB trước khi viết DDL.

## 3. Bổ sung cho Stranger Inbox — mapping đã triển khai trong source

Không tạo bảng notification hoặc bảng message request riêng. `Conversation` có các nullable fields `conversation_status`, `requester_user_id`, `request_recipient_user_id`, `request_created_at`, `request_declined_at`; enum là `PENDING`, `ACCEPTED`, `DECLINED`. Bản ghi cũ có status null được hiểu là `ACCEPTED`. Có index recipient/status/updatedAt cho inbox request. Đây chỉ là mapping trong source; chưa xác nhận DDL/foreign keys/index thực tế trên MySQL.

Bất biến D-25: pending request chỉ người nhận mới được accept/decline; người gửi ở policy EVERYONE có thể gửi nhiều tin trước khi recipient accept tường minh; mở detail không tăng read cursor, accept cập nhật status và cursor nguyên tử. Decline giữ lịch sử sender-side nhưng recipient-invisible tin thuộc vòng request cũ; retry sau 1 ngày dùng canonical conversation. Block chặn gửi/nhận và ẩn request; tài khoản inactive không thể tiếp tục chat. Policy chỉ chặn mở chat mới; accepted chat tiếp tục sau đổi policy/unfriend. Không thêm bảng notification.

Một conversation canonical cho mỗi cặp user được tái sử dụng khi gửi lại sau cooldown; nội dung cũ được giữ, `request_created_at` đánh dấu vòng request mới. Unit test kiểm tra cooldown và legacy status, nhưng chưa kiểm chứng concurrent retry hoặc truy vấn trên MySQL.

## 4. Unread, friend badge, notifications

Unread message total hiện có query/API và chỉ tính conversation accepted; pending requests có badge count riêng qua `GET /api/conversations/message-requests/count`. Incoming friend count được lấy từ endpoint friend requests phân trang (`totalElements`); UI refetch khi app resume/events. Chưa thêm unread conversation count riêng.

Không có Notification entity/API trong source; Notifications screen là placeholder. Không thêm bảng notification như phụ phẩm của badge. Nếu cần notification history bền vững cho friend/message-request events, thiết kế riêng actor/recipient/type/reference/readAt/createdAt, retention, idempotency, privacy, pagination và indexes; đây là scope/decision mở.

## 5. Migration/verification checklist

1. Capture schema thật trên đúng disposable MySQL version, compare từng column/FK/unique/index với entities.
2. Xác định dữ liệu legacy, orphan rows và pair duplicates trước backfill.
3. Viết thay đổi additive với null/default tương thích và transaction/rollback strategy phù hợp MySQL.
4. Test concurrent open/request, duplicate client retry, accept-vs-block, decline-vs-resend, read cursor và unread queries.
5. Chạy migration thử trên bản copy, xác minh row count và constraints trước/ sau; có backup/restore evidence.
6. Production profile phải validate, không dựa vào auto-update để thay thế migration đã review.

Spring context đã chạy trên MySQL 8.0.44 với test schema; Hibernate `ddl-auto=update` đã tạo/cập nhật JPA mapping và repositories khởi tạo thành công. Chưa có backup/restore evidence, reviewed DDL/query plan, hoặc API-level migration test. Không chạy backend với DB development/người dùng để xác nhận.

## 6. Revision 2 — Public user search và quyền tiếp tục conversation

- Không cần bảng mới cho user discovery, search pagination, friendship actions hoặc can-start/can-continue context. Reuse `users`, `friendships`, `user_blocks`, `user_messaging_settings`, `conversations`.
- Search hiện có `UserRepository.searchActiveUsers` dùng prefix theo `handle`/`fullName`. `handle` unique có index; fullName normalized/indexed field không tồn tại trong Entity hiện tại. Không khẳng định dấu tiếng Việt được xử lý chỉ từ `lower()`.
- Nếu query plan chứng minh prefix full-name chưa đáp ứng, đề xuất thêm `full_name_search` nullable-first/indexed field chứa Unicode-normalized lowercase/không dấu value; cập nhật khi create/profile rename và backfill hiện tại. Cần migration additive và rollback plan. Chỉ dùng sau khi `EXPLAIN` và test collation/MySQL xác nhận lợi ích.
- Partial substring match giữa từ bằng `LIKE '%q%'` sẽ khó dùng B-tree và có thể scan toàn bảng. Ưu tiên normalized prefix; nếu yêu cầu substring thật sự, đánh giá full-text ngram index riêng trước khi đưa vào schema. Không tải users vào Flutter.
- Cần batch query từ `conversations` để profile/search xác định accepted thread tồn tại và có thể tiếp tục, tách khỏi permission tạo mới. Không cần cột mới: status null/ACCEPTED đã có nghĩa canonical accepted; block/account status kiểm tra từ bảng hiện hữu.

## 7. Revision 3 — Ẩn hội thoại theo participant (đã bị D-25 thay thế)

- Reuse `conversation_read_states` (đã có khóa ghép conversation/user), thêm `hidden_at` nullable; không thêm bảng hoặc xóa Conversation/Message.
- Inbox, request list và unread counts loại bỏ hội thoại có `hidden_at` của viewer. Xóa khỏi list không đồng nghĩa xóa lịch sử.
- Tin mới chỉ xóa `hidden_at` cho sender và recipient nếu message recipient-visible. Tin FRIENDS_ONLY sender-only không làm hội thoại xuất hiện ở phía recipient.
- Mapping JPA là additive theo cơ chế schema local hiện hành. Production cần DDL additive đã review; schema vật lý chưa được xác minh.
- **D-25:** không còn dùng `hidden_at`, `DELETE /api/conversations/{id}` hoặc thao tác xóa/ẩn hội thoại. JPA mapping/query/API sẽ được gỡ; nếu cột `hidden_at` đã được Hibernate thêm vào DB local/test thì để nguyên chưa sử dụng để tránh DDL phá hủy dữ liệu. Không cần migration/drop.
- `UserMessagingSettings`/`user_messaging_settings` là persistence hiện có. Không thêm settings table. Physical schema/collation/index chưa được introspect trong lần plan revision này.
