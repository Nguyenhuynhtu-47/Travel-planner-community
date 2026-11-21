# BÁO CÁO TRIỂN KHAI PHASE 1: CHIA SẺ NỘI DUNG NỘI BỘ QUA HỆ THỐNG MESSAGING

> **Dự án:** Travel Planner Community  
> **Giai đoạn:** Phase 1 – Backend Spring Boot Integration  
> **Branch Git:** `feature/message-sharing`  
> **Ngày hoàn thành:** 21/11/2026  
> **Trạng thái:** Hoàn thành 100% mục tiêu Phase 1 (Toàn bộ 18 test cases passed, 36/36 tests regression passed, 0 error).

---

## 1. Tổng quan & Kiến trúc đã triển khai

Phase 1 hiện thực hóa cơ chế chia sẻ nội dung trong ứng dụng (In-app Sharing) cho **Lịch trình (Itinerary)** và **Bài viết (Post)** trực tiếp thông qua hệ thống Chat / Messaging hiện có của Travel Planner, tuân thủ nghiêm ngặt phương án kiến trúc đã phê duyệt tại `06-in-app-sharing-through-messaging-audit.md`.

### 1.1. Luồng dữ liệu (Data Flow)
```
[User A: Sharer]
       │
       ▼ POST /api/conversations/shares (1..10 recipients, targetType, targetId, note)
┌────────────────────────────────────────────────────────────────────────┐
│ Spring Boot Backend: MessagingServiceImpl.shareContent                 │
│ 1. Validate request (1..10 recipients, rate limit check)               │
│ 2. Authorize content (Owner only if PRIVATE itinerary, author/public)  │
│ 3. Build snapshot metadata JSON (title, cover, subtitle, author)       │
│ 4. Loop recipients (Deterministic user-pair locking):                  │
│    ├─ Check self-share & friendship/block permissions                  │
│    ├─ Get or create Conversation & ReadState                           │
│    ├─ If PRIVATE Itinerary -> grant ItineraryAccessGrant (ACTIVE)      │
│    ├─ Save Message (messageType=SHARE, snapshot JSON)                  │
│    ├─ Update conversation monotonic sequenceNumber & lastMessageAt     │
│    └─ Publish STOMP WebSocket CommittedChatEvent                       │
└────────────────────────────────────────────────────────────────────────┘
       │
       ▼
[User B: Recipient receives card in chat]
       │
       ├─► Read PRIVATE Itinerary Detail -> Authorized by ACTIVE Access Grant
       ├─► Clone PRIVATE Itinerary -> Authorized by ACTIVE Access Grant
       └─► Edit/Delete PRIVATE Itinerary -> 403 Forbidden (Strictly READ-ONLY)
```

---

## 2. Chi tiết các thay đổi Source Code & Database

### 2.1. Mở rộng Data Model `Message`
- **File:** `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/Message.java`
- **Thêm các trường mới:**
  - `messageType`: Enum `MessageType` (`TEXT`, `SHARE`), default `TEXT`, `@Column(name = "message_type", nullable = false, length = 16)`.
  - `shareTargetType`: Enum `ShareTargetType` (`ITINERARY`, `POST`), `@Column(name = "share_target_type", length = 16)`.
  - `shareTargetId`: `@Column(name = "share_target_id")` (`Long`).
  - `shareMetadata`: `@Column(name = "share_metadata", columnDefinition = "TEXT")` (lưu trữ snapshot JSON của card).
- **Index:** Đã thêm `@Index(name = "idx_messages_share_target", columnList = "share_target_type,share_target_id")`.
- **Tương thích ngược:** Toàn bộ tin nhắn cũ tự động mang giá trị `messageType = TEXT` với các trường share là null.

### 2.2. Phân hệ `ItineraryAccessGrant`
- **Entity:** `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/ItineraryAccessGrant.java`
  - Các trường: `grantId`, `itinerary`, `grantee`, `grantedBy`, `status` (`GrantStatus`: `ACTIVE`, `REVOKED`), `createdAt`, `revokedAt`.
  - Constraint: `@UniqueConstraint(name = "uk_itinerary_access_grant", columnNames = {"itinerary_id", "grantee_user_id"})`. Đảm bảo mỗi người dùng chỉ có 1 grant duy nhất cho 1 itinerary, không tạo bản ghi trùng lặp khi chia sẻ đồng thời.
