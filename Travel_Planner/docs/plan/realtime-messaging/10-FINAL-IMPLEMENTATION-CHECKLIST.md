# 10 — Checklist triển khai cuối

**Trạng thái:** Cập nhật 2026-11-17 sau triển khai source. Chỉ đánh dấu những mục đã có bằng chứng kiểm tra trong phiên.

## A. Yêu cầu và quyết định
- [x] Chốt semantics FRIENDS_ONLY/EVERYONE/NOBODY cho chat mới và accepted chat (D-16).
- [x] Chốt cap tin đầu, decline/resend/cooldown, unfriend và block; cooldown gửi lại 1 ngày.
- [x] Chốt chỉ dùng unread message total và badge request riêng; không thêm notification history.
- [x] Cập nhật Decision Record trước implementation.

## B. Database/API
- [ ] Xác nhận đúng MySQL host/schema/version, backup và restore thử thành công.
- [ ] Introspect schema thật; đối chiếu Entity, FK, type/signedness, unique/index.
- [x] Review/additive source mapping/API cho pending message request và legacy accepted behavior.
- [ ] Test query/page bounds, idempotency, concurrency, privacy/block/account status qua API trên MySQL; service unit subset và repository context đã chạy.
- [ ] Chạy integration trên disposable MySQL; ghi DDL/query plan/evidence (context đã cập nhật test schema, chưa review DDL/query plan).
- [ ] Không reset/xóa dữ liệu; production schema validation/rollback rõ.

## C. Realtime/backend
- [ ] Connect bearer, expiry, Origin, destination allowlist và cap session được test.
- [ ] Event chỉ phát sau commit; lỗi event không làm mất message đã lưu.
- [ ] Quyết định simple broker single instance hay reliability/multi-instance.
- [ ] Logs/metrics hữu ích, không chứa JWT/message nội dung.

## D. Flutter
- [x] State snapshot + event subscription lấy trạng thái hiện tại trước khi nghe tiếp.
- [x] Client shared app-level; logout/account switch dọn kết nối qua owner.
- [ ] Avatar/fallback, timestamps, bubble direction, send/read status.
- [x] Friend/stranger/unread badges lấy REST, phân biệt các đơn vị, refetch khi resume/event.
- [ ] Community vẫn 5 tab; tuân design system/accessibility; request actions rõ.
- [ ] Widget/unit tests, formatter/analyzer tương ứng pass.

## E. Xác minh runtime
- [ ] Emulator + phone trỏ cùng backend; `/api/health` cùng deployment.
- [ ] Hai chiều send, event, REST recovery sau offline, reconnect/resubscribe.
- [ ] Token expiry, app background, profile chat open/pop lặp, session cleanup.
- [ ] Privacy/friend/message request flows trên hai user/device.
- [ ] Báo cáo có command, version, thiết bị và kết quả thật.

## F. Trạng thái hiện tại

- Previous backend messaging unit/context checks passed. Latest recorded full suite: 499 tests, 0 assertion failures, 175 setup/cleanup errors concentrated in stale test-schema FK cleanup (`media_assets.uploaded_by`). This is separate from the targeted passing unit suites; see IMPLEMENTATION-REPORT.
- Flutter feature tests đã chạy trong full suite thành công, nhưng full suite có 427 passed và 26 failed ở các itinerary/activity/rating widgets.
- `flutter analyze` báo informational lints, gồm style lints trên các file Flutter đã sửa; analyzer chưa xanh.
- ADB nhận một Android device và emulator; chưa chạy app/WebSocket runtime hoặc hai tài khoản.

## G. Revision 2 — Explore/Profile/Privacy/Search — PLAN ONLY; SOURCE CHƯA IMPLEMENT
- [x] Baseline inbox/friends/stranger routes, user search API/screen và separate badges đã có source theo plan 12 §8.
- [x] Cập nhật proposal navigation/API/privacy/search và acceptance trong plan 12 §9 cùng tài liệu liên quan; chưa được user review/approve.
- [ ] Bỏ shortcut Stranger Inbox trên Community header và giữ entry bên trong Messaging Inbox.
- [ ] Chuyển user-search entry sang Explore AppBar cạnh Notifications; không ảnh hưởng itinerary search.
- [ ] Thêm Profile > Settings > Messaging Privacy route dùng lại screen/API/storage hiện tại.
- [ ] Thêm additive start-new/continue-existing flags cho public profile/search; giữ D-16 và backend enforcement.
- [ ] Chốt normalized Vietnamese prefix strategy/index sau MySQL collation, EXPLAIN/benchmark; không tải user directory về mobile.
- [ ] Giữ phân biệt Explore user discovery và Inbox conversation-only filter.
- [ ] Hoàn thành API/widget/regression tests và two-device acceptance trước đánh dấu complete.
- [ ] Screenshot icon vuông vẫn cần để xác định control cũ nếu yêu cầu đó còn hiệu lực.

