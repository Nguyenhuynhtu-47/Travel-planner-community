# 07 — Roadmap triển khai

**Cập nhật:** 2026-11-17. Source đã triển khai một phần Phase 1–3; DB/runtime và các exit criteria chưa được xác minh.

## Phase 0 — Chốt hành vi và môi trường

**Trạng thái: một phần.** D-16/cooldown đã chốt; test DB localhost MySQL 8.0.44 được xác nhận và schema test đã được cập nhật. Chưa có backup/restore evidence hoặc kiểm tra runtime hai thiết bị.

- Review Decision Record D-12 trở đi: NOBODY, accepted chat sau đổi privacy/unfriend, request cap/cooldown/resend, declined retention, notification history.
- Chọn MySQL disposable đúng version; xác nhận schema thật và backup/restore được trước DDL.
- Ghi rõ base URL backend cho emulator + phone; dùng cùng process/backend trong test.

**Exit:** quyết định không còn ambiguity ảnh hưởng schema/API; fixture DB an toàn.

## Phase 1 — Backend model/query/API

**Trạng thái: source, unit tests và Spring context đã xác minh; API/concurrency integration còn thiếu.** `Conversation` có status/requester/recipient/timestamps nullable để bản ghi cũ tiếp tục được hiểu là ACCEPTED. Đã thêm list/count/accept/decline request endpoints; repositories khởi tạo trên MySQL 8.0.44. Unit tests messaging pass; full backend suite có lỗi test isolation trong ba class ngoài messaging.

- Thiết kế additive message request lifecycle, tương thích conversations cũ = accepted.
- Thêm list/accept/decline request endpoints và permission checks; canonical pair/concurrency/idempotency.
- Tối ưu query badge: total unread messages (giữ contract), optional unread conversation count, friend pending count, stranger pending count.
- Chỉ thêm notification persistence nếu scope được chốt riêng.
- Xác minh API docs, constraints/indexes, migration/rollback trên disposable MySQL.

**Exit:** service/integration tests qua; privacy matrix và race cases xác định; schema diff reviewed.

## Phase 2 — Realtime lifecycle và event contract

**Trạng thái: source đã triển khai; runtime reconnect/session chưa xác minh.** App shell sở hữu shared client; ChatScreen khởi tạo từ snapshot hiện tại; friend/request actions phát invalidation event sau commit. REST vẫn là nguồn dữ liệu chuẩn.

- Khắc phục state snapshot/race trong UI; thống nhất owner/scope và dispose client.
- Account switch/logout/token refresh/expiry cleanup; reconnect + resubscribe.
- Phát event invalidation sau commit cho message/request/friendship actions cần thiết. REST refetch authoritative state.
- Thêm structured reason code/metrics/logs không chứa JWT/message; xác minh giới hạn sessions.
- Xác nhận quyết định về delivery durability; giữ simple broker nếu MVP single-process.

**Exit:** duplicate/lost event không làm state cuối sai sau REST reconcile; không để session leak.

## Phase 3 — Flutter UI

**Trạng thái: source + feature tests đã triển khai; full suite/analyzer chưa xanh.** Community có Friends, lời mời và Stranger Inbox cùng badge riêng; chat hiển thị avatar/time/trạng thái kết nối và thao tác nhận/từ chối request. Full Flutter suite còn lỗi ngoài feature; xem Implementation Report cập nhật.

- Chat avatar/time/status/connection states theo design system.
- Community badges, Friends/Invites, Stranger Inbox; profile navigation; pending request actions.
- Refresh on resume/route return/event invalidation; loading/error/empty/offline states.
- Giữ Community 5-tab và tái dùng feature components/repositories.

**Exit:** widget tests và analyzer qua; không có duplicate navigation/data systems.

## Phase 4 — Kiểm thử tích hợp và hai thiết bị

**Trạng thái: chưa hoàn tất.** Spring context/JPA đã chạy trên test MySQL; chưa kiểm tra authenticated API/WebSocket thật, phone/emulator app-to-app.