- **Repository:** `ItineraryAccessGrantRepository.java`
  - `findByItinerary_ItineraryIdAndGrantee_UserId`
  - `existsByItinerary_ItineraryIdAndGrantee_UserIdAndStatus`
- **Service & Implementation:** `ItineraryAccessGrantService.java` & `ItineraryAccessGrantServiceImpl.java`
  - `grantAccess(Itinerary itinerary, User grantee, User grantedBy)`: Cấp quyền hoặc kích hoạt lại (nếu đã bị `REVOKED` trước đó).
  - `revokeAccess(Integer itineraryId, Integer granteeUserId, String currentUsername)`: Chỉ chủ sở hữu (`isOwner`) mới có quyền thu hồi, chuyển status thành `REVOKED` và set `revokedAt = now()`.
  - `hasActiveGrant(Integer itineraryId, Integer granteeUserId)`: Kiểm tra quyền đọc có hiệu lực.

### 2.3. Củng cố phân quyền Itinerary (Authorization Hardening)
- **`ItineraryServiceImpl.java`:**
  - `getItineraryDetail(Integer id, String currentUsername)`: Kiểm tra nếu `itinerary.getVisibility() != Visibility.PUBLIC`, cho phép truy cập nếu là owner HOẶC `accessGrantService.hasActiveGrant(id, user.getUserId())`.
  - `cloneItinerary(Integer id, String currentUsername)`: Người nhận có grant `ACTIVE` được phép clone lịch trình riêng tư. Khi grant bị `REVOKED`, lập tức chặn với `403 Forbidden`.
  - `updateItinerary` & `deleteItinerary`: Vẫn sử dụng `findOwnedItinerary`, nghiêm ngặt chỉ cho phép owner chỉnh sửa hoặc xóa. Người được chia sẻ chỉ có quyền `READ-ONLY`, nếu cố gọi API sửa/xóa sẽ nhận `403 Forbidden`.
- **`RouteServiceImpl.java` & `ItineraryPlaceServiceImpl.java`:**
  - Cập nhật kiểm tra quyền đọc lịch trình private: cho phép truy vấn địa điểm đã lưu và tính toán lộ trình nếu người xem có `ACTIVE` grant.

### 2.4. Batch Share API (`POST /api/conversations/shares`)
- **Controller:** `ConversationController.java` (`@PostMapping("/shares")` trả về HTTP 201 Created).
- **Service Implementation:** `MessagingServiceImpl.java`
  - Validation: 1 đến 10 recipients mỗi request, kiểm tra rate limiter `ChatRateLimiter`.
  - Snapshot JSON: Sinh server-controlled snapshot (`title`, `coverImage`, `subtitle`, `authorName`, `authorAvatar`, `visibility`, `status`). Tuyệt đối không chứa dữ liệu nhạy cảm.
  - Xử lý từng recipient:
    - Nếu gửi cho chính mình (`recipientId == actorId`) -> Báo lỗi `SELF_SHARE` trên item mà không làm hỏng các item khác.
    - Nếu bị chặn hoặc không nhận tin từ người lạ -> Báo lỗi `PERMISSION_DENIED` trên item.
    - Lock user-pair theo thứ tự `(min, max)` và lock conversation để tránh race condition sequence number.
    - Tự động tạo `ItineraryAccessGrant` với status `ACTIVE` nếu là `PRIVATE` itinerary.
    - Tạo `Message` với `MessageType.SHARE`, cập nhật `lastMessageSequence`, `lastMessage`, `lastMessageAt`.
    - Bắn realtime event `CommittedChatEvent` qua WebSocket STOMP.

### 2.5. Thu hồi quyền truy cập (`DELETE /api/itineraries/{id}/access-grants/{granteeUserId}`)
- **Controller:** `ItineraryController.java`
- Xử lý: Kiểm tra caller phải là chủ sở hữu itinerary, chuyển trạng thái grant sang `REVOKED` và ghi nhận timestamp `revokedAt`.

---

## 3. Danh sách File Tạo Mới & Chỉnh Sửa

