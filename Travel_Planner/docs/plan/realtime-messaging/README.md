# Kế hoạch nhắn tin realtime và kết bạn

**Trạng thái:** Giai đoạn 2 — plan đã cập nhật theo các quyết định được người dùng phê duyệt; chưa triển khai code.  
**Ngày cập nhật:** 2026-11-10  
**Phạm vi tài liệu:** chỉ thư mục docs/plan/realtime-messaging.

## Kết luận

MVP dự kiến gồm chat 1-1 bằng văn bản, danh sách hội thoại, lịch sử phân trang, realtime khi ứng dụng đang kết nối, trạng thái chưa đọc, friendship hai chiều, thiết lập nhận tin và chặn người dùng. Follow hiện tại tiếp tục độc lập. Mobile dùng REST cho thao tác và đồng bộ, Spring WebSocket/STOMP chỉ đẩy sự kiện sau khi dữ liệu đã commit. Web chat, push notification, chat nhóm/tệp đính kèm, typing và online presence nằm ngoài MVP.

Các quyết định đã được xác nhận cho phạm vi lập kế hoạch: đây là dự án Development; giữ Hibernate/JPA với ddl-auto=update trong Development; cho phép bổ sung bảng chat qua entity/JPA; không dùng Flyway, Liquibase hoặc baseline; không đổi cấu hình quản lý schema toàn cục; bảo toàn dữ liệu và chức năng đang có; không sửa/xóa UserHandleBackfillRunner. Đây là quyết định kiến trúc cho lần triển khai feature này, không phải xác nhận đã thay đổi cấu hình hoặc database.

Tổ chức dữ liệu đề xuất dùng sáu bảng mới: conversations, messages, conversation_read_states, friendships, user_messaging_settings, user_blocks. Thứ tự trong từng chat được quản lý bằng sequence tăng dần theo conversation, cấp trong transaction sau khi khóa row conversation; không suy ra thứ tự commit từ auto-increment message_id. Chi tiết ở 03.

## Trạng thái phê duyệt

- **Đã chốt:** scope phát triển chat/friendship; Development dùng Hibernate/JPA và ddl-auto=update; được thêm bảng chat; không thêm Flyway/Liquibase/baseline; giữ nguyên dữ liệu/chức năng hiện có và UserHandleBackfillRunner; chỉ cập nhật plan ở Giai đoạn 2.
- **Đề xuất nghiệp vụ cần duyệt trước implementation:** chính sách nhận tin mặc định FRIENDS_ONLY; hành vi tin nhắn người lạ; auto-accept lời mời ngược; giữ history khi block/unfriend; read cursor; giới hạn nội dung; retry/pagination; thư viện STOMP Flutter.
- **Chưa thực hiện:** không tạo entity, dependency, API, migration/SQL, DDL/DML, thay đổi source, chạy test/build hoặc kết nối database.

## Tài liệu

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

## Ghi chú phạm vi

Tài liệu trạng thái dự án và entity-generation cũ mô tả phạm vi trước khi chat được chấp thuận. Giai đoạn 2 ghi nhận phần mở rộng này chỉ cho feature chat/friendship; không tự ý viết lại tài liệu quy tắc chung trong lượt hiện tại. Khi bắt đầu implementation, đồng bộ tài liệu chính thức trong phạm vi được cho phép và chỉ sửa những điều khoản thật sự xung đột. Không biến điều này thành thay đổi các feature/schema khác.

AGENTS.md yêu cầu cập nhật development log cho thay đổi tài liệu. Yêu cầu Giai đoạn 2 giới hạn chỉnh sửa ở thư mục plan này, nên development log bên ngoài thư mục không được sửa.
