# 09 — Rủi ro và quyết định còn mở

## 1. Xung đột tài liệu và phạm vi

1. Tài liệu trạng thái cũ ghi chat ngoài scope; yêu cầu hiện tại mở rộng scope có giới hạn cho feature chat/friendship. Khi implementation được yêu cầu, đồng bộ docs chính thức tương ứng, không suy rộng sang feature khác.
2. Entity-generation cũ giới hạn 12 bảng. Quyết định Giai đoạn 2 cho phép bổ sung bảng chat trong Development; các quy tắc khác vẫn giữ. Không thêm bảng ngoài scope chat/friendship.
3. Tài liệu community cũ có mô tả Follow chưa triển khai nhưng source hiện đã có PublicUserController/Service/UI. Không viết lại Follow; regression phải xác nhận chức năng này còn nguyên.
4. docs/ai/01-architecture.md có phần mô tả bảo mật cũ; kế hoạch bám source hiện tại đã audit.
5. UserHandleBackfillRunner hiện tồn tại và phải giữ nguyên theo quyết định người dùng. Không dùng nó làm cơ chế schema cho chat.

## 2. Rủi ro kỹ thuật và biện pháp

- **Hibernate update và schema vật lý chưa biết:** trước implementation cần backup/restore, xác nhận profile/DB Development, kiểm tra kiểu FK và schema hiện tại. Hibernate update không phải migration versioned; do đó chỉ cho thay đổi additive, không drop/rename.
- **Constraint/index mapping:** cần xác minh MySQL/Hibernate runtime thực sự tạo unique/index/foreign key yêu cầu. Nếu không tạo được invariant thiết yếu thì dừng, ghi quyết định bổ sung; không âm thầm thêm Flyway/Liquibase, baseline hay startup DDL.
- **Thứ tự gửi đồng thời:** auto-increment ID không đảm bảo thứ tự commit. Cấp sequence_number theo từng conversation dưới row lock; insert, tăng sequence và cập nhật summary cùng transaction; mọi page/delta sort theo sequence.
- **Simple broker:** in-memory, single instance; không durable/clustered. Multi-instance cần broker relay/outbox được duyệt riêng.
- **Commit/publish crash gap:** AFTER_COMMIT có thể mất event nếu process chết sau DB commit. REST sync sửa mất event; outbox là scope riêng.
- **Token/socket:** token hết hạn trong socket sống; server cần từ chối/đóng khi hết hạn và client refresh/reconnect. Không truyền token trên URL.
- **Authorization leakage:** subscription topic hội thoại chung hoặc recipientId do client truyền có thể lộ tin; dùng user queue, REST send và check membership phía server.
- **Duplicate/reconnect:** idempotency key và messageId/clientMessageId dedupe; sequence_number xác định thứ tự.
- **Privacy/abuse:** policy, block/unfriend có thể đổi giữa lúc mở chat; recheck mỗi lần gửi. Rate, payload, session cap và block UX cần chốt.
- **Mobile lifecycle:** OS có thể dừng app; socket không đảm bảo background/terminated notification.
- **Retention/deletion:** chưa có chính sách xóa tài khoản, backup, moderation, export.
- **WebSocket browser security:** same-origin/CORS và browser STOMP cần kiểm thử nếu mở rộng web; Web chat hiện ngoài MVP.

## 3. Quyết định sản phẩm còn mở

Các mục sau vẫn là đề xuất, không được coi là đã duyệt chỉ vì nằm trong plan:

1. Default privacy FRIENDS_ONLY hay lựa chọn khác, áp dụng thế nào với account cũ.
2. EVERYONE gửi thẳng vào inbox hay có message-request inbox.
3. NOBODY có chặn tin từ bạn bè hiện có không.
4. Reverse pending friend request tự accept hay cần người nhận thao tác rõ ràng.
5. Block/unfriend xử lý quan hệ, history và inbox hiển thị thế nào.
6. Read cursor chỉ phục vụ unread hay hiển thị receipt cho peer.
7. Giới hạn text, rate limit, số socket/user, payload và idle timeout.
8. Simple broker single instance có phù hợp nơi chạy Development/demo.
9. Có yêu cầu push notification nền không; push vẫn ngoài MVP hiện tại.
10. Retention, account deletion, moderation và data export.
11. Web chat có release riêng hay sẽ không nằm trong feature.
12. Chọn/pin STOMP Flutter package sau compatibility spike.

## 4. Giới hạn audit và trạng thái

Audit dựa trên source/config/docs tại nhánh develop ngày 2026-11-10. Không kết nối DB, không kiểm tra schema vật lý, không chạy test/build/device pair. Plan đã được cập nhật theo quyết định kiến trúc về Development JPA/Hibernate, nhưng chưa triển khai code, dependency, entity, API, DDL/DML hay cấu hình runtime. Các mục mở cần chốt trước implementation.
