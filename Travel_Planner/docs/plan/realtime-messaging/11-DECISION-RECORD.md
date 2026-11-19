# 11 — Decision Record

**Cập nhật:** 2026-11-18. Giữ các quyết định lịch sử; D-23 là semantics hiện hành cho tin nhắn người lạ.

## D-22 — Mặc định nhận tin và đồng bộ trạng thái block
**Trạng thái:** Được yêu cầu và triển khai trong source ngày 2026-11-17.

Người dùng mới hoặc tài khoản chưa có row `user_messaging_settings` mặc định `EVERYONE`. Không ghi đè policy đã lưu; UI hiện chỉ cho chọn `EVERYONE`/`FRIENDS_ONLY`. `NOBODY` chỉ còn là giá trị legacy có thể đọc ở backend. Hồ sơ có lối vào trực tiếp tới quyền riêng tư tin nhắn. Chat tải lại block state khi mở/resume và đổi menu thành “Bỏ chặn người dùng” nếu peer đang bị block.

## D-23 — Stranger messaging semantics (revision theo yêu cầu 2026-11-18)
**Trạng thái:** Được người dùng xác nhận; thay thế các phần D-16 về chỉ được gửi một tin, yêu cầu recipient bấm Accept trước khi chat thường, và chặn hoàn toàn khi chọn FRIENDS_ONLY.

- Setting ban đầu là `EVERYONE`. Người lạ được gửi nhiều tin; chúng hiện trong Stranger Inbox. Khi người nhận trả lời, conversation tự chuyển sang inbox thường và hai bên chat tiếp.
- `FRIENDS_ONLY` không chặn sender gửi. Tin từ người chưa kết bạn được lưu để sender xem trong chính thread của họ, đánh dấu sender-only và không xuất hiện cho recipient trong REST, WebSocket, unread count, inbox hay preview. Sender thấy thông báo rằng người kia không nhận tin người lạ.
- Kết bạn sau đó không mở lại các tin sender-only. Conversation được dùng tiếp; chỉ tin mới gửi sau khi đã là bạn được recipient nhìn thấy, và thông báo giới hạn biến mất.
- UI bỏ lựa chọn `NOBODY`. Backend giữ khả năng đọc giá trị legacy để không làm hỏng row cũ và áp dụng semantics FRIENDS_ONLY cho row đó; policy được chọn từ UI chỉ còn `EVERYONE`/`FRIENDS_ONLY`.
- Tin sender-only lưu bằng cột nullable tương thích với message legacy; null được hiểu là recipient-visible. Cần dùng JPA schema-update hiện có và không xóa/reset dữ liệu.
- HTTP 500 ở settings update do tạo entity `@MapsId` với ID tự gán khiến Spring Data gọi merge và Hibernate báo `null identifier`; constructor không gán ID để repository dùng persist và MapsId sinh ID từ User.

## D-12 — Phân biệt hiện trạng với xác minh runtime

**Trạng thái:** Đã quyết định cho tài liệu audit.

Source/config/API contract chứng minh implementation có trong code; không chứng minh runtime hoạt động trên thiết bị hoặc bảng tồn tại trong MySQL thật. Báo cáo triển khai ngày 10/11 là historical evidence, không được trình bày như test mới.

## D-13 — REST là nguồn bền vững, STOMP là event

**Trạng thái:** Đã quyết định cho MVP.

REST lưu/gửi/lịch sử/read cursor; STOMP phát sau commit. Khi reconnect hoặc event thiếu, client refetch REST. Simple broker hiện tại không có durability/outbox và chỉ chạy trong process; yêu cầu scale/reliability cao hơn cần ADR riêng.

## D-14 — Community navigation

**Trạng thái:** Đã quyết định.

Giữ Community feed-first và tab bar 5 mục; mở rộng shortcuts/sections hiện có. Không tạo bottom tab thứ sáu hoặc community hub trùng lặp. Notifications không được giả là có dữ liệu khi backend còn placeholder.

## D-15 — Badge source

**Trạng thái:** Đã duyệt và triển khai source.

REST trả authoritative unread message total, incoming friend request count và pending stranger request count. Chưa cần unread conversation count riêng. STOMP chỉ invalidate/refetch. Không trộn đơn vị badge, không increment đồng thời từ event và REST.

## D-16 — Message request / privacy semantics (lịch sử, được D-23 thay thế)

**Trạng thái:** Đã duyệt theo xác nhận của người dùng ngày 2026-11-17; source đã triển khai.

EVERYONE tạo stranger request chờ recipient accept; FRIENDS_ONLY chỉ cho friend mở mới; NOBODY chặn mở mới. Accepted thread tiếp tục sau khi đổi policy/unfriend; block và inactive account luôn chặn. Pending sender chỉ được gửi một tin mở đầu. Declined request được giữ lại, có thể gửi lại sau 1 ngày; không xóa lịch sử. Block/inactive vẫn chặn.

## D-17 — Database approach

**Trạng thái:** Đã quyết định giữ nguyên nguyên tắc hiện hành.

