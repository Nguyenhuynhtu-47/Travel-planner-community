# 06 — Friendship, Follow và privacy

## 1. Quan hệ khác nhau

- Follow hiện là cạnh một chiều follower → following, có API POST/DELETE /api/users/{userId}/follow, follower/following list và trạng thái isFollowing.
- Friendship là trạng thái theo cặp, hai chiều sau khi accept. Không dùng FollowRepository để giả lập friend list; không xóa/đổi Follow API.
- Người dùng có thể follow nhưng chưa friend; friend nhưng không follow; cả hai hoặc không quan hệ.

## 2. State model

Bảng friendships giữ một canonical row per pair:
- NONE: không có row.
- PENDING: requested_by_user_id gửi; participant kia nhận.
- ACCEPTED: hai chiều là bạn bè.
- REJECTED: request đã từ chối; không là bạn.
- BLOCKED là quan hệ riêng ở user_blocks, không phải friendship state.

Transitions:
- NONE → PENDING khi gửi lời mời.
- PENDING → ACCEPTED bởi đúng người nhận.
- PENDING → REJECTED bởi đúng người nhận.
- PENDING → NONE khi requester hủy (xóa row hoặc reset; contract cần chốt).
- ACCEPTED → NONE khi một trong hai unfriend.
- REJECTED → PENDING khi một bên gửi lời mời mới sau cooldown/policy.
- Nếu A có pending tới B và B gửi ngược lại: đề xuất coi là accept intent, chuyển cùng row sang ACCEPTED; tránh hai pending đối nghịch. Nếu request đã REJECTED, không auto-accept request cũ.
- Hai thao tác cùng lúc được serialize theo canonical user pair/conditional update; unique pair là guard cuối. Không dựa pre-check trong service.

Acceptance là quan hệ idempotent; double accept trả trạng thái hiện tại hoặc 409 consistent. Request duplicate cùng chiều trả existing pending. Target không active, self request, block hoặc already friend trả lỗi domain phù hợp, không tạo row.

## 3. Privacy policies đề xuất

| Policy | Người không phải friend | Friend | New conversation | Existing conversation |
|---|---|---|---|---|
| EVERYONE | Được gửi | Được gửi | Mở trực tiếp | gửi nếu không block/account inactive |
| FRIENDS_ONLY (default) | Không gửi; có thể gửi friend request | Được gửi | Chỉ mở khi ACCEPTED | history giữ; send yêu cầu vẫn là friend |
| NOBODY | Không gửi | Không gửi | Không mở/gửi | history giữ; send bị chặn |

Policy mặc định FRIENDS_ONLY là đề xuất giảm spam, nhưng là quyết định sản phẩm cần owner phê duyệt. Với EVERYONE, strangers gửi thẳng inbox ở MVP; chưa có message request inbox. Nếu trải nghiệm cần chấp nhận tin nhắn riêng, phải thêm trạng thái request conversation và luồng UI/API riêng.

Settings là owner-only. Backend kiểm tra inboundPolicy của recipient mỗi lần mở/gửi; friendship ACCEPTED chỉ thỏa FRIENDS_ONLY. Mọi hướng block chặn. Không cho tạo conversation nếu policy đang cấm. Existing conversation/history không bị xóa; khi policy đổi, thao tác send được đánh giá theo rule mới. Có thể trả 403 generic “Không thể gửi tin nhắn cho người dùng này”.

Profile canMessage là contextual projection với viewer; không lộ raw setting hay block direction. Guest canMessage=false. Own profile canMessage=false.

## 4. Block

Nên có block tối thiểu ngay MVP vì tính năng mở tin nhắn người lạ tạo nguy cơ quấy rối. user_blocks có hướng blocker → blocked; backend luôn kiểm tra cả hai hướng.

Khi block:
- Ngăn new conversation, send message, friend invite/accept giữa hai phía.
- Hủy friendship/pending request pair để unblock không tự khôi phục friend; giữ block record.
- Conversation và message history không xóa; ẩn/giữ row trong inbox là quyết định UX phụ, nhưng không phát event chat mới.
- Không thông báo cho target “bạn bị block”; trả lỗi generic.
- Unblock không tự restore friendship/conversation permission. Không xóa history.

Block/unblock cần idempotent và unique guard. Danh sách block/private, chỉ user sở hữu đọc được.

## 5. Deactivation / banned / deletion

UserStatus hiện ACTIVE/INACTIVE/BANNED; không thấy hard-delete account API trong module đã khảo sát. Inactive/banned không thể CONNECT, gửi/đọc API yêu cầu auth; người khác không được nhận user đó trong friend suggestions/lists. Preserve rows/history; không cascade delete user data.

Nếu tài khoản bị xóa vĩnh viễn về sau, cần retention/privacy/legal policy: xóa hoặc ẩn danh sender, xử lý message/backup, FK strategy và khả năng khôi phục. Không tự đặt hard-delete cascade trong MVP.

## 6. Message request và spam

MVP không tạo message-request inbox: FRIENDS_ONLY mặc định và friend request tạo consent gate đơn giản; EVERYONE là explicit opt-in của chủ tài khoản. Message request inbox có ích nếu muốn strangers liên hệ mà không vào inbox chính; sẽ cần pending/accepted/declined state per sender-conversation, giới hạn số request, mute/ignore và unread/request badge. Đưa vào phase sau sau feedback.

Rate limit send theo account, recipient, IP/context; friend invitation theo sender-recipient/quota. Dùng UserDetails current status, server-side validation, block checks, idempotency and rate limits; Bucket4j có trong pom nhưng limiter hiện tại cho location cần tách key/limits cho chat, không tái dùng limiter bằng IP một cách mặc định.
