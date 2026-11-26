# 09 — Rủi ro và câu hỏi còn mở

**Cập nhật:** 2026-11-17.

## 1. Rủi ro đã xác minh trong source trước implementation

- Chat UI khởi tạo disconnected mà không lấy `currentStatus`: banner có thể stale dù client socket connected.
- Public profile mở chat với client WebSocket mới, nhưng client không được dispose sau route pop; backend cap 5 session/user, có thể gây các CONNECT sau bị từ chối.
- Community badge chỉ được nạp theo load/refresh; không nghe event toàn cục nên stale.
- `friendRequestsCount` tồn tại trong notifier nhưng chưa có nguồn callsite/badge.
- `NotificationsScreen` vẫn là empty state. Backend hiện có Notification Core riêng, nhưng Messaging D1–D3 vẫn không ghi notification history và chỉ dùng cơ chế push-only theo plan.
- STOMP simple broker volatile và event delivery post-commit không retry; lịch sử REST là recovery.

Các mục lifecycle stale banner, tạo socket riêng từ profile và thiếu badge/request inbox đã được xử lý ở source. Runtime và device vẫn chưa xác minh.

## 2. Giả thuyết runtime chưa được xác minh

Sai API_BASE_URL/host, localhost trên phone, emulator và phone vào backend khác nhau; backend bind/firewall/VPN/Wi-Fi; JWT expiry/disabled; Origin mismatch; socket subscribe failure; server restart; session cap; mạng di động ngủ nền. Cần runtime logs hai thiết bị và cùng host để phân định. Không kết luận root cause từ banner UI.

## 3. Câu hỏi product/architecture còn mở

1. Incoming reverse friendship request có accept tự động không? Plan hiện hữu nói không.
2. Stranger Inbox có cần report/abuse flow ngoài block hiện có không?
3. Có cần unread conversation count riêng trên UI hay chỉ unread message total?
4. App cần chat khi backend chạy nhiều instance hoặc delivery bền vững không? Nếu có, broker/outbox là scope vận hành đáng kể.
5. DB test/target version/schema/backup/restore là gì? Cần xác nhận trước khi chạy context hoặc app.
6. Search name có cần match phần giữa mọi từ hay prefix/token-prefix đáp ứng? Ưu tiên prefix/indexed, cần duyệt theo yêu cầu thực tế.
7. Có chấp thuận `full_name_search` normalized column/index nếu MySQL query plan chứng minh cần không? Chưa có collation/EXPLAIN evidence.
8. “Username” trong UI là public `@handle` hay login username? Plan giữ @handle và không expose credential username/email.
9. Duyệt Profile > Cài đặt làm canonical entry privacy, giữ Community settings shortcut làm deep link hay bỏ shortcut?

## 4. Rủi ro dữ liệu và vận hành

Hibernate update có thể làm thay đổi schema theo mapping; không dùng như migration review cho production. User FK là Integer, messaging IDs là BIGINT; cần đối chiếu exact type/signedness. Pair canonical constraints và concurrent inserts phụ thuộc MySQL behavior. Simple broker không scale multi-instance. Không có outbox, nên event có thể mất sau khi DB commit. Logs phải tránh token/message PII.

## 5. Mitigation/owner

Product decisions: người sở hữu yêu cầu. DB evidence/migration: backend + DB operator. Lifecycle/UI: Flutter owner. Two-device environment/logs: test owner. Mỗi câu hỏi cần được ghi quyết định vào 11 trước khi implementation phụ thuộc vào nó.

## Addendum — Rủi ro revision 2
- Không xóa nghiệp vụ Stranger Inbox khi bỏ shortcut header; entry Inbox và count/badge phải còn.
- Explore có hai search domains: itinerary search trong body và user search trên AppBar. Entry point mới không được hijack query/filter hiện tại.
- `canMessage` hiện không phân biệt start-new và continue-existing. Nếu không additive contract, profile CTA có thể mất đối với accepted thread sau privacy change.
- User search endpoint hiện có nhưng chỉ prefix; tiếng Việt có dấu/không dấu chưa được test trên schema target. Full-name substring không index-backed có thể scan nhiều user.
- Search result yêu cầu relation/conversation flags; per-row query gây N+1 nếu không batch.
- Privacy screen/API/storage tồn tại; chỉ navigation cần hoàn thiện. Tạo thêm settings storage sẽ tạo nguồn state cạnh tranh.
- Pending request khác unread message; gộp badge gây trạng thái sai. Chi tiết revision 2 ở plan 12.
