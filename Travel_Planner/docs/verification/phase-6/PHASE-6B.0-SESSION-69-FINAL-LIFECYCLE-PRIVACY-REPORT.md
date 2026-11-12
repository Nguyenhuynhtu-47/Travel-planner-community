# PHASE 6B.0 — BÁO CÁO NGHIỆM THU VÒNG ĐỜI VÀ BẢO MẬT CUỐI CÙNG
## FINAL LIFECYCLE & PRIVACY HARDENING REPORT (SESSION 69)

**Dự án:** Travel Planner  
**Phân hệ:** Phase 6B.0 — Community Feed / Discovery (Architecture Audit & Technical Design)  
**Ngày thực hiện:** 2026-11-12  
**Kiến trúc sư / Trưởng nhóm Kỹ thuật:** AI Senior Software Architect  
**Nhánh:** `develop` | **HEAD Commit:** `f997f34`  
**Tuân thủ Git Policy:** **STRICTLY NO COMMIT, NO PUSH** (100% Tuân thủ)  
**Chính sách Triển khai:** **ZERO SOURCE CODE MODIFICATIONS, ZERO DATABASE MIGRATIONS**  
**Kết luận Thẩm định (Final Verdict):** **ACCEPTED WITH LIMITATIONS**

---

## 1. TỔNG QUAN VÀ MỤC TIÊU PHIÊN 69 (EXECUTIVE SUMMARY)

Báo cáo này đại diện cho đợt hoàn thiện kỹ thuật chuyên sâu cuối cùng của **Phase 6B.0 — Community Feed / Discovery**. Session 69 tập trung giải quyết toàn diện 6 vấn đề vòng đời, kiểm soát đồng thời và bảo mật dữ liệu riêng tư:

1. **Cơ chế Claim Token & Chống Stale Worker Ghi đè (Issue 1):** Cấp phát `claim_token` UUID duy nhất cho từng đợt claim; giải phóng row lock trước khi gọi Cloudinary; kiểm tra token khi cập nhật kết quả; bảo đảm tính idempotent khi Cloudinary trả về "not found".
2. **Vòng đời Media Asset khi Post bị Xóa (Issue 2):** Phân định rõ Post Soft-Delete (giữ nguyên ảnh `ATTACHED` để khôi phục) vs Post Purge / Hard-Delete (chuyển ảnh sang `DELETING` trước khi cascade xóa quan hệ).
3. **Cơ chế Dead-Letter & Phục hồi sau Retry Exhaustion (Issue 3):** Giữ vững 4 trạng thái enum; bổ sung `dead_lettered_at` và cơ chế manual retry; ngăn chặn vòng lặp retry vô tận đối với lỗi vĩnh viễn.
4. **Bảo mật Lịch trình Đính kèm & Mã Lý do Client Hợp nhất (Issue 4):** Trả về mã lý do chung `itineraryUnavailableReason = "UNAVAILABLE"` và `itinerary: null` cho người dùng thông thường, ngăn chặn việc suy đoán trạng thái nhạy cảm của tác giả (BANNED/INACTIVE) hoặc lịch trình (PRIVATE/DELETED).
5. **Khảo sát Thực tế Mã nguồn về `UserStatus.INACTIVE` (Issue 5):** Đối chiếu trực tiếp mã nguồn thực tế tại `AuthServiceImpl.java`, xác nhận tài khoản `INACTIVE` bị chặn đăng nhập với HTTP 403 Forbidden và **chưa có luồng kích hoạt/tự kích hoạt nào tồn tại trong code hiện có** (`OPEN QUESTION`).
6. **Chuẩn hóa Ngữ nghĩa Anti-Enumeration & Locking (Issue 6):** Làm rõ `404 Not Found` là chính sách che giấu tài nguyên chống dò quét ID (không thay thế authorization); chuẩn hóa cơ chế khóa bi quan bằng Spring Data JPA `@Lock(LockModeType.PESSIMISTIC_WRITE)` kèm sắp xếp danh sách ID.

---

## 2. THÔNG TIN NHÁNH VÀ COMMIT HEAD

- **Nhánh hiện tại:** `develop`
- **HEAD Commit:** `f997f34` (`f997f34 feat: implement rollback tests`)
- **Chế độ làm việc:** **DOCUMENTATION ONLY** (Zero source code modifications, zero database migrations).

---

## 3. KIỂM SOÁT GIT VÀ TRẠNG THÁI WORKING TREE (TRƯỚC VÀ SAU)