## H. Chat avatar và layout — Flutter implementation done; manual pending
- [x] Có avatar đúng sender ở cả own (phải) và peer (trái); own lấy profile hiện tại, peer dùng sender avatar rồi peer profile fallback.
- [x] Placeholder/loading/error fallback ổn định, hình tròn và kích thước cố định.
- [x] Tin liên tiếp nhóm theo sender/time; avatar ở cuối nhóm; khoảng cách nội bộ nhỏ hơn giữa hai nhóm.
- [x] Widget tests cho avatar hai phía, peer fallback, grouping, cập nhật profile avatar và màn hình hẹp đã pass.
- [ ] Manual emulator + điện thoại cho đủ matrix tại plan 08; xác minh REST/WebSocket và pagination trên app thực tế.

## I. Revision 3 — Community navigation, block, Explore search, timestamps (2026-11-17)

- [x] Bỏ shortcut riêng Stranger Inbox trên Community feed; giữ screen/API và đường vào/badge tại Messaging Inbox.
- [x] Đưa User Search lên Explore cạnh Notifications; itinerary search giữ nguyên.
- [x] Chat Detail có avatar peer, menu profile/block, xác nhận block, gọi API sẵn có, giữ history và khóa composer sau khi block thành công.
- [x] Ngăn phát ChatEvent cho cặp user đã block tại thời điểm listener xử lý.
- [x] Timestamp chung `HH:mm dd-MM-yyyy`, Asia/Ho_Chi_Minh cho chat/inbox/stranger/legacy community, có phân biệt LocalDateTime và timestamp có offset.
- [x] Backend service tests 16/16 plus MySQL unaccented-prefix test and Spring/JPA context; Flutter profile/messaging/community tests 37/37; analyzer 14 files without errors/warnings (13 info-only style lints).
- [x] Không thêm database schema/endpoint; dùng persistence/endpoints hiện có và chỉ thêm response field tương thích ngược.
- [ ] Manual hai tài khoản, reconnect/WebSocket và đổi avatar trên emulator + điện thoại.
- [x] Test trên MySQL 8.0.44 xác nhận tìm prefix không dấu `nguyen` khớp tên `Nguyễn Huệ` theo collation hiện tại.
- [ ] Tìm substring bắt đầu giữa tên chưa hỗ trợ; cần đánh giá EXPLAIN/volume trước khi đổi prefix query.

## J. Profile settings và quyền tiếp tục chat (2026-11-17)

- [x] Profile có entry tới settings quyền riêng tư tin nhắn; dùng lại API và database hiện tại.
- [x] API profile/search tách can-start (`canMessage`) với continue accepted (`canContinueConversation`); batch query accepted peers và recheck account/block.
- [x] Backend test D-16 mới và Flutter profile/messaging/community: 16 backend tests, 37 Flutter tests đều pass.
- [x] Prefix search bỏ dấu đã được xác minh trên MySQL test schema; không cần migration.
- [ ] Substring search ở giữa tên vẫn cần đánh giá query plan.
- [ ] Manual two-device/runtime nghiệm thu vẫn pending.

## K. Mặc định stranger messaging và đồng bộ block UI (2026-11-17)

- [x] User mới/chưa có messaging setting mặc định `EVERYONE`; không ghi đè policy đã lưu.
- [x] Profile AppBar và nội dung hồ sơ cùng mở màn hình quyền riêng tư tin nhắn.
- [x] Chat khôi phục trạng thái block sau reopen/resume; menu đổi sang “Bỏ chặn người dùng”, API unblock xong refresh quyền gửi.
- [x] Profile mở preview chỉ đọc có thông báo nếu policy từ chối tạo chat mới; không tạo conversation giả phía backend.
- [x] Backend policy suite và Flutter messaging suite đã chạy qua trong phiên; xem Implementation Report.
- [ ] Xác minh hai tài khoản/thiết bị và policy transition khi app đang mở.

## L. Revision quản lý hội thoại D-24 (đã bị D-25 thay thế)

- [x] Historical implementation added `hidden_at`; D-25 removes its JPA/API use without dropping the physical column.
- [x] REST DELETE ẩn đúng phía actor; query Inbox, Stranger Inbox và unread áp dụng hidden filter.
- [x] Tin mới chỉ khôi phục list visibility cho participant được phép xem; sender-only giữ kín khỏi recipient.
- [x] Historical D-24 behavior is superseded; see D-25 checklist below.
- [x] Inbox menus no longer include delete; Stranger badge uses unread count.
- [x] Backend targeted tests (17 tests) và Spring context/JPA test pass; Flutter messaging + community badge 37 tests pass; analyzer 11 file không issue.
- [ ] Xác minh schema update/API và hành vi đồng bộ trên hai tài khoản/thiết bị; chưa có runtime evidence.

## M. D-25 — Conversation acceptance, read state and global block access (2026-11-18)

- [x] Accept belongs to canonical Conversation; only recipient action accepts; keep accepted across unfriend/privacy changes.
- [x] Pending detail does not mark read; accept + read cursor are atomic; declined pending content stays hidden from recipient while sender retains history.
- [x] Remove DELETE conversation API, hidden-state filtering, and delete menu actions; menu only profile/block.
- [x] Add pair block guards in profile/search/feed/posts/itineraries/chat REST/WebSocket; targeted regression exists, but not every protected endpoint has a dedicated direct-access test yet.
- [x] Backend targeted tests, Spring context and Flutter messaging/feed/profile tests run successfully; scoped analyzer has no errors/warnings.
- [ ] Runtime/two-device validation and production schema review remain separate, not claimed complete.
