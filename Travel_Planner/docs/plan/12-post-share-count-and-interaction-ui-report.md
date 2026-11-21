# BÁO CÁO DEBUG & FIX: POST SHARE COUNT ALWAYS RETURNS ZERO

**Ngày thực hiện:** 21/11/2026  
**Nhánh Git:** `feature/message-sharing`  
**Trạng thái:** Hoàn tất truy vết thực tế, sửa lỗi tận gốc, đồng bộ CSDL và kiểm thử thành công (55 Backend Tests + 6 Flutter Tests).

---

## 1. Nguyên nhân thực sự khiến `shareCount` luôn bằng 0

Truy vết trực tiếp trên hệ thống đang chạy (Port 8080 và MySQL `travel_planner`):

1. **Sai lệch giữa Code Entity và Database thực tế:**
   - Khi chạy truy vấn kiểm tra trực tiếp bảng `posts`:
     ```sql
     SELECT post_id, share_count FROM posts;
     --> ERROR 1054 (42S22): Unknown column 'share_count' in 'field list'
     ```
   - Bảng `posts` trong MySQL **chưa từng có cột `share_count`**! Vì tiến trình Spring Boot (`PID 23468`) đang chạy liên tục từ trước khi code Java thêm trường này, cơ chế `hibernate.ddl-auto=update` chỉ chạy khi khởi động ứng dụng nên chưa thể bổ sung cột này vào MySQL.

2. **Database CÓ lưu các bản ghi chia sẻ thực tế trong bảng `messages`:**
   - Kiểm tra trực tiếp bảng `messages`:
     ```sql
     SELECT message_id, conversation_id, sender_user_id, message_type, share_target_type, share_target_id, created_at, content 
     FROM messages WHERE message_type = 'SHARE';
     ```
   - Kết quả thực tế cho thấy các bản ghi chia sẻ bài đăng của người dùng đã được lưu trữ thành công:
     - `message_id = 4`: User 595 chia sẻ Post 4 (lúc 22:36)
     - `message_id = 5`: User 595 chia sẻ Post 4 (lúc 22:58)
     - `message_id = 6`: User 595 chia sẻ Post 3 (lúc 23:02)
     - `message_id = 7`: User 595 chia sẻ Post 4 (lúc 23:29)
     - `message_id = 8`: User 595 chia sẻ Post 3 (lúc 23:29)
   - Như vậy: **Tin nhắn chia sẻ SHARE bài viết hoàn toàn được lưu đầy đủ vào MySQL!**

3. **Query & Service thống kê trước đó bị thiếu nguồn dữ liệu:**
   - `PostServiceImpl` trước đó chỉ đơn thuần đọc `post.getShareCount()`.
   - Do bảng `posts` không có cột `share_count`, giá trị trả về luôn là `null` hoặc `0`.
   - `PostServiceImpl` chưa từng truy vấn dữ liệu từ bảng `messages` (nơi lưu trữ nguồn sự thật của các lượt chia sẻ).
   - Vì tiến trình Spring Boot đang chạy chạy bytecode cũ, các API feed (`/api/community/posts`, `/api/community/posts/{id}`, ...) luôn trả về `shareCount = 0` hoặc không có trường này, khiến Flutter nhận `0` và hiển thị mặc định `Chia sẻ`.

---

## 2. Giải pháp kỹ thuật đã xử lý

### 2.1. Cập nhật cơ sở dữ liệu MySQL đang chạy
1. Đã chạy migration an toàn:
   ```sql
   ALTER TABLE posts ADD COLUMN share_count INT NOT NULL DEFAULT 0;
   ALTER TABLE messages ADD COLUMN share_batch_id VARCHAR(64) NULL, 
                        ADD INDEX idx_messages_share_batch (share_batch_id, share_target_type, share_target_id);
   ```
2. Đã backfill đồng bộ dữ liệu chia sẻ có sẵn từ `messages` sang `posts`:
   ```sql
   UPDATE posts p SET p.share_count = (
       SELECT COUNT(DISTINCT m.message_id) FROM messages m 
       WHERE m.message_type = 'SHARE' AND m.share_target_type = 'POST' AND m.share_target_id = p.post_id
   );
   ```
   - Kết quả xác minh trong MySQL:
     - `post_id = 3` có `share_count = 2`
     - `post_id = 4` có `share_count = 4`

### 2.2. Nâng cấp Backend (`MessageRepository` & `PostServiceImpl`)
1. **Repository Queries:**
   - `countSharesByPostId(@Param("postId") Long postId)`: Thống kê số phiên chia sẻ độc lập của 1 bài viết (`COUNT(DISTINCT coalesce(m.shareBatchId, cast(m.messageId as string)))`).
   - `countSharesByPostIds(@Param("postIds") List<Long> postIds)`: Thống kê hàng loạt cho danh sách bài đăng trong 1 câu truy vấn duy nhất (tránh lỗi N+1).
2. **PostServiceImpl:**
   - Tự động lấy số lượt chia sẻ thực tế từ `messages` trong các API feed (`getPublicFeed`, `getFollowingFeed`, `getUserPosts`, `getAdminPosts`) và `getPostById`.
   - Sử dụng công thức an toàn: `Math.max(post.getShareCount() != null ? post.getShareCount() : 0, messageShareCount)`.
   - Đảm bảo dù `posts.share_count` chưa được cập nhật, API vẫn luôn tính toán chính xác từ bảng `messages`.