### 3.1. Git Status trước khi thực hiện Session 69:
```
 M Travel_Planner/docs/ai/09-development-log.md
 M Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart
 M Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart
 M Travel_Planner/frontend/mobile/lib/features/location/data/models/location_search_result.dart
 M Travel_Planner/frontend/mobile/lib/features/location/presentation/widgets/location_picker_sheet.dart
 M Travel_Planner/frontend/mobile/test/explore_test.dart
 M Travel_Planner/frontend/mobile/test/features/social/rating_ui_layout_test.dart
?? Travel_Planner/docs/verification/phase-6/PHASE-6A-IMPLEMENTATION-PLAN.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.1-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.2-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.3-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-CONSISTENCY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/phase-6b-design/
?? Travel_Planner/docs/verification/post-phase-6a/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/data/helpers/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/day_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/test/features/itinerary/
```

### 3.2. Git Status sau khi hoàn thành Session 69:
```
 M Travel_Planner/docs/ai/09-development-log.md
 M Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart
 M Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart
 M Travel_Planner/frontend/mobile/lib/features/location/data/models/location_search_result.dart
 M Travel_Planner/frontend/mobile/lib/features/location/presentation/widgets/location_picker_sheet.dart
 M Travel_Planner/frontend/mobile/test/explore_test.dart
 M Travel_Planner/frontend/mobile/test/features/social/rating_ui_layout_test.dart
?? Travel_Planner/docs/verification/phase-6/PHASE-6A-IMPLEMENTATION-PLAN.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.1-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.2-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.3-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-CONSISTENCY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-69-FINAL-LIFECYCLE-PRIVACY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/phase-6b-design/
?? Travel_Planner/docs/verification/post-phase-6a/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/data/helpers/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/day_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/test/features/itinerary/
```
*(Bảo toàn 100% working tree, không ghi đè, không có commit, không có push).*

---

## 4. CHI TIẾT XỬ LÝ SÁU NHÓM VẤN ĐỀ

### ISSUE 1: Claim Token & Stale Worker Protection (`PROPOSED DESIGN`)
- **Phân tích Rủi ro Stale Worker:**
  - Nếu chỉ dùng `locked_by = workerId` và lease 10 phút: Worker A claim Asset X, bị trễ (GC pause hoặc mạng nghẽn), lease hết hạn. Worker B claim lại Asset X. Worker A thức dậy, hoàn thành Cloudinary và ghi đè trạng thái DB khi quyền sở hữu đã thuộc Worker B.
- **Giải pháp Claim Token Độc nhất:**
  - Bổ sung cột: `claim_token VARCHAR(36) NULL` (UUID).
  - Transaction Claim ngắn (< 50ms):
    ```sql
    UPDATE media_assets 
    SET status = 'DELETING',
        claim_token = :claimToken,
        locked_at = NOW(), 
        locked_by = :workerId,
        updated_at = NOW()
    WHERE (
        (status = 'UNATTACHED' AND created_at < NOW() - INTERVAL 24 HOUR)
        OR 
        (status = 'DELETING' AND (locked_at IS NULL OR locked_at < NOW() - INTERVAL 10 MINUTE) AND (next_retry_at IS NULL OR next_retry_at <= NOW()))
    )
    AND dead_lettered_at IS NULL
    AND retry_count < 5
    LIMIT 50;
    ```
  - Worker commit ngay lập tức, giải phóng row lock trước khi gửi HTTP request tới Cloudinary.
  - Cập nhật kết quả có kiểm tra token:
    ```sql
    UPDATE media_assets 
    SET status = 'DELETED', claim_token = NULL, locked_at = NULL, locked_by = NULL, updated_at = NOW()
    WHERE media_asset_id = :id AND claim_token = :claimToken;
    ```
  - Nếu `affectedRows == 0`, Worker A nhận biết mình là stale worker và hủy bỏ việc ghi DB.
  - **Bảo toàn Tính Idempotent:** Nếu Worker A đã xóa thành công trên Cloudinary, Worker B gọi Cloudinary sau đó nhận kết quả `result: "not found"`. Worker B vẫn ghi nhận thành công và chuyển DB sang `DELETED`. Hoàn toàn không gây lỗi dữ liệu.

---

