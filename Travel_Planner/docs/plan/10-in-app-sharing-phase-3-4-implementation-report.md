# BÁO CÁO TRIỂN KHAI PHASE 3 & 4: IN-APP SHARING UI & DEEP NAVIGATION

> **Dự án:** Travel Planner Community  
> **Giai đoạn:** Phase 3 & Phase 4 — Share UI, Message Card Rendering & In-App Content Navigation  
> **Branch Git:** `feature/message-sharing`  
> **Ngày hoàn thành:** 21/11/2026  
> **Trạng thái:** Hoàn thành 100% mục tiêu Phase 3 & 4.

---

## 1. Tổng quan Kiến trúc

Triển khai Phase 3 và Phase 4 hoàn thiện trải nghiệm người dùng chia sẻ nội dung trong ứng dụng (In-app Content Sharing) giữa Lịch trình (Itinerary), Bài viết cộng đồng (Community Post) và Hệ thống Tin nhắn (Messaging):

```
+-----------------------------------------------------------------------------------+
|                            ĐIỂM BẮT ĐẦU CHIA SẺ                                  |
|  - ItineraryDetailScreen (AppBar action button)                                   |
|  - PostCardWidget (CommunityFeed, ProfileScreen, PublicProfileScreen)             |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                            SHARE BOTTOM SHEET                                     |
|  - Header preview nội dung (Ảnh đại diện, Tiêu đề, Badge phân loại)               |
|  - Tìm kiếm bạn bè / người dùng (Debounce 300ms, API bạn bè & tìm kiếm)           |
|  - Chọn danh sách người nhận (Tối đa 10 người, Chip hiển thị & bỏ chọn nhanh)      |
|  - Ô nhập lời nhắn kèm theo (Tùy chọn, tối đa 4000 ký tự)                         |
|  - Gửi qua MessagingRepository.shareContent (API POST /api/conversations/shares)   |
|  - Thông báo kết quả chi tiết từng người nhận (Thành công / Thất bại)             |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        HỘI THOẠI & TIN NHẮN (CHAT SCREEN)                         |
|  - Nhận tin nhắn SHARE qua REST hoặc STOMP WebSocket realtime                     |
|  - Render ShareMessageCard tùy biến theo ITINERARY và POST                        |
|  - Hiển thị Snapshot: Ảnh bìa, Tiêu đề, Tác giả, Badge loại nội dung, Lời nhắn   |
|  - Nút bấm trực quan "Xem chi tiết"                                               |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                            ĐIỀU HƯỚNG NỘI DUNG MỤC TIÊU                           |
|  - ITINERARY Card -> Mở ItineraryDetailScreen: Tải dữ liệu mới nhất từ server,    |
|    áp dụng ItineraryAccessGrant cho lịch trình PRIVATE (cho phép xem & clone).    |
|  - POST Card -> Mở PostDetailScreen: Tải bài viết theo ID từ server, hỗ trợ       |
|    tương tác Like, Comment, Share, Report. Xử lý bài viết bị xóa/ẩn (404/403).    |
|  - Quay lại (Pop): Giữ nguyên lịch sử chat, vị trí cuộn và kết nối STOMP.         |
+-----------------------------------------------------------------------------------+
```

---

## 2. Kế thừa Nền tảng Phase 2

Phase 3 và 4 tận dụng toàn bộ các model, client và repository đã hoàn thiện trong Phase 2:
- `ChatMessage`: Các getter tiện ích `isShare`, `isItineraryShare`, `isPostShare`, `shareMetadata`, `displayContent`.
- `ShareMetadata`: Snapshot an toàn của nội dung được chia sẻ (`title`, `coverImage`, `subtitle`, `authorName`, `authorAvatar`, `visibility`, `status`).
- `ShareBatchRequest` & `ShareBatchResponse`: Cấu trúc request gửi hàng loạt cho tối đa 10 người nhận và xử lý kết quả từng phần.
- `MessagingRepository.shareContent`: Phương thức gọi trực tiếp endpoint `POST /api/conversations/shares`.
- `ChatScreen`: Cơ chế de-duplication theo `messageId` và `clientMessageId`, giữ thứ tự `sequenceNumber` tăng dần, quản lý `peerReadSequence` đơn điệu.

---

## 3. Chi tiết Triển khai Phase 3 — Giao diện Chia sẻ (Share UI)