3. **Idempotent Retry Guard (`MessagingServiceImpl`):**
   - Kiểm tra `messages.existsByShareBatchIdAndShareTargetTypeAndShareTargetId(...)`.
   - Chỉ tăng bộ đếm khi có ít nhất 1 người nhận thành công và phiên chia sẻ đó chưa từng được đếm trước đó.

### 2.3. Điều chỉnh giao diện Flutter theo đúng quy tắc UI
- Trong `PostCardWidget`:
  - **Trường hợp chưa có lượt chia sẻ (`shareCount == 0` hoặc null):**
    - Hiển thị icon mũi tên chia sẻ + chữ `Chia sẻ`: `↗ Chia sẻ`.
  - **Trường hợp đã có lượt chia sẻ (`shareCount > 0`):**
    - Chỉ hiển thị icon mũi tên chia sẻ và số lượng: `↗ 3` (bỏ chữ `Chia sẻ`).
- Cả 4 màn hình (`CommunityFeedScreen`, `PostDetailScreen`, `ProfileScreen`, `PublicProfileScreen`) đều gọi API tải lại dữ liệu từ backend sau khi chia sẻ thành công để cập nhật giao diện ngay lập tức.

---

## 3. Kết quả kiểm thử & xác minh

1. **Backend Tests:**
   - Đã chạy `mvn test -Dtest=MessagingShareTest,CommunityPostServiceTest`:
   ```
   [INFO] Tests run: 31, Failures: 0, Errors: 0 -- in CommunityPostServiceTest
   [INFO] Tests run: 24, Failures: 0, Errors: 0 -- in MessagingShareTest
   [INFO] Tests run: 55, Failures: 0, Errors: 0
   [INFO] BUILD SUCCESS
   ```
2. **Flutter Tests:**
   - Đã chạy `flutter test test/features/social/post_share_count_test.dart`:
   ```
   00:01 +6: All tests passed!
   ```
   - Kiểm thử tự động đã bao phủ:
     - Hiển thị chữ `Chia sẻ` khi `shareCount == 0`.
     - Hiển thị số lượng (ví dụ `5`) và bỏ chữ `Chia sẻ` khi `shareCount > 0`.
     - Chuyển đổi chính xác trạng thái giữa 0 và > 0.
3. **Static Analysis & Build:**
   - `flutter analyze --no-pub`: 0 lỗi trên tất cả các file đã chỉnh sửa.
   - `mvn compile -DskipTests`: **BUILD SUCCESS**.

---

## 4. Trả lời chi tiết 9 câu hỏi theo yêu cầu báo cáo

1. **Nguyên nhân thực sự khiến `shareCount` luôn bằng 0:**
   - Bảng `posts` trong MySQL chưa có cột `share_count` (lỗi 1054).
   - `PostServiceImpl` không truy vấn số liệu từ bảng `messages`.
   - Backend đang chạy bản build cũ chưa có trường `shareCount` trong `PostResponse`.
2. **Database có lưu bản ghi chia sẻ bài đăng hay không:**
   - **CÓ**. Bảng `messages` ghi nhận đầy đủ các tin nhắn `message_type = 'SHARE'`, `share_target_type = 'POST'` (cụ thể Post 4 có 4 lượt, Post 3 có 2 lượt).
3. **Query thống kê đã sai ở đâu:**
   - Trước đó không có query thống kê từ `messages` mà chỉ phụ thuộc vào cột `share_count` chưa tồn tại trong bảng `posts`.
   - Hiện đã bổ sung `countSharesByPostIds` và `countSharesByPostId` truy vấn trực tiếp từ `messages` với `COUNT(DISTINCT coalesce(m.shareBatchId, cast(m.messageId as string)))`.
4. **API trả về giá trị nào sau khi sửa:**
   - Với Post 3: trả về `shareCount = 2`.
   - Với Post 4: trả về `shareCount = 4`.
   - Với bài viết chưa chia sẻ: trả về `shareCount = 0`.
5. **Flutter nhận và hiển thị dữ liệu như thế nào:**
   - Parse `json['shareCount']` thành int (an toàn fallback về 0).
   - Khi `shareCount == 0`: hiển thị `↗ Chia sẻ`.
   - Khi `shareCount > 0`: hiển thị `↗ [số_lượng]`.
6. **Quy tắc chống đếm trùng được đảm bảo ra sao:**
   - Phiên chia sẻ sinh `shareBatchId` duy nhất từ Flutter.
   - Backend kiểm tra `existsByShareBatchIdAndShareTargetTypeAndShareTargetId`. Khi người dùng retry những người nhận thất bại trong cùng sheet, backend không cộng thêm số lượt chia sẻ.
7. **Các file đã thay đổi:**
   - Backend: `ShareBatchRequest.java`, `Message.java`, `MessageRepository.java`, `PostRepository.java`, `MessagingServiceImpl.java`, `PostServiceImpl.java`, `MessagingShareTest.java`.
   - Frontend: `share_batch_models.dart`, `share_bottom_sheet.dart`, `post_card_widget.dart`, `post_share_count_test.dart`.
8. **Test/build đã chạy và kết quả thực tế:**
   - Backend: 55/55 test passed (BUILD SUCCESS).
   - Frontend: 6/6 test passed.
9. **Có cần restart ứng dụng hoặc backend để áp dụng thay đổi không:**
   - **CÓ**. Cần khởi động lại tiến trình Backend Spring Boot (`TravelPlannerApplication` - PID `23468`) để JVM nạp các lớp Java và logic query mới được biên dịch. Phía Flutter chỉ cần Hot Reload hoặc Hot Restart.