- Backend tests, Flutter tests, disposable MySQL migration/concurrency, API contract.
- Manual Android emulator + physical phone cùng backend; kiểm tra connect/subscription, gửi hai chiều, mất mạng/reconnect, badge/privacy.
- Xác minh log/runtime bằng evidence; update CODEBASE_GUIDE hoặc feature docs nếu implementation đổi contract.

**Exit:** checklist 10 có bằng chứng theo từng mục; báo cáo triển khai ghi versions/commands/results thực tế.

## Phase 5 — Rollout

- Snapshot/backup, deploy additive schema/API trước mobile nếu tương thích.
- Theo dõi error/session metrics; rollback procedure; không xóa bảng hoặc dữ liệu.
- Production profile validate schema; không bật auto-update tùy tiện.

Không đánh dấu phase complete chỉ vì source compile; yêu cầu runtime/DB tương ứng phải được xác minh.

## Addendum — Roadmap Community/Discovery Revision 2 (plan-only)

Baseline inbox/user search đã có source; các thay đổi dưới đây chưa implement và chờ duyệt revision 2 tại plan 12:

1. **API/Backend:** thêm batch accepted-conversation context và additive `canStartConversation`/`canContinueConversation` result fields; giữ legacy `canMessage` alias. Reuse settings API/Entity; verify pending request behavior after privacy changes. Normalize user query and select index/migration only after MySQL collation + EXPLAIN/benchmark.
2. **Flutter navigation:** remove only direct Stranger Inbox shortcut from Community header; retain route through Messaging Inbox. Move user-search entry to Explore AppBar next to Notifications, preserving itinerary search. Add canonical Profile > Settings > Messaging Privacy route, reusing existing screen. Add public-profile CTA/state for start versus existing accepted thread.
3. **Search:** preserve distinct user search in Explore and conversation-only inbox filtering. Implement Vietnamese diacritic-insensitive partial/prefix behavior with bounded, server-side queries; stable pagination, debounce, stale response suppression, explicit loading/empty/error state.
4. **Verification:** backend unit/API/query tests, Flutter route/widget tests, privacy state matrix, and emulator+device manual flow. If normalized name index is approved, test additive backfill/migration/rollback on disposable MySQL.

**Exit:** no duplicate navigation/data layer; API permission enforced server-side; privacy transitions follow D-16; user search is distinct from Explore itinerary search and Inbox conversation filter; tests and runtime evidence recorded. No source/database change is authorized by this plan revision itself.

> **Trạng thái cập nhật 2026-11-17:** người dùng tiếp tục yêu cầu cập nhật Plan và triển khai code. Phần source đã triển khai được ghi tại plan 12 và Implementation Report. Câu “No source/database change is authorized” là snapshot của revision plan-only tại thời điểm trước đó, không còn là trạng thái hiện tại.

## Revision 4 — Chấp nhận toàn conversation, read cursor và block access (2026-11-18)

**Source:** implementation theo D-25 cần được xác minh; runtime/two-device chưa nghiệm thu.

1. Backend: Conversation status ACCEPTED là trạng thái bền vững độc lập friendship/privacy; remove accepted→pending on unfriend and implicit accept on reply. Accept updates status + recipient read cursor atomically; pending read endpoint is rejected.
2. Decline: retain history for requester; set requester's pending messages recipient-invisible before decline; resend after existing 1-day cooldown reuses canonical conversation and only new messages are visible under current policy.
3. Remove conversation delete/hide API and Inbox delete actions. Keep ellipsis only profile/block, each isolated from row navigation.
4. Block access: apply symmetric pair visibility guard to user profile/search, post/feed/comment actions, public itinerary listing/detail, conversation/history/send and WebSocket event delivery; do not delete rows/history. Filter list queries before pagination.
5. Verification: service/repository/API tests for accept/read atomicity, decline visibility/retry, unfriend stability, block direct/list access, and Flutter request/badges/menu controls. Manual runtime two devices remains a separate acceptance gate.