### 3.1. Widget `ShareBottomSheet`
Được xây dựng mới hoàn toàn tại `Travel_Planner/frontend/mobile/lib/features/messaging/presentation/widgets/share_bottom_sheet.dart`:
- **Header Preview:** Hiển thị thẻ tóm tắt nội dung sắp chia sẻ (ảnh thumbnail, icon phân loại lịch trình/bài viết, tiêu đề và tên tác giả).
- **Bộ lọc & Tìm kiếm Người nhận:**
  - Tải danh sách bạn bè mặc định từ `MessagingRepository.friends()`.
  - Hỗ trợ ô tìm kiếm với cơ chế debounce 300ms, tự động chuyển đổi giữa danh sách bạn bè và kết quả tìm kiếm người dùng qua `MessagingRepository.searchUsers()`.
  - Lọc bỏ chính người dùng hiện tại (`currentUserId`).
- **Lựa chọn Đa người nhận (Multi-selection):**
  - Giới hạn tối đa 10 người nhận; tự động hiển thị SnackBar cảnh báo nếu người dùng cố gắng chọn người thứ 11.
  - Danh sách ngang (Horizontal ListView) chứa các chip người dùng đã chọn kèm nút xóa nhanh (remove icon).
- **Lời nhắn Kèm theo (Optional Note):**
  - Trường `TextField` đa dòng với bộ đếm ký tự (`maxLength: 4000`), cho phép đính kèm ghi chú cá nhân khi chia sẻ.
- **Trạng thái Gửi & Phản hồi:**
  - Nút gửi tích hợp `CircularProgressIndicator` khi đang gửi.
  - Sau khi API trả về, phân tích `ShareBatchResponse`:
    - Nếu thành công tất cả: Đóng sheet và hiển thị thông báo thành công.
    - Nếu có lỗi một phần: Hiển thị danh sách các người nhận thất bại (ví dụ: bị chặn, hạn chế quyền riêng tư).
    - Nếu thất bại toàn bộ: Giữ sheet mở để người dùng có thể thử lại.

### 3.2. Điểm Bắt đầu Chia sẻ (Entry Points)
1. **Chi tiết Lịch trình (`ItineraryDetailScreen`):**
   - Thêm nút `IconButton(Icons.share_outlined)` trên `AppBar`.
   - Mở `ShareBottomSheet` truyền `targetType: 'ITINERARY'`, `targetId`, tiêu đề lịch trình, ảnh bìa và thông tin tác giả.
2. **Thẻ Bài viết Cộng đồng (`PostCardWidget`):**
   - Thêm thuộc tính `final VoidCallback? onShare;` vào `PostCardWidget`.
   - Thêm nút Chia sẻ (icon `Icons.share_outlined`) trong hàng thao tác tương tác bên cạnh Thích và Bình luận.
3. **Các Màn hình Tích hợp:**
   - `CommunityFeedScreen`: Kích hoạt `_openSharePost` khi nhấn chia sẻ trên bất kỳ bài viết nào trong bảng tin.
   - `ProfileScreen` (Hồ sơ của tôi): Cho phép chia sẻ các bài viết trong tab "Bài viết" của người dùng.
   - `PublicProfileScreen` (Hồ sơ công khai): Cho phép chia sẻ các bài viết của người dùng khác.

---

## 4. Chi tiết Triển khai Phase 4 — Thẻ Tin nhắn & Điều hướng Nội dung (Share Message Card & Navigation)

### 4.1. Thẻ Tin nhắn Chia sẻ (`ShareMessageCard`)
Được triển khai tại `Travel_Planner/frontend/mobile/lib/features/messaging/presentation/widgets/share_message_card.dart`:
- **Thiết kế Chuẩn mực Wanderlog:** Nền sáng tối giản, góc bo cong mềm mại, viền hairline tinh tế, không lồng ghép rườm rà.
- **Phân biệt Rõ ràng giữa Lịch trình và Bài viết:**
  - Badge loại nội dung: `Lịch trình` (màu xanh dương đậm/teal với icon hành lý) hoặc `Bài viết` (màu cam nhạt/accent với icon bài viết).
  - Ảnh bìa (Cover Image): Hiển thị tỷ lệ 16:9 với bo góc trên, kèm icon dự phòng nếu ảnh trống hoặc lỗi mạng.
  - Khối thông tin: Tiêu đề in đậm, phụ đề/ngày đi/tác giả, và avatar tác giả.
  - Lời nhắn của người gửi: Render trong khung trích dẫn riêng biệt phía trên hoặc dưới thẻ nội dung.
  - Call to Action: Nút "Xem chi tiết" với mũi tên chỉ hướng `Icons.arrow_forward_ios`.

### 4.2. Tích hợp vào `ChatScreen`
- Trong hàm `_buildMessageRow`: Kiểm tra `if (message.isShare)`.
- Render `ShareMessageCard` với sự căn chỉnh phù hợp (tin nhắn của tôi nằm bên phải, tin nhắn của bạn bè nằm bên trái).
- Kết nối sự kiện `onTap`:
  - `ITINERARY`: Điều hướng sang `ItineraryDetailScreen`.
  - `POST`: Điều hướng sang `PostDetailScreen`.

