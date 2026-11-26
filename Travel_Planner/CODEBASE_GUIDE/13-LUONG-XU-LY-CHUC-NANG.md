# 13. Luồng xử lý end-to-end

## Đăng nhập
Login screen → AuthNotifier → AuthRepository → ApiClient → `POST /api/auth/login` → AuthController/AuthService → user lookup + password/status/JWT → AuthResponse → AuthStorage → authenticated state. Request tiếp theo gắn Bearer token; 401 được ApiClient báo cho app để đồng bộ logout.

## Tạo itinerary/activity
Create/detail screen → notifier/repository → request JSON → `POST /api/itineraries`, sau đó `/api/itineraries/{id}/days` và `/api/itineraries/{id}/days/{dayId}/activities` → ItineraryController/Service → ownership/validation → repositories/entities → response DTO → mobile models/state/UI. Reorder gửi danh sách thứ tự. Backend kiểm soát chủ sở hữu và scope.

## Search map và gắn vị trí
`LocationPickerSheet` → `LocationRepository` → `GET /api/locations/search` → LocationController/LocationService/provider + filtering/ranking/cache → `LocationSearchResultResponse` → người dùng chọn POI hoặc pin → reverse/details nếu cần → `LocationActivityMapper`.
- Place nội bộ: resolve qua `POST /api/places/resolve`, gửi `canonicalPlaceId`; activity tham chiếu Place.
- POI external/manual pin: gửi snapshot tên/địa chỉ/tọa độ/provider/placeId; không tự ghi catalog Place.
- Mobile vẫn giữ method `/api/destinations` không được sử dụng; backend không cung cấp endpoint này. `destinationId` trong DTO activity là tương thích cũ, không phải API/catalog.
CARTO tile fetch độc lập với search, reverse, route và media.

## Saved Place itinerary
Picker/add sheet → resolve provider result thành Place canonical nếu cần → `POST /api/itineraries/{itineraryId}/places` với `placeId` → `ItineraryPlaceController/service` kiểm tra quyền và lưu relation → GET list/all để hiển thị → DELETE `/{placeId}` để bỏ. Đây không đồng nghĩa thêm activity.

## Comment thread
Comments section scope itinerary hoặc activity → repository lấy trang root; reply tải riêng theo thread → gửi `parentCommentId` trực tiếp → `/api/comments/{commentId}/replies` → backend kiểm tra target/scope/visibility, lưu parent/root → DTO trả về → notifier gắn reply vào root thread. Post comments thuộc API/community model riêng.

## Community post và media
Feed/repository gọi `/api/community/feed` hoặc `/feed/following`; create/edit/like/comment/report qua `/api/community/posts...`. Upload file qua multipart `/api/media/images` → backend kiểm tra và upload Cloudinary → secure URL/media asset được dùng bởi UI. Admin moderation đi qua `/api/admin/community/...`. Không đồng nhất post với itinerary comment.

## Messaging và friendship
REST list/create direct conversation, page/send message, mark read, unread qua `/api/conversations...`; message request dùng `GET /api/conversations/message-requests`, `/count`, `/unread-count` và `POST /{conversationId}/accept|decline`. Conversation cũ có status null được hiểu accepted; pending request chỉ có một tin mở đầu, decline cho gửi lại sau 1 ngày. FriendshipController xử lý friend requests/friends/blocks; MessagingSettingsController xử lý preference. `GET /api/users/search?q=&page=&size=` yêu cầu active viewer, tìm prefix theo fullName/handle và trả public fields cùng relationship action flags; quan hệ được batch load. WebSocket/STOMP dùng `/ws` cho sự kiện realtime với interceptor xác thực session; app shell sở hữu shared client và feed refetch badge sau event/resume. Mobile chia các destination Inbox, Stranger Inbox, Friends/Invites và User Search nhưng dùng chung repository. Notification Center dùng API `NotificationController` và repository Flutter; duy nhất chuông Home/Khám phá điều hướng đến Center, trong khi badge chat/friend request vẫn thuộc Community.

## Public profile và upload
Current profile qua `/api/user/profile`; public profile/follow qua `/api/users/...`. Avatar/post/activity image URL được lấy từ upload flow nếu người dùng upload; geocoding/tile provider không mặc nhiên cấp ảnh đại diện địa điểm.

## Notification Core (Phase 1)
Backend `NotificationController` → `NotificationService`/`NotificationServiceImpl` → `NotificationRepository` exposes authenticated principal-scoped feed, unread count, mark-one and mark-all endpoints. Social producers depend on `SocialNotificationService`/`SocialNotificationServiceImpl` and write within the existing successful domain transaction. Create is an internal service seam only; no client endpoint can choose a recipient. The feed uses a bounded keyset cursor and actor join-fetch, merged with shared announcements. Mobile repository/state/screen render the Center, reached from the single Home/Explore bell. Announcement administration uses the existing Flutter Web `AdminShell`. Messaging unread counters remain separate; FCM sends messaging-only push and creates no Center record.