**Exit:** API/JPA query khởi động, service tests và widget tests pass; quyền truy cập actor-only được kiểm tra; runtime DB và hai thiết bị vẫn phải ghi riêng, không đánh dấu khi chưa chạy.

## Addendum — Chat avatar/layout implementation phase (plan-only, 2026-11-17)

**Kết quả:** Phần Flutter UI đã implement và widget tests pass (12 tests trong feature messaging). Chưa xác minh bằng app chạy trên emulator/điện thoại.

## Addendum — Privacy/Block, Header, Explore Search và Timestamp (2026-11-17)
1. Audit giữ nguyên backend privacy, stranger request, block entities/routes và search service. Chỉ sửa `ChatEventListener` để revalidate block trước delivery nếu event model có actor IDs; mở rộng tests listener/service. Không thêm schema/API.
2. Flutter Chat Detail: header peer avatar + ellipsis/title; mở profile; dialog block; gọi repository `block`; success khóa gửi và giữ history. Xóa community feed shortcut Stranger nhưng Inbox entry/badge vẫn dùng được.
3. Explore: mở UserSearchScreen qua action cạnh notifications; reuse search API/repository/relationship actions. Không đổi itinerary search. Accent-insensitive substring/search indexing chỉ thay khi MySQL query plan chứng minh strategy.
4. Thêm một date-time parser/formatter trong messaging dùng cho messages, summaries, pending availability và các list. Bao phủ UTC/offset và backend LocalDateTime; Asia/Ho_Chi_Minh, `HH:mm dd-MM-yyyy`, không đổi DB.
5. Kiểm tra profile/privacy/pending/accepted/block matrix, unit/widget tests, API/event listener tests, rồi cập nhật status. Manual two-device vẫn là gate riêng.

Thực hiện trong Flutter UI phase sau khi chốt layout; không cần migration theo audit hiện tại.

1. **Contract/model audit:** xác nhận REST page, send response, STOMP event đều chuyển đủ senderUserId/senderAvatar/createdAt; own profile avatar và peer avatar có fallback đúng. Giữ idempotency/sequence và message items độc lập.
2. **Row/layout:** trong `chat_screen.dart`, thay hai nhánh render hiện tại bằng row hai chiều dùng chung; own avatar bên phải, peer bên trái. Tính width bubble sau khi trừ padding/avatar/gap, thử kích thước hẹp/text scale và tránh overflow.
3. **Grouping:** tính run liên tiếp theo sender + khoảng thời gian/ngày; giảm gap trong nhóm, tăng gap giữa nhóm; chỉ hiện avatar ở bubble cuối nhóm, các item còn lại giữ slot cân bằng. Không gộp data message, timestamps/status/retry semantics.
4. **Avatar state:** hình tròn kích thước cố định, loading/placeholder/error fallback, ảnh không méo; own lấy Profile/AuthNotifier, peer ưu tiên sender response rồi conversation peer. Xử lý rebuild khi URL đổi và cache invalidation hợp lý.
5. **Regression/acceptance:** thực hiện matrix ở `08-TESTING-AND-REGRESSION.md`; chỉ ghi hoàn tất khi widget tests qua và manual hai phía trên thiết bị/emulator có evidence. REST và WebSocket phải xác định cùng người gửi và avatar.

### File dự kiến
- Chính: `frontend/mobile/lib/features/messaging/presentation/screens/chat_screen.dart`.
- Theo kết quả contract audit, chỉ khi cần: `frontend/mobile/lib/features/messaging/data/models/chat_message.dart`, `conversation_summary.dart`, `messaging_repository.dart`.
- Tests: `frontend/mobile/test/features/messaging/chat_screen_test.dart` (mở rộng test hiện có), và model test chỉ khi model thay đổi.
- Backend/API/DB: không thay đổi nếu sender avatar đang đầy đủ như source hiện tại; nếu test contract phát hiện thiếu field thì sửa mapper hiện hữu và bổ sung test tương ứng, không thêm dữ liệu avatar vào message table.