Tiếp tục JPA/Hibernate theo cấu trúc dự án, không thêm Flyway/Liquibase chỉ vì feature này. Không reset dữ liệu. Schema change chỉ sau khi xác minh đúng disposable/target DB, backup+restore và review DDL. `ddl-auto=update` không thay thế production migration process.

## D-18 — Notification history

**Trạng thái:** Đã duyệt: không tạo notification history trong scope này.

Không thêm notification table chỉ để badge. Nếu cần lịch sử bền vững, thiết kế riêng type/reference/read state, retention, idempotency, privacy, paging và API trước khi mở scope.

## D-19 — Realtime lifecycle

**Trạng thái:** Quyết định đã triển khai ở source, chưa xác minh runtime.

UI phải nhận snapshot trạng thái hiện tại và transitions; socket client có ownership/dispose rõ ràng, dọn khi logout/account switch/token expiry. Cần xác minh bằng tests và runtime, chưa khẳng định lỗi mạng thực tế đã được giải quyết.

## D-20 — Community navigation và friend discovery baseline
**Trạng thái:** Navigation/inbox/search baseline đã triển khai theo source ngày 2026-11-17; không bao gồm revision 2.

Giữ feed-first và năm bottom destinations; có routes riêng inbox, Stranger Inbox, friends/requests, user search. Search trả fullName/public `handle`, không lộ login username/email. Friendship discovery độc lập messaging privacy; server revalidates status/block/relation. Pending request và unread messages là metrics khác nhau; REST snapshot authoritative, STOMP chỉ invalidate. Icon vuông khác với shortcut Stranger Inbox chưa được nhận diện; không xóa trước screenshot.

## D-21 — Community/Explore/Profile/Privacy/Search revision 2 (lịch sử plan)
**Trạng thái:** Proposal cập nhật trong plan ngày 2026-11-17; chờ người dùng review. Không phải cho phép implementation.

Community bỏ shortcut Stranger Inbox trên header nhưng giữ access từ Messaging Inbox; Explore đặt user search cạnh Notifications và giữ itinerary search; Profile settings là canonical path đến existing messaging privacy screen. Public profile tách quyền bắt đầu mới khỏi quyền tiếp tục accepted thread cũ; giữ D-16 (EVERYONE tạo pending opener, FRIENDS_ONLY cần friend, NOBODY chặn new thread, accepted thread tiếp tục sau privacy change/unfriend, block thắng). Search user độc lập search conversation; public username nghĩa là @handle, không login username/email. Ưu tiên Vietnamese-normalized prefix và chỉ thêm DB column/index nếu MySQL collation/query plan chứng minh cần. Mọi đề xuất này plan-only đến khi được review/duyệt.

## D-24 — Xóa hội thoại riêng và đánh giá lại privacy sau khi hủy kết bạn (đã bị D-25 thay thế)
**Trạng thái:** Quyết định lịch sử ngày 2026-11-18; không còn là hành vi mong muốn.

D-24 trước đây cho phép ẩn/xóa conversation riêng và re-evaluate privacy sau unfriend. D-25 thay thế: không cung cấp xóa/ẩn; accepted Conversation giữ trạng thái độc lập với friendship/privacy.

## D-25 — Accept toàn Conversation, read cursor khi chấp nhận và quyền truy cập khi block
**Trạng thái:** Được người dùng yêu cầu ngày 2026-11-18; là quyết định hiện hành và thay thế mọi phần mâu thuẫn của D-16/D-23/D-24.

- Accept là trạng thái của canonical Conversation, chỉ recipient chủ động accept request; mở detail hoặc gọi send không accept ngầm. ACCEPTED không quay về PENDING/Stranger Inbox khi unfriend hoặc đổi privacy; chỉ block/account inactive chặn tiếp tục.
- Mở pending detail không advance read cursor. Accept đặt ACCEPTED và cập nhật read cursor đến tin pending cuối của requester trong cùng transaction; lỗi cập nhật cursor rollback việc accept. Phát acceptance/read events sau commit.
- Decline giữ tin/lịch sử ở sender, làm các tin thuộc vòng request recipient-invisible và không phát cho recipient. Cooldown gửi lại 1 ngày; canonical conversation được reuse, tin mới có visibility theo policy hiện thời.
- Privacy Mọi người/Bạn bè chỉ áp dụng cho conversation chưa accepted. `FRIENDS_ONLY` sender-only history không bị lộ khi người dùng kết bạn; ACCEPTED thread tiếp tục sau unfriend.
- Block là directed storage nhưng enforcement đối xứng cho cặp: profile/search, social content, itinerary, conversation/history/send và realtime bị ẩn/chặn khi có block. Không xóa lịch sử hoặc tự đổi friendship/conversation status; unblock chỉ gỡ block.
- Inbox/Stranger Inbox row menu chỉ có xem profile và block. Không xóa/ẩn conversation; remove `DELETE /api/conversations/{id}` và code/schema mapping dùng riêng cho hidden state. Nếu cột đã tồn tại trong DB, để nguyên unused, không drop tự động.
- Không thêm bảng. Backend là authorization authority; list filters phải áp dụng trước pagination. REST và WebSocket phải cùng kiểm tra pair block.