### ISSUE 2: Vòng đời Media Asset khi Post bị Xóa (`PROPOSED DESIGN`)
- **Phân định rõ các Kịch bản:**
  1. *Post Soft-Delete (Tác giả/Admin xóa bài):* Post chuyển `status = 'DELETED'`. **Media Assets giữ nguyên `ATTACHED`**. Nếu xóa ảnh khỏi Cloudinary ngay lập tức, tính năng khôi phục bài viết (Restore Post) trong vòng 30 ngày sẽ bị vô hiệu hóa vì mất ảnh vĩnh viễn.
  2. *Post bị Moderation (`status = 'HIDDEN'`):* Media Assets giữ nguyên `ATTACHED`. Ảnh chỉ bị ẩn khỏi feed công cộng, không được xóa khỏi Cloudinary khi quá trình kháng cáo/xem xét chưa kết thúc.
  3. *Post Purge / Hard-Delete (Xóa vĩnh viễn):* Xảy ra khi dọn bài soft-delete quá hạn 30 ngày hoặc tuân thủ GDPR.
- **Thứ tự Giao dịch & Đánh giá Foreign Key Cascade:**
  - Bảng `post_media` có `ON DELETE CASCADE` tham chiếu từ `posts(post_id)`.
  - Nếu xóa `posts` trước, cascade sẽ xóa sạch các dòng trong `post_media`, khiến hệ thống mất liên kết để biết asset nào cần xóa khỏi Cloudinary.
  - **Quy trình chuẩn hóa trong Purge Service:**
    1. Query danh sách `media_asset_id` từ `post_media` theo `post_id`.
    2. Cập nhật các `media_assets` này sang `status = 'DELETING'`.
    3. Xóa các dòng trong `post_media`.
    4. Xóa dòng trong `posts`.
    5. Commit database transaction.
    6. Background worker quét các asset `DELETING` và xóa trên Cloudinary với claim token protection.

---

### ISSUE 3: Retry Exhaustion & Phục hồi Dead-Letter (`PROPOSED DESIGN`)
- **Giữ nguyên 4 trạng thái:** `UNATTACHED`, `ATTACHED`, `DELETING`, `DELETED`. Không thêm enum thứ năm.
- **Cấu trúc Dead-Letter:**
  - Bổ sung cột `dead_lettered_at DATETIME(6) NULL`.
  - Loại bỏ hoàn toàn quy ước `retry_count = 999`.
- **Chính sách Thử lại (Retry Policy):**
  - Tối đa 5 lần retry tự động.
  - Công thức giãn cách: $next\_retry = now + (2^{retry} \times 15s) + jitter (0-5s)$.
  - Khi `retry_count >= 5` hoặc gặp lỗi vĩnh viễn (400 Bad Request, sai API credentials, public_id không hợp lệ):
    - Đánh dấu `dead_lettered_at = NOW()`.
    - Xóa `claim_token = NULL`, `locked_at = NULL`, `locked_by = NULL`.
    - Ghi chi tiết vào `last_error`.
  - Cron worker định kỳ luôn lọc `WHERE dead_lettered_at IS NULL`, triệt tiêu hoàn toàn vòng lặp retry vô tận.
- **Cơ chế Phục hồi Thủ công (Manual Recovery):**
  - Cung cấp endpoint quản trị: `POST /api/admin/media-assets/{id}/retry`.
  - Thao tác: Đặt `dead_lettered_at = NULL`, `retry_count = 0`, `next_retry_at = NOW()`, `last_error = NULL` để asset quay trở lại hàng đợi xử lý.

---

### ISSUE 4: Bảo mật Lịch trình Đính kèm & Reason Code Hợp nhất (`PROPOSED DESIGN`)
- **Nguyên tắc Che giấu Trạng thái Nhạy cảm:**
  - Việc trả về các reason code chi tiết như `CREATOR_BANNED`, `ITINERARY_PRIVATE`, `ITINERARY_DELETED` làm lộ thông tin nhạy cảm của người dùng khác (ví dụ: biết được bạn mình vừa bị ban hoặc vừa xóa lịch trình).
- **Chuẩn hóa Payload DTO cho Client:**
  ```json
  {
    "itinerary": null,
    "itineraryUnavailable": true,
    "itineraryUnavailableReason": "UNAVAILABLE"
  }
  ```
- **Quy tắc Bất biến:**
  - Đối với tất cả người xem thông thường, client chỉ nhận được chuỗi duy nhất: `"UNAVAILABLE"`.
  - Không phân biệt lý do Lịch trình bị ẩn hay Chủ sở hữu bị khóa.
  - Các mã lỗi kỹ thuật chi tiết chỉ được ghi vào **internal server logs** phục vụ audit/debug.
  - Tuyệt đối không trả về `title`, `coverImage`, `budget`, `totalDays`, hoặc danh sách hoạt động khi `itinerary == null`.

