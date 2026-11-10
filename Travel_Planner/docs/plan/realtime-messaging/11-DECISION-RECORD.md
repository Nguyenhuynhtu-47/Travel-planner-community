# 11 — Decision record

Decision record này ghi các quyết định đã được người dùng phê duyệt ở Giai đoạn 2 và bổ sung ở Giai đoạn 3. Nó ghi nhận ý định, không xác nhận code hoặc database đã thay đổi.

## Đã phê duyệt

| ID | Quyết định | Phạm vi / hệ quả |
|---|---|---|
| D-01 | Dự án đang ở giai đoạn Development cho feature này. | Kế hoạch triển khai target Development; chưa kết luận cấu hình production. |
| D-02 | Giữ Hibernate/JPA và ddl-auto=update ở Development. | Schema chat dự kiến được tạo additive qua entity khi app chạy đúng Development profile. |
| D-03 | Cho phép bổ sung bảng mới phục vụ chat/friendship. | Cho phép sáu bảng ở 03; không phải quyền thay schema không liên quan. |
| D-04 | Không dùng Flyway, Liquibase hoặc baseline. | Không thêm dependencies/config/migration framework cho feature này. |
| D-05 | Không đổi chiến lược quản lý DB toàn cục. | Không đổi profile, database, ddl-auto ngoài phạm vi đã chốt. |
| D-06 | Bảo toàn dữ liệu và chức năng hiện có. | Không drop/reset/rename hoặc phá hợp đồng API/features cũ. |
| D-07 | Không sửa hoặc xóa UserHandleBackfillRunner. | Runner hiện tại tiếp tục nguyên trạng; không tạo runner DDL chat tương tự. |
| D-08 | Giai đoạn 2 chỉ cập nhật plan Markdown trong thư mục này. | Không sửa source, dependencies, DB, tests, migration hoặc tài liệu ngoài plan folder. |

## Đã chốt thêm trong Giai đoạn 3

| Chủ đề | Quyết định |
|---|---|---|
| Privacy | FRIENDS_ONLY mặc định; EVERYONE nhắn trực tiếp; NOBODY chặn mọi tin mới. |
| Message request | Không có request inbox trong MVP; người lạ được gửi trực tiếp khi recipient chọn EVERYONE. |
| Request ngược chiều | Không auto-accept; người nhận phải bấm Chấp nhận. |
| Block/unfriend | Giữ lịch sử chat; kiểm tra quyền lại ở mỗi lần gửi. |
| Read state | Có unread count và read receipt cơ bản từ cursor. |
| Thứ tự chat | Sequence_number tăng dần dưới row lock conversation | Thiết kế persistence phải giữ invariant này. |
| Realtime | REST write + STOMP user queue sau commit; REST repair | Simple broker chỉ single instance; durable outbox là scope khác. |
| Mobile package | stomp_dart_client là ứng viên | Cần compatibility spike/version pin trước khi thêm dependency. |
| Message content | Text tối đa 4.000 ký tự; rate/payload/session limits cần cấu hình Development. |

## Các quyết định kỹ thuật bắt buộc khi implementation

1. Chụp schema và xác minh DB target là Development; backup/restore trước lần Hibernate update đầu.
2. Xác minh Hibernate/MySQL hiện tại có thể tạo ràng buộc cần thiết; nếu không, dừng và xin quyết định bổ sung thay vì lén thêm migration framework hoặc startup SQL.
3. Serialize message sequence theo conversation row lock; cấp sequence, insert message và update summary trong cùng transaction. Commit mới phát event.
4. Chạy integration/concurrency test trên database cô lập, không trên dữ liệu duy nhất của người dùng.
5. Không suy rộng các quyết định Development sang production. Nếu cần triển khai production, lập quyết định schema/deployment riêng.

## Không được hiểu là đã chấp thuận

- Không có phê duyệt thay đổi source ngay trong Giai đoạn 2.
- Không có phê duyệt chạy app để Hibernate tự cập nhật database trong lượt này.
- Không có phê duyệt xóa, reset, chuyển đổi hoặc seed database.
- Không có phê duyệt thêm chat vào Web, push notifications, group chat, attachments, E2E encryption hoặc message requests.
- Không có phê duyệt thay đổi Follow hay các chức năng hiện hữu.
