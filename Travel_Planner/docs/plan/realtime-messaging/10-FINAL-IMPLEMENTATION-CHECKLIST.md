# 10 — Checklist triển khai cuối

Checklist này áp dụng trước khi bắt đầu code và trước khi kết thúc implementation. Các mục chưa được xác minh không được đánh dấu hoàn thành theo suy đoán.

## A. Quyết định được phép

- [x] Phạm vi project là Development cho lần triển khai dự kiến.
- [x] Giữ JPA/Hibernate với ddl-auto=update trong Development.
- [x] Cho phép bổ sung bảng feature chat bằng entity.
- [x] Không dùng Flyway, Liquibase hoặc baseline; không đổi schema manager toàn cục.
- [x] Giữ dữ liệu/chức năng hiện có và giữ nguyên UserHandleBackfillRunner.
- [x] Giai đoạn 2 chỉ chỉnh tài liệu trong docs/plan/realtime-messaging.

## B. Cần chốt trước implementation

- [ ] Xác nhận inbound policy mặc định, EVERYONE/F​​RIENDS_ONLY/NOBODY và quyền người lạ vào inbox.
- [ ] Xác nhận reverse pending friendship được auto-accept hay yêu cầu thao tác accept rõ ràng.
- [ ] Xác nhận block/unfriend xử lý friendship/history và inbox thế nào.
- [ ] Chốt read state/receipt và chính sách hiện trạng thái đã đọc.
- [ ] Chốt message length, rate limit, payload/session limits.
- [ ] Kiểm tra schema MySQL thực tế, kiểu user_id/FK, profile được chạy và DB đúng là Development.
- [ ] Tạo và kiểm tra backup/restore; tuyệt đối không lấy DB duy nhất làm test DB.
- [ ] Xác minh Hibernate mapping tạo unique/index/constraint cần thiết; nếu thiếu thì ghi decision bổ sung trước khi triển khai.
- [ ] Chốt package Flutter STOMP qua spike Android/iOS và version compatibility.

## C. Backend/data

- [ ] Entity mới additive; không rename/drop/alter ngầm dữ liệu/schema cũ.
- [ ] Duy trì ddl-auto=update riêng Development; không thêm Flyway/Liquibase/baseline.
- [ ] UserHandleBackfillRunner giữ nguyên.
- [ ] Conversation pair canonical + unique; concurrent open trả một row.
- [ ] Sequence riêng per conversation cấp dưới row lock và commit cùng message/summary.
- [ ] History và reconnect cursor theo sequence, không dùng auto-increment ID như commit watermark.
- [ ] Sender lấy từ JWT principal; membership/privacy/block/status xác minh server-side.
- [ ] Idempotency unique theo sender + clientMessageId.
- [ ] Read cursor monotonic và thuộc đúng conversation.
- [ ] Queries page/projection không N+1; index theo query thật.
- [ ] Event chỉ phát sau commit, rollback không broadcast.

## D. Realtime/mobile

- [ ] STOMP CONNECT JWT, không token URL; subscription chỉ user queue.
- [ ] Không cho client STOMP MESSAGE/publish trong MVP.
- [ ] Event dedupe bằng ID/key và sequence; REST khôi phục event thất lạc.
- [ ] Một socket/account; logout, 401, token đổi, account switch đóng socket và xóa private state cũ.
- [ ] Retry message dùng cùng clientMessageId.
- [ ] Background không hứa socket delivery; resume đồng bộ REST.
- [ ] 5 bottom tabs giữ nguyên; Community tái sử dụng; Follow không đổi.

## E. Nghiệm thu và an toàn

- [ ] Backend unit/MVC tests pass; MySQL concurrency tests dùng DB cô lập.
- [ ] Kiểm thử A→B→A concurrent send bảo đảm sequence duy nhất/tăng đúng thứ tự commit.
- [ ] Flutter analyze/test và kiểm thử account switch/reconnect pass.
- [ ] Web regression/build pass dù Web chat ngoài MVP.
- [ ] Test quyền guest/member/non-member/blocked/inactive/banned/IDOR.
- [ ] So sánh schema và dữ liệu trước/sau; xác nhận dữ liệu feature cũ giữ nguyên.
- [ ] Không log JWT, CONNECT headers hoặc nội dung tin nhắn.
- [ ] Ghi kết quả kiểm thử thật; không đánh dấu pass khi chưa chạy.
- [ ] Chỉ hoàn tất sau khi các vấn đề mở đã được quyết định và tài liệu thay đổi đồng bộ.