### 4.3. Màn hình Chi tiết Bài viết (`PostDetailScreen`)
Được tạo mới tại `Travel_Planner/frontend/mobile/lib/features/social/presentation/screens/post_detail_screen.dart`:
- Tải dữ liệu bài viết mới nhất từ server qua `CommunityPostRepository.getPostById(widget.postId)`.
- Xử lý đầy đủ các trạng thái giao diện:
  - **Loading:** Thanh tiến trình chờ dữ liệu.
  - **Error / 404 / 403:** Màn hình lỗi thân thiện thông báo "Bài viết không còn khả dụng hoặc đã bị tác giả xóa" kèm nút Thử lại hoặc Quay lại.
  - **Success:** Tái sử dụng `PostCardWidget` đầy đủ tính năng: xem ảnh, nhấn thích, mở danh sách bình luận (`PostCommentsSheet`), chia sẻ tiếp và báo cáo vi phạm.

### 4.4. Kiểm soát Quyền truy cập & Bảo toàn Trạng thái Điều hướng
- **Lịch trình Private:** Nhờ `ItineraryAccessGrant` đã hoàn thành ở Phase 1, khi người nhận nhấn vào thẻ lịch trình Private trong chat, Backend xác thực grant hợp lệ và trả về nội dung chi tiết. Người nhận có thể xem toàn bộ lịch trình và thực hiện thao tác Clone (Nhân bản) thành lịch trình của mình.
- **Lịch trình bị Thu hồi / Xóa:** Nếu chủ sở hữu đã xóa hoặc thu hồi grant, `ItineraryDetailScreen` hiển thị trạng thái lỗi 403/404 an toàn mà không làm sập ứng dụng.
- **Bảo toàn Cuộc trò chuyện:** Sử dụng `Navigator.push` tiêu chuẩn. Khi người dùng nhấn nút Back từ màn hình chi tiết, `ChatScreen` không bị unmount, giữ nguyên kết nối WebSocket STOMP, danh sách tin nhắn và vị trí cuộn.

---

## 5. Danh sách File Đã Tạo và Thay đổi

| Hành động | Đường dẫn File | Chức năng chính |
| :--- | :--- | :--- |
| **Tạo mới** | `frontend/mobile/lib/features/messaging/presentation/widgets/share_bottom_sheet.dart` | BottomSheet chọn người nhận (tối đa 10), tìm kiếm, ghi chú, gửi chia sẻ |
| **Tạo mới** | `frontend/mobile/lib/features/messaging/presentation/widgets/share_message_card.dart` | Card hiển thị tin nhắn SHARE trong danh sách chat |
| **Tạo mới** | `frontend/mobile/lib/features/social/presentation/screens/post_detail_screen.dart` | Màn hình chi tiết bài viết khi mở từ card tin nhắn |
| **Chỉnh sửa** | `frontend/mobile/lib/features/messaging/presentation/screens/chat_screen.dart` | Tích hợp render `ShareMessageCard` và điều hướng |
| **Chỉnh sửa** | `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` | Thêm nút Chia sẻ trên AppBar và mở `ShareBottomSheet` |
| **Chỉnh sửa** | `frontend/mobile/lib/features/social/presentation/widgets/post_card_widget.dart` | Thêm action chia sẻ trong danh sách nút thao tác |
| **Chỉnh sửa** | `frontend/mobile/lib/features/social/presentation/screens/community_feed_screen.dart` | Kết nối action chia sẻ trên bài viết bảng tin |
| **Chỉnh sửa** | `frontend/mobile/lib/features/profile/presentation/screens/profile_screen.dart` | Kết nối action chia sẻ trên bài viết tab cá nhân |
| **Chỉnh sửa** | `frontend/mobile/lib/features/profile/presentation/screens/public_profile_screen.dart` | Kết nối action chia sẻ trên bài viết tab người dùng công khai |
| **Tạo mới** | `docs/plan/10-in-app-sharing-phase-3-4-implementation-report.md` | Báo cáo chi tiết quá trình triển khai Phase 3 & 4 |

---

## 6. Kết luận & Bước tiếp theo
Phase 3 & 4 đã hoàn tất đầy đủ mọi yêu cầu về giao diện, luồng trải nghiệm, tính năng chia sẻ đa người nhận, hiển thị thẻ tin nhắn và điều hướng nội dung hai chiều. Ứng dụng sẵn sàng cho việc nghiệm thu tính năng chia sẻ nội dung trong ứng dụng.