| STT | File | Trạng thái | Mô tả |
|-----|------|------------|-------|
| 1 | `.../model/enums/MessageType.java` | Tạo mới | Enum `TEXT`, `SHARE` |
| 2 | `.../model/enums/ShareTargetType.java` | Tạo mới | Enum `ITINERARY`, `POST` |
| 3 | `.../model/enums/GrantStatus.java` | Tạo mới | Enum `ACTIVE`, `REVOKED` |
| 4 | `.../model/ItineraryAccessGrant.java` | Tạo mới | JPA Entity lưu trữ quyền đọc lịch trình private |
| 5 | `.../repository/ItineraryAccessGrantRepository.java` | Tạo mới | Repository JPA truy vấn grant |
| 6 | `.../service/ItineraryAccessGrantService.java` | Tạo mới | Interface quản lý grant |
| 7 | `.../service/impl/ItineraryAccessGrantServiceImpl.java` | Tạo mới | Implementation cấp, thu hồi, kiểm tra grant |
| 8 | `.../dto/request/ShareBatchRequest.java` | Tạo mới | Request DTO chia sẻ hàng loạt (1..10 recipients) |
| 9 | `.../dto/response/ShareMetadataDto.java` | Tạo mới | Snapshot metadata DTO |
| 10 | `.../dto/response/ShareBatchItemResponse.java` | Tạo mới | Kết quả chia sẻ chi tiết cho từng recipient |
| 11 | `.../dto/response/ShareBatchResponse.java` | Tạo mới | Response tổng hợp của batch share |
| 12 | `.../model/Message.java` | Chỉnh sửa | Bổ sung các cột share và composite index |
| 13 | `.../dto/response/MessageResponse.java` | Chỉnh sửa | Mở rộng response trả về client các trường share |
| 14 | `.../service/MessagingService.java` | Chỉnh sửa | Khai báo method `shareContent` |
| 15 | `.../service/impl/MessagingServiceImpl.java` | Chỉnh sửa | Hiện thực logic `shareContent`, helper snapshot & locking |
| 16 | `.../controller/ConversationController.java` | Chỉnh sửa | Endpoint `POST /api/conversations/shares` |
| 17 | `.../controller/ItineraryController.java` | Chỉnh sửa | Endpoint `DELETE /api/itineraries/{id}/access-grants/{granteeUserId}` |
| 18 | `.../service/impl/ItineraryServiceImpl.java` | Chỉnh sửa | Phân quyền đọc & clone private itinerary dựa trên grant |
| 19 | `.../service/impl/RouteServiceImpl.java` | Chỉnh sửa | Kiểm tra quyền truy cập route khi có grant |
| 20 | `.../service/impl/ItineraryPlaceServiceImpl.java` | Chỉnh sửa | Kiểm tra quyền truy cập địa điểm khi có grant |
| 21 | `.../MessagingShareTest.java` | Tạo mới | Bộ unit test toàn diện gồm 18 ca kiểm thử |
| 22 | `docs/ai/09-development-log.md` | Chỉnh sửa | Ghi log kỹ thuật Phase 1 bằng tiếng Anh |
| 23 | `docs/plan/07-in-app-sharing-phase-1-implementation-report.md` | Tạo mới | Báo cáo chi tiết Phase 1 |

---

## 4. Kết quả Kiểm thử (Verification & Test Suite)

Bộ kiểm thử `MessagingShareTest.java` bao phủ đầy đủ toàn bộ 18 kịch bản bắt buộc theo đặc tả:

