# 05 — Mobile UI và kiến trúc

## 1. Entry points và màn hình

Tổ chức theo structure hiện tại, không tạo domain layer rỗng hay router framework mới.

### Feature dự kiến

- features/messaging/data/models/: ConversationSummary, Message, MessagePage, ChatEvent, MessagingSettings, FriendSummary, FriendRequest.
- features/messaging/data/: MessagingRepository (REST), MessagingRealtimeClient (STOMP adapter).
- features/messaging/presentation/: MessagingNotifier/ConversationListNotifier, ChatNotifier, FriendNotifier, settings state coordinator.
- features/messaging/presentation/screens/: ConversationListScreen, ChatScreen, FriendsScreen/RequestsScreen nếu không phù hợp gộp Community hub.
- features/messaging/presentation/widgets/: conversation row, message bubble, date separator, composer, read/unread indicator, connection banner.
- Reuse core/network/ApiClient, AuthNotifier, theme tokens, shared empty/error/buttons.
- Repository không gọi API trong widget; ChangeNotifier/ListenableBuilder theo pattern hiện dùng.

Exact class/file split sẽ được kiểm tra khi implementation; không cần nhiều notifier nếu feature nhỏ.

## 2. Điều hướng không thêm tab

Giữ 5 bottom destinations hiện tại. Đề xuất tái sử dụng CommunityScreen (hiện placeholder) thành trung tâm kết nối với các mục/segmented views: Tin nhắn, Lời mời, Bạn bè. ConversationListScreen mở ChatScreen. PublicProfileScreen thêm Nhắn tin và Kết bạn; itinerary detail creator tap tiếp tục mở profile theo userId. ProfileScreen cá nhân có lối vào Cài đặt nhắn tin/block list; không biến hồ sơ cá nhân thành profile công khai.

Không thay nội dung collection/profile tabs hoặc thứ tự tab. Thiết kế cuối theo AppTheme, AppColors, AppSpacing, AppTextStyles, shared widgets, UX loading/empty/error, touch target >=48dp và accessibility. Motion: Level 0 hoặc 1; không cần animation liên tục cho message stream, giữ Material route mặc định.

## 3. Trạng thái chat

ChatNotifier quản lý page đầu, older page cursor, incoming events, pending messages, retry state, read cursor và connection state. Gửi tin:
1. Tạo UUID clientMessageId và optimistic row sending.
2. POST REST với cùng key.
3. Response thành công thay optimistic row bằng persisted message.
4. Nếu event đến trước/sau response thì dedupe theo messageId/clientMessageId.
5. Lỗi xác định: hiển thị failed + retry cùng idempotency key. Timeout mơ hồ: retry vẫn cùng key.
6. Không tự động retry POST bằng key mới.

Older history dùng beforeSequence; merge event/REST theo sequenceNumber riêng của conversation và dedupe theo messageId/clientMessageId. Không sắp thứ tự hội thoại bằng createdAt/messageId. UI phân biệt tin của mình bằng sender userId từ response, không dựa vị trí client.

## 4. Realtime lifecycle

Một MessagingRealtimeClient sở hữu socket theo authenticated account; không tạo socket riêng cho từng widget/conversation.

- Sau AuthNotifier chuyển authenticated, mở socket một lần bằng token hiện tại; chỉ subscribe user queue khi connected.
- Khi token đổi/expired/401, logout hoặc current user ID đổi: deactivate socket, cancel subscriptions, clear cached conversation/message state trước khi mở session khác.
- Khi chat screen mở: nhận state nội bộ/local conversation; server events vẫn đi user queue. Khi screen đóng, bỏ listener; socket global có thể tiếp tục cho unread.
- Khi app đi background: chủ động giảm/đóng socket theo platform policy; không dựa socket cho delivery nền.
- On resume: validate session/token, reconnect with bounded exponential backoff + jitter, tải conversation/unread state và message delta qua REST, dedupe.
- Khi mất kết nối: giữ history đã tải, banner offline/reconnecting, optimistic failed/retry; message đã commit trên server không mất.
- Dispose stream subscriptions/timers/client khi app coordinator dispose. Chặn race giữa beforeConnect lấy token và logout/account switch bằng generation/session ID.

AuthNotifier là ChangeNotifier và root MyApp sở hữu vòng đời hiện tại; implementation có thể gắn coordinator ở app root hoặc inject singleton scoped theo account. Cần test đổi user và 401, không để socket sống khi logout.

## 5. Inbox/unread

Conversation list row: peer avatar/display name, last message excerpt, timestamp, unread badge, connection-independent data. Paginate DB qua API; refresh after resume. Empty/error/retry dùng shared components. Unread badge có thể nằm trên icon Cộng đồng hoặc AppBar action, không đổi tab count. Chốt UX badge/test với 5-tab regression.

Read state cập nhật khi conversation đang mở/visible và người dùng tới cuối lịch sử; mark-read cursor monotonic. Không gửi read receipt từng message; một cursor batched giảm write load.

## 6. Public Profile states

- Own profile: không hiện Nhắn tin/Kết bạn; tiếp tục edit profile.
- Guest: hiện CTA login/đăng nhập trước mutation; profile GET tiếp tục public.
- Authenticated target stranger: friendship/request status và canMessage quyết định CTA.
- Friend: trạng thái Bạn bè + Nhắn tin.
- Request sent/received: Hủy lời mời / Chấp nhận / Từ chối.
- Policy denied / blocked: CTA disabled hoặc generic explanation; không tiết lộ ai đã block.
- Loading/error: giữ profile và không tạo duplicate request; refresh contextual relationship sau returning route.
- Follow vẫn độc lập hiển thị ở profile; có thể vừa follow vừa friend.

## 7. Web

Web hiện app riêng và thiên về auth/profile/admin destination, không có mobile shared source. MVP chỉ triển khai backend contract/WebSocket server dùng chung và Flutter Mobile. Defer web conversation list/chat/settings/push. Trước web phase sau cần POC STOMP browser auth, CORS/origin, token lifecycle, lifecycle tab visibility, responsive UI, keyboard access, Web tests/build. Không sửa Web source trong Giai đoạn 2.


