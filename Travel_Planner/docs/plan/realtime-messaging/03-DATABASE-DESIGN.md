# 03 — Thiết kế database đề xuất

## 1. ERD

~~~mermaid
erDiagram
  USERS ||--o{ CONVERSATIONS : member_low
  USERS ||--o{ CONVERSATIONS : member_high
  CONVERSATIONS ||--o{ MESSAGES : stores
  USERS ||--o{ MESSAGES : sends
  CONVERSATIONS ||--o{ CONVERSATION_READ_STATES : cursor
  USERS ||--o{ CONVERSATION_READ_STATES : reads_as
  USERS ||--o| USER_MESSAGING_SETTINGS : configures
  USERS ||--o{ FRIENDSHIPS : low_or_high
  USERS ||--o{ USER_BLOCKS : blocks_or_blocked
  USERS ||--o{ FOLLOWS : existing_one_way_follow
~~~

Follow giữ nguyên quan hệ một chiều hiện có. Chat MVP chỉ 1-1 nên hai thành viên lưu trực tiếp trên conversations; chưa cần bảng participants.

## 2. Quy ước kiểu dữ liệu

Bảng users hiện dùng user_id INT ở entity. Trước code cần xác minh signedness/kiểu thực tế trên Development database và dùng khớp chính xác cho mọi FK user. ID chat có thể BIGINT. Các thời điểm lưu UTC với precision thống nhất; không suy ra timezone từ máy client. Dùng InnoDB/FK.

## 3. Bảng đề xuất

### conversations

| Cột | Kiểu đề xuất | Vai trò |
|---|---|---|
| conversation_id | BIGINT PK auto increment | ID hội thoại |
| user_low_id, user_high_id | INT FK users | cặp thành viên chuẩn hóa |
| last_message_sequence | BIGINT NOT NULL DEFAULT 0 | sequence mới nhất đã cấp |
| last_message_id | BIGINT nullable | tham chiếu message cuối để hydrate summary |
| last_message_at | DATETIME(3) nullable | thời gian activity |
| created_at, updated_at | DATETIME(3) NOT NULL | thời gian UTC |

UNIQUE(user_low_id,user_high_id) bảo đảm một direct conversation cho mỗi cặp. Luôn canonicalize low=min(idA,idB), high=max(...); CHECK(low < high) chỉ là lớp bảo vệ bổ sung nếu runtime MySQL thực thi. Index theo từng thành viên và last activity. Không lưu preview body trùng lặp.

### messages

| Cột | Kiểu đề xuất | Vai trò |
|---|---|---|
| message_id | BIGINT PK auto increment | định danh, dedupe và tham chiếu |
| conversation_id | BIGINT FK conversations | hội thoại |
| sequence_number | BIGINT NOT NULL | thứ tự tăng dần riêng trong chat |
| sender_user_id | INT FK users | luôn lấy từ principal |
| client_message_id | VARCHAR(36) NOT NULL | UUID idempotency do app tạo |
| content | TEXT hoặc VARCHAR(4000) | nội dung đã validate |
| created_at | DATETIME(3) NOT NULL | giờ server sau khi lấy khóa conversation |

UNIQUE(conversation_id,sequence_number) và UNIQUE(sender_user_id,client_message_id). Index history theo (conversation_id,sequence_number), index bổ sung cho các truy vấn sender khi cần. Sequence là thứ tự chuẩn để sắp xếp, phân trang và đồng bộ; message_id chỉ là ID. Không dựa vào thứ tự auto-increment để biểu diễn thứ tự commit: InnoDB có thể cấp ID trước khi transaction commit, nên hai transaction có thể commit khác thứ tự ID.

### conversation_read_states

| Cột | Kiểu đề xuất | Vai trò |
|---|---|---|
| conversation_id | BIGINT FK conversations | hội thoại |
| user_id | INT FK users | người đọc |
| last_read_sequence | BIGINT NOT NULL DEFAULT 0 | sequence cuối đã đọc |
| last_read_at | DATETIME(3) nullable | thời điểm cập nhật |

Composite PK(conversation_id,user_id), tối đa hai row cho mỗi chat. Chỉ thành viên được cập nhật. Cursor phải trong khoảng 0..last_message_sequence và chỉ tiến về trước. Unread count đếm message của peer có sequence_number lớn hơn cursor; truy vấn batch/projection để tránh N+1.

### friendships

Một canonical row mỗi cặp: friendship_id BIGINT PK, user_low_id/user_high_id INT FK, requested_by_user_id INT FK, status PENDING/ACCEPTED/REJECTED, created_at/updated_at. UNIQUE cặp. Khi PENDING người nhận là thành viên còn lại. Index theo từng thành viên + status + updated_at. `requested_by_user_id` phải thuộc cặp. Lịch sử nhiều lần gửi lời mời không nằm trong MVP. Xem transition ở 06.

### user_messaging_settings

user_id INT PK/FK, inbound_policy VARCHAR(20) (EVERYONE/FRIENDS_ONLY/NOBODY), updated_at. Settings chỉ chủ tài khoản đọc/sửa. Default và rollout account cũ hiện là đề xuất nghiệp vụ, chưa được chốt.

### user_blocks

block_id BIGINT PK, blocker_user_id INT FK, blocked_user_id INT FK, created_at. UNIQUE(blocker_user_id,blocked_user_id); không cho tự block; index hỗ trợ kiểm tra cả hai hướng. Chính sách giữ history được mô tả ở 06.

## 4. Tính toàn vẹn và thứ tự gửi đồng thời

Mọi conversation/friendship pair canonicalize ở backend; không nhận member pair do client cung cấp. Unique constraint là bảo vệ cuối cùng, không thay precheck/service logic.

Gửi message phải chạy trong một transaction theo trình tự:

1. Tìm idempotency key trước để retry trả lại row cũ khi đã tồn tại.
2. Khóa row conversation bằng cơ chế tương đương SELECT ... FOR UPDATE; kiểm tra thành viên, trạng thái account, privacy và block trong phạm vi transaction.
3. Sau khi giữ được khóa, cấp sequence_number = last_message_sequence + 1; ghi message và cập nhật sequence, last_message_id, last_message_at trên conversation trong cùng transaction.
4. Commit rồi mới publish realtime event. Khóa được giữ đến commit, vì vậy request tiếp theo cùng conversation chỉ cấp sequence sau commit/rollback request trước. Rollback không để lại sequence gap do cập nhật conversation cũng rollback.
5. Nếu unique idempotency collision từ retry đua, đọc lại message tương ứng và trả kết quả idempotent.

Thứ tự history và UI là sequence_number, không phải created_at hoặc message_id. Thời gian chỉ phục vụ hiển thị. Điều này tạo thứ tự tuyến tính cho mỗi hội thoại dù nhiều thiết bị gửi đồng thời. Không giữ DB lock khi gọi broker/network. Giao dịch friendships cũng cần khóa theo cặp user có thứ tự tăng dần hoặc conditional update/unique-collision reload để tránh deadlock và request trùng.

Mở conversation: check recipient ACTIVE, không tự chat, block và inbound policy; tìm cặp chuẩn hóa; nếu concurrent insert đụng unique thì load lại row chuẩn.

## 5. Đồng bộ Hibernate Development

Đã được chấp thuận cho plan này: dự án đang ở Development, dùng JPA/Hibernate với ddl-auto=update; cho phép thêm bảng feature chat thông qua entity mới. Không tạo Flyway/Liquibase/baseline; không chuyển toàn dự án sang schema manager khác. Đây là plan, chưa chạy Hibernate hay sửa code/config.

Khi implementation, chỉ thêm entity/repository và mapping additive; kiểm tra mapping trước khi khởi động trên database Development có dữ liệu cần giữ. Không đổi hoặc xóa bảng/cột hiện hữu, không thay strategy global, không chạy lệnh reset/drop/recreate. Giữ nguyên UserHandleBackfillRunner; không sửa logic, không nhân rộng thành schema runner chat. Kiểm tra startup log/schema để xác nhận Hibernate chỉ bổ sung các bảng/cột dự kiến và dữ liệu cũ còn nguyên.

Không có đảm bảo Hibernate update tự tạo mọi CHECK/index/database-specific constraint theo thiết kế. Trước code cần xác minh khả năng mapping/runtime MySQL. Nếu thiếu constraint quan trọng, dừng ở thiết kế, ghi rõ constraint thiếu và đề xuất cách bổ sung an toàn cho chính Development; không âm thầm thêm framework migration hoặc SQL startup. Production deployment/schema validation không thuộc giả định Development và cần plan riêng nếu đưa ứng dụng ra ngoài Development.

## 6. An toàn dữ liệu và xác minh

Trước lần chạy đầu tiên sau khi thêm entity: xác định chính xác profile và URL database, xác nhận đây là Development DB dự kiến, tạo backup có thể phục hồi, kiểm tra user ID types/table constraints, và bảo đảm test dùng database cô lập. Không dùng cơ sở dữ liệu chứa dữ liệu duy nhất làm test concurrency/destructive test. Sau khởi động so sánh schema/table/data trước-sau, xác nhận bảng mới và không mất dữ liệu/chức năng cũ. Đây là checklist tương lai; không truy cập database trong Giai đoạn 2.

Giai đoạn 2 không đọc/ghi DB runtime, không chạy DDL/DML, không thêm entity hay config.