| Case | Tên kiểm thử | Mô tả kịch bản | Kết quả |
|:----:|--------------|----------------|:-------:|
| 1 | `test1_sharePublicItinerary_success` | Chia sẻ PUBLIC itinerary -> thành công, snapshot metadata tạo đúng, không cần grant | **PASSED** |
| 2 | `test2_sharePrivateItinerary_byOwner_success_andGrantCreated` | Chia sẻ PRIVATE itinerary bởi chính chủ sở hữu -> thành công, cấp grant ACTIVE | **PASSED** |
| 3 | `test3_shareValidPost_success` | Chia sẻ Post hợp lệ -> thành công, snapshot chứa ảnh đại diện, tác giả và trích đoạn | **PASSED** |
| 4 | `test4_shareNonExistentContent_throws404` | Chia sẻ nội dung không tồn tại -> báo lỗi 404 ResourceNotFoundException | **PASSED** |
| 5 | `test5_nonOwnerSharePrivateItinerary_throws403` | Non-owner cố tình chia sẻ PRIVATE itinerary -> báo lỗi 403 ForbiddenException | **PASSED** |
| 6 | `test6_recipientBlocked_failsItemWithoutFailingBatch` | Người nhận bị chặn/không nhận tin -> item báo lỗi, batch vẫn hoàn tất | **PASSED** |
| 7 | `test7_batchMixedRecipients_partialSuccess` | Chia sẻ hàng loạt hỗn hợp (hợp lệ + tự gửi cho mình + bị chặn) -> trả về trạng thái từng item chính xác | **PASSED** |
| 8 | `test8_batchExceedingTenRecipients_throws400` | Chia sẻ vượt quá 10 người nhận -> validation lỗi 400 BadRequestException | **PASSED** |
| 9 | `test9_revokeAccessGrant_byOwner_success` | Thu hồi Access Grant bởi owner -> grant chuyển sang REVOKED và ghi nhận revokedAt | **PASSED** |
| 10 | `test10_readPrivateItineraryAfterGrantRevoked_throws404` | Đọc PRIVATE itinerary sau khi grant bị REVOKED -> bị chặn 404 | **PASSED** |
| 11 | `test11_clonePrivateItinerary_whenGrantActive_success` | Clone PRIVATE itinerary khi grant còn ACTIVE -> thành công | **PASSED** |
| 12 | `test12_clonePrivateItinerary_whenGrantRevoked_throws403` | Clone PRIVATE itinerary sau khi grant bị REVOKED -> bị chặn 403 Forbidden | **PASSED** |
| 13 | `test13_nonOwnerWithGrant_updateOrDeleteItinerary_throws403` | Người được cấp grant cố tình sửa/xóa itinerary -> bị chặn 403 (chỉ có quyền READ-ONLY) | **PASSED** |
| 14 | `test14_legacyTextMessage_sentAndReadNormally` | Tin nhắn TEXT thường gửi và đọc bình thường, không bị ảnh hưởng bởi các trường share | **PASSED** |
| 15 | `test15_realtimeEventPublished_withCorrectPayload` | Realtime event STOMP WebSocket được publish đúng payload và đúng người nhận | **PASSED** |
| 16 | `test16_monotonicSequenceNumbers_andUnreadTracking` | Sequence number tăng đơn điệu, conversation cập nhật lastMessage chính xác | **PASSED** |
| 17 | `test17_concurrentShare_idempotentGrantActivation` | Chia sẻ lặp lại kích hoạt lại grant cũ an toàn, không vi phạm unique constraint | **PASSED** |
| 18 | `test18_shareDeletedOrHiddenPost_throwsError` | Bài viết bị ẩn hoặc đã xóa -> từ chối chia sẻ với lỗi 404 | **PASSED** |

### Kết quả chạy kiểm thử toàn bộ Messaging Suite:
```
[INFO] Running Travel_Planner.Travel_Planner.ChatEventListenerTest (2 tests) - PASSED
[INFO] Running Travel_Planner.Travel_Planner.ChatRateLimiterTest (1 test) - PASSED
[INFO] Running Travel_Planner.Travel_Planner.FriendshipPrivacyServiceTest (3 tests) - PASSED
[INFO] Running Travel_Planner.Travel_Planner.MessageRequestServiceTest (11 tests) - PASSED
[INFO] Running Travel_Planner.Travel_Planner.MessagingSettingsServiceTest (1 test) - PASSED
[INFO] Running Travel_Planner.Travel_Planner.MessagingShareTest (18 tests) - PASSED
[INFO] 
[INFO] Results:
[INFO] Tests run: 36, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

---

## 5. Kết luận & Sẵn sàng cho Phase 2 (Flutter Mobile)

Phase 1 đã hoàn thành đầy đủ toàn bộ yêu cầu Backend theo đúng nguyên tắc:
1. **Không can thiệp Flutter Mobile trong Phase 1:** Toàn bộ code Flutter giữ nguyên vẹn 100%.
2. **Không commit / push Git:** Giữ nguyên working tree sạch và tách bạch trên branch `feature/message-sharing`.
3. **Độ ổn định cao:** Bảo đảm backward compatibility cho hệ thống nhắn tin hiện có, cô lập lỗi batch, và bảo mật thông tin snapshot.
4. **Sẵn sàng cho Phase 2:** Backend đã sẵn sàng cung cấp các endpoint `POST /api/conversations/shares` và `DELETE /api/itineraries/{id}/access-grants/{granteeUserId}`, cũng như WebSocket event `MESSAGE_CREATED` để Mobile Client hiển thị card chia sẻ và điều hướng người dùng khi nhấn vào card.