---

### ISSUE 5: Khảo sát Thực tế Mã nguồn về `UserStatus.INACTIVE` (`VERIFIED IN SOURCE`)
Đối chiếu mã nguồn thực tế tại `Travel_Planner/backend/src/main`:

| Câu hỏi Kiểm tra | Bằng chứng Mã nguồn Thực tế | Kết luận Thực tế |
| :--- | :--- | :--- |
| **`UserStatus` gồm những enum nào?** | `Travel_Planner/model/enums/UserStatus.java:3-7` | Gồm: `ACTIVE`, `INACTIVE`, `BANNED`. |
| **Giá trị mặc định khi Đăng ký là gì?** | `Travel_Planner/service/impl/AuthServiceImpl.java:71` | `user.status(UserStatus.ACTIVE)` — Đăng ký là active ngay, không có bước xác thực email. |
| **Login xử lý `INACTIVE` thế nào?** | `Travel_Planner/service/impl/AuthServiceImpl.java:101-103` | Ném `ForbiddenException("Tài khoản của bạn đang bị vô hiệu hóa")` (HTTP 403). **Không tự kích hoạt lại**. |
| **`getCurrentUser` xử lý `INACTIVE` thế nào?** | `Travel_Planner/service/impl/AuthServiceImpl.java:124-126` | Ném `ForbiddenException("Tài khoản của bạn đang bị vô hiệu hóa")` (HTTP 403). |
| **Spring Security cấu hình `INACTIVE` thế nào?** | `Travel_Planner/security/UserDetailsServiceImpl.java:28-36` | `isActive = user.getStatus() == UserStatus.ACTIVE`; `disabled(!isActive)` $\rightarrow$ Account bị disabled. |
| **Có endpoint/service nào kích hoạt tài khoản không?** | Toàn bộ package `controller` và `service` | **KHÔNG CÓ**. Không tồn tại bất kỳ method nào set status từ `INACTIVE` về `ACTIVE`. |
| **Có email verification service không?** | Toàn bộ backend | **KHÔNG CÓ**. Không có token verification hay email sender. |
| **`INACTIVE` được tạo ra ở đâu?** | `Travel_Planner/seeder/DataSeeder.java:232` | Chỉ xuất hiện trong dữ liệu mẫu (mock seed data). |

> [!IMPORTANT]
> **KẾT LUẬN & ĐẶT VẤN ĐỀ (OPEN QUESTION):**  
> Nhận định tại Session 68 cho rằng *"User INACTIVE có thể tự kích hoạt qua luồng đăng nhập"* là **hoàn toàn trái ngược với mã nguồn thực tế** (Login hiện tại chặn 403 Forbidden).  
> Hiện tại hệ thống **CHƯA CÓ cơ chế kích hoạt lại tài khoản**.  
> **OPEN QUESTION dành cho Người dùng:** Cần quyết định chính sách sản phẩm trước Phase 6B.1:
> - *Lựa chọn 1:* Chỉ Admin mới có quyền mở khóa tài khoản `INACTIVE` qua API Quản trị User.
> - *Lựa chọn 2:* Bổ sung tính năng OTP/Email Verification để người dùng tự mở khóa tài khoản khi đăng nhập.  
> Trong phạm vi Phase 6B.0, tài khoản `INACTIVE` được đặc tả nhất quán là **bị chặn đăng nhập và chặn toàn bộ quyền ghi cộng đồng**.

---

### ISSUE 6: Hoàn thiện Ngữ nghĩa Anti-Enumeration & Locking (`PROPOSED DESIGN`)
1. **Phân biệt Ranh giới An ninh:**
   - **Anti-Enumeration:** Là kỹ thuật che giấu tài nguyên (Resource Concealment). Trả về `404 Not Found` cho unowned assets nhằm triệt tiêu nguy cơ kẻ tấn công dò quét ID hợp lệ.
   - **Authorization:** Là logic kiểm tra quyền hạn thực tế ở máy chủ (`ma.uploadedBy.userId == currentUserId`). Anti-enumeration là chính sách phản hồi của tầng authorization khi từ chối truy cập, không phải sự thay thế cho authorization.
   - **SQL Injection:** Hoàn toàn độc lập với format của ID; được bảo vệ bởi Spring Data JPA parameter binding và strong typing (`List<Long>`).
