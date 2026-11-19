# Kế hoạch nhắn tin realtime và friendship

**Trạng thái:** D-25 đã được triển khai một phần lớn trong source ngày 2026-11-18: explicit accept/read cursor, declined-message visibility, accepted thread sau unfriend/privacy, bỏ conversation delete/hide, và block guards. Backend unit 55 tests + Spring context pass; Flutter messaging/feed/profile 40 tests pass; analyzer 8 file không có lỗi/warning (12 info-only lints). Block regression chưa bao phủ mọi endpoint, full suites chưa chạy lại; API app-runtime và two-device chưa xác minh.

## Phạm vi và cách đọc

Tài liệu này là plan đã duyệt và theo dõi implementation. Báo cáo [IMPLEMENTATION-REPORT.md](IMPLEMENTATION-REPORT.md) giữ nguyên snapshot lịch sử và có các implementation updates theo ngày. Phần source đã thay đổi; mọi xác minh runtime được đánh dấu riêng.

Đọc theo thứ tự: [01 Audit hiện trạng](01-CURRENT-SYSTEM-AUDIT.md), [02 Yêu cầu và phạm vi](02-REQUIREMENTS-AND-SCOPE.md), [03 Database](03-DATABASE-DESIGN.md), [04 Backend API/realtime](04-BACKEND-API-AND-REALTIME.md), [05 Mobile](05-MOBILE-UI-AND-ARCHITECTURE.md), [06 Friendship/privacy](06-FRIENDSHIP-AND-PRIVACY.md), [07 Roadmap](07-IMPLEMENTATION-ROADMAP.md), [08 Kiểm thử](08-TESTING-AND-REGRESSION.md), [09 Rủi ro/câu hỏi](09-RISKS-OPEN-QUESTIONS.md), [10 Checklist](10-FINAL-IMPLEMENTATION-CHECKLIST.md), [11 Quyết định](11-DECISION-RECORD.md).

## Nguyên tắc bảo toàn

- Tôn trọng README, DESIGN.md, CODEBASE_GUIDE, coding rules và kiến trúc hiện hữu.
- Community đang là feed-first và có 5 tab; mở rộng entry points hiện có thay vì tạo tab/hub trùng.
- REST tiếp tục nguồn bền vững; STOMP là event/invalidation sau commit, lịch sử REST dùng để resync.
- Backend là nguồn quyết định friendship, privacy, request, membership, block và account status.
- Giữ JPA/Hibernate approach hiện tại; không thêm migration framework/database runner không cần thiết.
- Không reset/xóa dữ liệu. Không tuyên bố schema vật lý đã tồn tại nếu chưa introspect DB.

## Kết quả audit nhanh

Audit hiện trạng trước implementation và các thay đổi hiện tại được phân biệt trong tài liệu 01/07. Source hiện có message request inbox, badge và shared realtime owner; Notifications vẫn placeholder. Runtime, DB và thiết bị chưa được nghiệm thu.

## Acceptance còn mở

D-25 tại Decision Record là nguồn hành vi hiện hành: accept toàn Conversation, read cursor chỉ cập nhật khi accept, accepted thread giữ trạng thái sau unfriend, bỏ xóa hội thoại, block chặn dữ liệu toàn hệ thống. D-24 được đánh dấu lịch sử/superseded. Runtime API và hai thiết bị chưa nghiệm thu.

## Bổ sung 2026-11-17
Plan bổ sung [12 — Community Navigation, Messaging Inbox và Friend Discovery](12-COMMUNITY-NAVIGATION-INBOX-AND-FRIEND-DISCOVERY.md) có baseline routes/user search đã triển khai. Revision 2 ngày 2026-11-17 (xem §9) chỉ cập nhật kế hoạch theo yêu cầu mới; Explore search placement, public-profile permission flags, Profile privacy entry và nâng cấp Vietnamese search chưa implement. Active Community hiện còn shortcut Stranger riêng trên header; target là đi vào qua Messaging Inbox. Icon vuông khác vẫn chưa được định vị.

### Plan Revision — Chat Avatar/Layout (2026-11-17)
Yêu cầu chat avatar hai phía, căn lề và grouping đã implement trong Flutter; automated tests pass, manual device validation còn mở. Xem audit/REST-STOMP contract tại [04](04-BACKEND-API-AND-REALTIME.md), widget/layout tại [05](05-MOBILE-UI-AND-ARCHITECTURE.md), roadmap tại [07](07-IMPLEMENTATION-ROADMAP.md), acceptance tại [08](08-TESTING-AND-REGRESSION.md) và checklist [10](10-FINAL-IMPLEMENTATION-CHECKLIST.md). Không yêu cầu schema mới theo source audit hiện tại.
