# Kế hoạch và triển khai nhắn tin realtime, kết bạn

**Trạng thái:** Đã có source implementation Giai đoạn 3; phần xác minh MySQL, Spring integration và kiểm thử hai thiết bị còn chờ.
**Ngày cập nhật:** 2026-11-10
**Branch:** `feature/realtime-messaging`

## Phạm vi

MVP chat 1-1 bằng văn bản, danh sách hội thoại/lịch sử phân trang, unread/read cursor, friendship, policy nhận tin và block. REST lưu/gửi; STOMP chỉ phát sự kiện sau commit. Giữ Follow độc lập. Chat Web, push notification khi app đóng, nhóm, file, typing và online presence nằm ngoài phạm vi.

## Quyết định

- Development tiếp tục dùng JPA/Hibernate với `ddl-auto=update`; không Flyway/Liquibase hoặc schema framework mới.
- Không xóa/reset dữ liệu cũ; không sửa UserHandleBackfillRunner hoặc Follow.
- `FRIENDS_ONLY` mặc định; `EVERYONE` cho người lạ mở chat; `NOBODY` chặn tin mới kể cả bạn bè.
- Request ngược chiều không tự accept; block/unfriend giữ lịch sử; backend kiểm tra lại privacy mỗi lần gửi.
- Tin nhắn tối đa 4.000 ký tự. Các giới hạn Development: 30 tin/phút/user, 5 WebSocket sessions/user, frame 65.536 bytes, send buffer 524.288 bytes, send time limit 15.000 ms.

## Báo cáo và checklist

- [Báo cáo triển khai Giai đoạn 3](IMPLEMENTATION-REPORT.md)
- [Checklist triển khai cuối](10-FINAL-IMPLEMENTATION-CHECKLIST.md)
- Checklist chỉ đánh dấu những gì đã được xác minh. Database target/backup, schema thật, MySQL concurrency, WebSocket integration và manual test hai thiết bị hiện vẫn chưa xác minh.

## Tài liệu kế hoạch

1. [01 — Audit hiện trạng](01-CURRENT-SYSTEM-AUDIT.md)
2. [02 — Yêu cầu và phạm vi](02-REQUIREMENTS-AND-SCOPE.md)
3. [03 — Thiết kế database](03-DATABASE-DESIGN.md)
4. [04 — Backend API và realtime](04-BACKEND-API-AND-REALTIME.md)
5. [05 — Mobile UI và kiến trúc](05-MOBILE-UI-AND-ARCHITECTURE.md)
6. [06 — Friendship và privacy](06-FRIENDSHIP-AND-PRIVACY.md)
7. [07 — Roadmap](07-IMPLEMENTATION-ROADMAP.md)
8. [08 — Kiểm thử và hồi quy](08-TESTING-AND-REGRESSION.md)
9. [09 — Rủi ro và quyết định còn mở](09-RISKS-OPEN-QUESTIONS.md)
10. [10 — Checklist triển khai cuối](10-FINAL-IMPLEMENTATION-CHECKLIST.md)
11. [11 — Decision record](11-DECISION-RECORD.md)

Giai đoạn 2 chỉ cập nhật plan; Giai đoạn 3 đã triển khai source theo các quyết định trên. Không khởi chạy ứng dụng để Hibernate thay đổi MySQL trước khi xác nhận đúng Development DB và có backup kiểm thử phục hồi được.