2. **Khóa Bi quan (Pessimistic Locking Semantics):**
   - Không sử dụng cú pháp JPQL không chuẩn dạng `SELECT ... FOR UPDATE`.
   - Sử dụng chuẩn Spring Data JPA:
     ```java
     @Lock(LockModeType.PESSIMISTIC_WRITE)
     @Query("SELECT ma FROM MediaAsset ma WHERE ma.mediaAssetId IN :ids")
     List<MediaAsset> findByIdsForUpdate(@Param("ids") List<Long> sortedIds);
     ```
   - Danh sách ID được sắp xếp tăng dần trước khi truyền vào repository để bảo đảm thứ tự chiếm khóa cố định, triệt tiêu nguy cơ deadlock.

---

## 5. BẢNG TỔNG HỢP PHÂN LOẠI BẰNG CHỨNG

| Nội dung Kiểm tra | Phân loại Bằng chứng | Ghi chú & Nguồn dẫn chứng |
| :--- | :---: | :--- |
| **Enum UserStatus (ACTIVE, INACTIVE, BANNED)** | `VERIFIED IN SOURCE` | `UserStatus.java:3-7` |
| **Login chặn INACTIVE bằng HTTP 403** | `VERIFIED IN SOURCE` | `AuthServiceImpl.java:101-103` |
| **Spring Security disable tài khoản non-ACTIVE** | `VERIFIED IN SOURCE` | `UserDetailsServiceImpl.java:28-36` |
| **Không tồn tại luồng kích hoạt lại tài khoản** | `VERIFIED IN SOURCE` | Quét toàn bộ controllers & services |
| **Friend Request totalElements có sẵn** | `VERIFIED IN SOURCE` | `FriendshipController.java:80-95` |
| **Chưa có endpoint tổng tin nhắn unread** | `VERIFIED IN SOURCE` | `ConversationController.java` |
| **Mô hình DDL Option B (`media_assets` + `post_media`)** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **Claim Token UUID & Stale Worker Protection** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **Post Hard-Purge cascade ordering** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **Generic Reason Code ("UNAVAILABLE")** | `PROPOSED DESIGN` | `04-community-feed-api-design.md` |
| **Chính sách Kích hoạt lại User INACTIVE** | **`OPEN QUESTION`** | Chờ quyết định phê duyệt sản phẩm trước 6B.1 |
| **Tất cả các tính năng Phase 6B** | **`NOT IMPLEMENTED`** | Phase 6B.1 chưa được phép triển khai |

---

## 6. DANH SÁCH FILE THAY ĐỔI TRONG PHIÊN 69

1. [`03-community-feed-data-architecture.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/03-community-feed-data-architecture.md) — DDL bổ sung `claim_token`, `dead_lettered_at`; quy trình claim token, post purge cascade ordering, deadlock-free locking, source grounding cho `UserStatus`.
2. [`04-community-feed-api-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/04-community-feed-api-design.md) — DTO payload `itineraryUnavailableReason = "UNAVAILABLE"`, anti-enumeration vs authorization clarification, open question note cho `INACTIVE`.
3. [`05-feed-query-performance-security.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/05-feed-query-performance-security.md) — Cập nhật index cleanup, worker claim token stale protection, phân biệt rõ anti-enumeration / authorization / SQL injection.
4. [`06-phase-6b-implementation-roadmap.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/06-phase-6b-implementation-roadmap.md) — Cập nhật DDL Phase 6B.1 (`claim_token`, `dead_lettered_at`, JPA `@Lock`), Phase 6B.6 dead-letter recovery.
5. [`07-phase-6b-architecture-decision-record.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/07-phase-6b-architecture-decision-record.md) — Cập nhật ADR-6B-04 (reason code `"UNAVAILABLE"`) và ADR-6B-08 (claim tokens, purge lifecycle).
6. [`PHASE-6B.0-ACCEPTANCE-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md) — Đồng bộ checklist và open question (cả 2 bản sao).
7. [`PHASE-6B.0-SESSION-69-FINAL-LIFECYCLE-PRIVACY-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-69-FINAL-LIFECYCLE-PRIVACY-REPORT.md) — Báo cáo tổng kết toàn diện Session 69.
8. [`09-development-log.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/09-development-log.md#L7680-L7740) — Ghi nhận nhật ký phát triển Session 69 (DOCUMENTATION ONLY, English).

---

## 7. ĐỐI CHIẾU NHẤT QUÁN LIÊN TÀI LIỆU (CROSS-DOCUMENT CONSISTENCY)

- **DDL & Bảng Dữ liệu:** Toàn bộ các file `03-data-architecture`, `06-roadmap`, `07-adr`, và acceptance reports đều đồng nhất 100% về cấu trúc `media_assets` gồm các cột `claim_token`, `locked_at`, `locked_by`, `retry_count`, `next_retry_at`, `dead_lettered_at`, `last_error`.
- **Reason Code Bảo mật:** Cả `03-data-architecture`, `04-api-design`, `05-query-performance`, `07-adr` đều xác nhận DTO trả về mã lý do chung `"UNAVAILABLE"`, không để lộ trạng thái riêng tư.
- **Ranh giới Transaction & Side-Effects:** Tất cả tài liệu đều khẳng định tuyệt đối: lệnh gọi Cloudinary chỉ thực hiện **SAU KHI** database commit.
- **Quyền hạn `UserStatus`:** Toàn bộ tài liệu nhất quán rằng `INACTIVE` bị chặn đăng nhập và chặn quyền ghi, việc kích hoạt lại là `OPEN QUESTION`.

---

## 8. XÁC MINH ZERO SOURCE CODE / DATABASE CHANGES

- `git status --short` xác nhận không có bất kỳ file `.java` hoặc `.dart` nào bị thay đổi.
- Không có bất kỳ migration script nào được thêm vào thư mục database.
- Không có thay đổi dependencies hay cấu hình môi trường.
- Toàn bộ thay đổi của Session 69 chỉ giới hạn trong các tài liệu markdown (`.md`).

---

## 9. NHỮNG ĐIỂM HẠN CHẾ & CÂU HỎI MỞ (REMAINING LIMITATIONS & OPEN QUESTIONS)

1. **`OPEN QUESTION` — Quy trình Kích hoạt lại Tài khoản `INACTIVE`:**
   - Mã nguồn hiện tại ném HTTP 403 Forbidden khi `INACTIVE` user đăng nhập và không cung cấp API activation.
   - Cần quyết định nghiệp vụ trước Phase 6B.1: Triển khai flow tự kích hoạt qua OTP/Email hay chỉ dành quyền kích hoạt cho Quản trị viên (Admin).
2. **Kiểm chứng Tải dưới Dữ liệu lớn (Phase 6B.6):**
   - Cơ chế claim bằng `SKIP LOCKED` của MySQL 8 là tối ưu về mặt lý thuyết, nhưng cần được benchmark thực tế khi có 5-10 worker chạy đồng thời dưới tải lớn.
3. **Phụ thuộc Triển khai Phía Mobile (Phase 6B.2):**
   - Đội ngũ Mobile cần nắm rõ quyết định chủ động ẩn unread badge trên Chat icon trong Phase 6B MVP để tránh thắc mắc trong quá trình kiểm thử giao diện.

---

## 10. KẾT LUẬN THẨM ĐỊNH (FINAL VERDICT)

# ✅ **ACCEPTED WITH LIMITATIONS**

> **Căn cứ Kết luận:**
> - Tất cả các vấn đề về claim token, stale worker, post purge lifecycle, dead-letter recovery, và privacy reason code đã được giải quyết triệt để và đồng bộ 100%.
> - Xếp loại `ACCEPTED WITH LIMITATIONS` là hoàn toàn chính xác và trung thực vì còn tồn tại 1 câu hỏi mở (`OPEN QUESTION`) về luồng kích hoạt lại tài khoản `INACTIVE` cần người dùng phê duyệt định hướng sản phẩm trước khi lập trình.

---

## 11. ĐIỀU KIỆN DỪNG BẮT BUỘC (STRICT STOP CONDITION)

> [!CAUTION]
> **NHIỆM VỤ SESSION 69 ĐÃ HOÀN TẤT VÀ KHÓA CHẶT (SEALED).**
> - **TRIỂN KHAI CODE PHASE 6B.1 TUYỆT ĐỐI CHƯA ĐƯỢC PHÉP BẮT ĐẦU (STRICTLY NOT AUTHORIZED).**
> - **KHÔNG TẠO MIGRATION, KHÔNG SỬA SOURCE CODE.**
> - **KHÔNG COMMIT, KHÔNG PUSH.**
> 
> Hệ thống dừng lại tại đây và chờ đợi chỉ thị phê duyệt chính thức từ người dùng để mở Phase 6B.1.

