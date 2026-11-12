# PHASE 6B.0 — BÁO CÁO NGHIỆM THU KIỂM SOÁT ĐỒNG THỜI VÀ NHẤT QUÁN VÒNG ĐỜI
## CONCURRENCY & LIFECYCLE CONSISTENCY REPORT (SESSION 70)

**Dự án:** Travel Planner  
**Phân hệ:** Phase 6B.0 — Community Feed / Discovery (Architecture Audit & Technical Design)  
**Ngày thực hiện:** 2026-11-12  
**Kiến trúc sư / Trưởng nhóm Kỹ thuật:** AI Senior Software Architect  
**Nhánh:** `develop` | **HEAD Commit:** `f997f34`  
**Tuân thủ Git Policy:** **STRICTLY NO COMMIT, NO PUSH** (100% Tuân thủ)  
**Chính sách Triển khai:** **DOCUMENTATION ONLY — ZERO SOURCE CODE MODIFICATIONS, ZERO DATABASE MIGRATIONS**  
**Kết luận Thẩm định (Final Verdict):** **ACCEPTED WITH LIMITATIONS**

---

## 1. TỔNG QUAN VÀ MỤC TIÊU PHIÊN 70 (EXECUTIVE SUMMARY)

Báo cáo này đại diện cho đợt hiệu chỉnh kỹ thuật chuyên sâu và đồng bộ tính nhất quán cuối cùng của **Phase 6B.0 — Community Feed / Discovery**. Session 70 tập trung xử lý dứt điểm sáu vấn đề cốt lõi về kiểm soát đồng thời (concurrency), tranh chấp tài nguyên (race conditions), phân loại lỗi dịch vụ ngoài (Cloudinary errors), và hạ mức các khẳng định chưa được kiểm chứng thực tế:

1. **Hiệu chỉnh Nhận định Deadlock trong JPA `@Lock` (Issue 1):** Sửa nhận định chưa chính xác của Session 69 cho rằng việc sắp xếp ID tăng dần trong `IN (:ids)` sẽ triệt tiêu deadlock; phân tích bản chất tập hợp không thứ tự của SQL `IN`, phân định rõ cơ chế khóa giữa luồng Attachment và Worker, thiết lập yêu cầu retry deadlock ở tầng service.
2. **Chuẩn hóa Cơ chế Batch-Level Claim Token (Issue 2):** Xác lập quy trình 7 bước của Cleanup Worker khi xử lý lô (batch tối đa 50 phần tử), giải phóng row lock trước khi gọi Cloudinary, truy vấn lại các entity đã claim qua `claim_token`, ngăn chặn stale worker ghi đè DB, và xử lý kết quả idempotent khi Cloudinary trả về "not found".
3. **Đặc tả Cơ chế Bảo vệ Tranh chấp Attachment / Cleanup (Issue 3):** Xây dựng mục riêng trong Data Architecture phân tích xung đột khi một Asset `UNATTACHED` quá 24h đồng thời được người dùng đính kèm vào Post và bị Worker quét dọn; thiết lập bất biến chuyển trạng thái đơn nhất (single-winner) và bảng ma trận race condition toàn diện.
4. **Phân loại Lỗi Cloudinary & Xử lý Lỗi Cấu hình Hệ thống (Issue 4):** Phân định rạch ròi 6 nhóm lỗi Cloudinary; ngăn chặn việc đưa hàng loạt asset vào dead-letter khi gặp lỗi cấu hình hệ thống (invalid credentials) bằng cơ chế Alert và Circuit Breaker / Pause Worker; loại bỏ magic number `999`.
5. **Chuẩn hóa Invariants Vòng đời Post Purge (Issue 5):** Rà soát thứ tự xóa dữ liệu khi hard-purge để không làm mất dấu media trên Cloudinary; hạ mức các tuyên bố tuyệt đối và xác định rõ ràng các ràng buộc schema (`UNIQUE uk_post_media_asset`).
6. **Hạ mức Khẳng định Vượt quá Bằng chứng (Issue 6):** Rà soát toàn bộ tài liệu Phase 6B.0, thay thế các từ ngữ phóng đại ("triệt tiêu hoàn toàn", "deadlock-free", "tuyệt đối") bằng các mô tả kỹ thuật chuẩn xác, phân loại rõ ràng theo 6 cấp độ bằng chứng.

---

## 2. THÔNG TIN NHÁNH VÀ COMMIT HEAD

- **Nhánh hiện tại:** `develop`
- **HEAD Commit:** `f997f34` (`f997f346f3c536d5bdcf6612fb3f35f6b1774e45`)
- **Chế độ làm việc:** **DOCUMENTATION ONLY** (Zero source code modifications, zero database migrations).

---

## 3. KIỂM SOÁT GIT VÀ TRẠNG THÁI WORKING TREE (TRƯỚC VÀ SAU)

### 3.1. Trạng thái Git trước Session 70:
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

### 3.2. Trạng thái Git sau Session 70:
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
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-70-CONCURRENCY-LIFECYCLE-CONSISTENCY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/phase-6b-design/
?? Travel_Planner/docs/verification/post-phase-6a/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/data/helpers/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/day_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/test/features/itinerary/
```
*(Working tree được bảo toàn 100%, không mất dữ liệu, không có commit, không có push).*

---

## 4. ISSUE 1 — JPA LOCK ORDERING VÀ DEADLOCK SEMANTICS

### 4.1. Hiệu chỉnh Nhận định Kỹ thuật về Deadlock
- **Thiếu sót ở Session 69:** Tuyên bố rằng việc sắp xếp danh sách ID tăng dần (`sortedIds`) trước khi truyền vào `@Lock(LockModeType.PESSIMISTIC_WRITE)` với `IN :ids` sẽ "triệt tiêu nguy cơ deadlock" hoặc "deadlock-free locking".
- **Bản chất Kỹ thuật Chính xác:**
  1. Mệnh đề `IN (:ids)` trong chuẩn SQL là một **vị từ tập hợp không có thứ tự** (unordered set membership).
  2. MySQL Query Optimizer (InnoDB) quyết định thứ tự quét và chiếm khóa dòng (row locks) dựa trên thứ tự vật lý của clustered index (B+Tree PK) hoặc index scan được lựa chọn trong execution plan, chứ không phụ thuộc vào thứ tự các phần tử được sắp xếp trong mảng tham số của Java.
  3. Ngay cả khi thêm `ORDER BY ma.mediaAssetId ASC`, mệnh đề này chỉ đảm bảo thứ tự của **result set trả về client**, chứ không đồng nhất với thứ tự đặt row lock nội bộ của storage engine trong quá trình thực thi câu lệnh SQL.
- **Kết luận:** Sắp xếp ID ở tầng ứng dụng là một biện pháp kỹ thuật tốt giúp **giảm thiểu** xác suất xung đột khóa chéo, nhưng **không thể loại bỏ hoàn toàn nguy cơ deadlock**.

### 4.2. Phân định Rạch ròi Giữa Luồng Attachment và Worker
- **Luồng Asset Attachment (Post Creation):**
  - Thực hiện trong transaction tạo bài viết của người dùng.
  - Sử dụng Spring Data JPA `@Lock(LockModeType.PESSIMISTIC_WRITE)`:
    ```java
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT ma FROM MediaAsset ma WHERE ma.mediaAssetId IN :ids")
    List<MediaAsset> findByIdsForUpdate(@Param("ids") List<Long> sortedIds);
    ```
  - Nạp entity vào Persistence Context để kiểm tra chi tiết các điều kiện nghiệp vụ: uploader ownership, trạng thái `UNATTACHED`, giới hạn $\le 5$ ảnh, không trùng ID.
  - Ánh xạ mã lỗi chính xác theo chuẩn RESTful: `400 Bad Request` (duplicate / vượt quá 5), `404 Not Found` (không tồn tại / unowned theo Anti-Enumeration), `409 Conflict` (đã attached / đang deleting).
  - **Xử lý Deadlock:** Bắt buộc bắt ngoại lệ `CannotAcquireLockException` / `DeadlockLoserDataAccessException` và áp dụng retry giới hạn (`@Retryable(maxAttempts = 3, backoff = @Backoff(delay = 100, multiplier = 2))`).
- **Luồng Cleanup Worker:**
  - Hoạt động trong background cron độc lập, **không dùng chung** chiến lược khóa bi quan của Attachment.
  - Sử dụng conditional atomic batch claim (`SKIP LOCKED`) với transaction ngắn (< 50ms) để không giữ row lock trong lúc gọi mạng ra bên ngoài.

---

## 5. ISSUE 2 — BATCH-LEVEL CLAIM TOKEN

### 5.1. Quyết định Kiến trúc: Batch-Level Claim Token cho MVP
- Trong phạm vi MVP, mỗi đợt quét batch (tối đa 50 phần tử) của Cleanup Worker sinh một chuỗi UUID v4 độc nhất: `claimToken = UUID.randomUUID().toString()`.
- Tất cả các asset được claim trong cùng đợt batch này mang chung giá trị `claim_token`.
- Các đợt claim khác nhau (kể cả trên cùng một worker) bắt buộc phải có `claim_token` khác nhau.

### 5.2. Quy trình 7 Bước Thực thi của Worker
Do MySQL qua JDBC/JPA không hỗ trợ việc câu lệnh `UPDATE ... LIMIT 50` tự động trả về danh sách các bản ghi vừa được cập nhật, worker phải tuân thủ đúng 7 bước:
1. **Sinh Token Batch:** Sinh `claimToken` ngẫu nhiên và định danh worker `workerId`.
2. **Claim Batch bằng Transaction Ngắn (< 50ms):**
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
3. **Commit Transaction Claim Ngay Lập Tức:** Giải phóng toàn bộ row lock trước khi thực hiện bất kỳ lệnh gọi mạng Cloudinary nào.
4. **Truy vấn lại Danh sách Asset Đã Claim:**
   ```sql
   SELECT * FROM media_assets WHERE claim_token = :claimToken;
   ```
5. **Duyệt qua Từng Asset trong Bộ nhớ:** Lấy ra `cloudinary_public_id`.
6. **Gọi API Cloudinary Ngoài Transaction:** `cloudinary.uploader().destroy(publicId)`.
7. **Cập nhật Trạng thái Kết quả có Kiểm tra Đầy đủ 3 Điều kiện:**
   ```sql
   UPDATE media_assets 
   SET status = 'DELETED',
       claim_token = NULL,
       locked_at = NULL,
       locked_by = NULL,
       updated_at = NOW()
   WHERE media_asset_id = :assetId 
     AND claim_token = :claimToken
     AND status = 'DELETING';
   ```

### 5.3. Worker Crash, Lease Expiration & Stale Worker Semantics
- **Bảo vệ Trạng thái DB:** Nếu lease 10 phút hết hạn, worker khác có thể reclaim asset với token mới. Stale worker cũ khi thức dậy cập nhật DB sẽ có `affectedRows == 0`, tự động hủy thao tác ghi đè.
- **Ranh giới Bảo vệ của Token:** Token chỉ bảo vệ **quyền cập nhật trạng thái trong cơ sở dữ liệu**; token **không thể thu hồi** lệnh gọi mạng xóa Cloudinary nếu gói tin HTTP đã gửi đi trên đường truyền.
- **Idempotency:** Nếu worker cũ đã xóa trên Cloudinary, worker mới gọi Cloudinary nhận `result: "not found"`, xem là thành công (Idempotent Success) và chuyển DB sang `DELETED`. Không gây lỗi dữ liệu.
- **Vòng đời Token:** Token bị xóa (`NULL`) khi: xóa thành công (`DELETED`), lỗi transient lên lịch retry, chuyển `dead_lettered_at`, hoặc bị worker mới ghi đè khi hết hạn lease.

---

## 6. ISSUE 3 — ATTACHMENT / CLEANUP RACE CONDITION

### 6.1. Tình huống Xung đột & Invariants Bắt buộc
Khi một Asset `UNATTACHED` quá 24h đồng thời bị tác động bởi:
- Người dùng tạo Post và đính kèm Asset.
- Cleanup Worker quét orphan asset để xóa.

**Bất biến bắt buộc:**
- Chỉ một bên được phép thắng: $\text{UNATTACHED} \rightarrow \text{ATTACHED}$ HOẶC $\text{UNATTACHED} \rightarrow \text{DELETING}$.
- Tuyệt đối cấm $\text{ATTACHED} \rightarrow \text{DELETING}$ chỉ vì `created_at < NOW() - 24h`.
- Post không bao giờ tham chiếu asset `DELETING`.
- Worker không được xóa Cloudinary asset đã attach thành công vào Post.
- Tính nguyên tử: Nếu 1 trong 5 ảnh của Post bị Cleanup claim trước, **toàn bộ transaction tạo Post rollback**, không tạo bài viết thiếu ảnh.

### 6.2. Ma trận Race Condition Toàn diện

| Transaction Attachment (User) | Transaction Cleanup (Worker) | Cơ chế Phân định Đồng thời | Kết quả Hợp lệ Được Chấp nhận |
| :--- | :--- | :--- | :--- |
| **Attach đến trước và commit** | **Cleanup quét đến sau** | Cleanup query lọc `status = 'UNATTACHED'`. Do status đã là `ATTACHED`, query bỏ qua asset này. | Cleanup không claim asset. Asset gắn vào Post an toàn. |
| **Cleanup claim trước và commit** | **Attach đến sau** | Attach nạp khóa dòng; đọc thấy `status == 'DELETING'` $\rightarrow$ trả về `409 Conflict`. | Attach thất bại an toàn. Transaction tạo Post rollback toàn bộ, thông báo người dùng chọn ảnh khác. |
| **Hai transaction cạnh tranh đồng thời** | **Hai transaction cạnh tranh đồng thời** | Cạnh tranh row lock trên `media_assets`. Transaction nào chiếm khóa trước sẽ hoàn tất transition. Transaction sau bị block chờ và đọc trạng thái mới. | Chỉ một bên thắng. Bên thắng chuyển trạng thái thành công; bên thua nhận trạng thái mới và xử lý tương ứng (Cleanup bỏ qua hoặc Attach trả lỗi 409). |
| **Attach gặp lỗi và Rollback** | **Cleanup quét ở đợt tiếp theo** | Do Attach rollback, `media_assets` quay lại trạng thái `UNATTACHED` ban đầu. | Asset tiếp tục đủ điều kiện cho đợt quét cleanup tiếp theo nếu vẫn quá 24h. |
| **Cleanup worker crash giữa chừng** | **User attach trong lúc lease còn hiệu lực** | Trong thời gian 10 phút lease, asset mang `status = 'DELETING'`. Attach đọc trạng thái này và từ chối (`409 Conflict`). | Không cho phép attach vào asset đang có worker xử lý dở dang. Sau khi lease hết hạn, worker mới sẽ hoàn tất xóa hoặc reclaim. |
| **Stale worker hoàn thành muộn** | **Token của asset đã bị đổi/hết hạn** | Stale worker gửi update DB có kiểm tra `claim_token`. Do token không khớp, câu lệnh có `affectedRows == 0`. | Stale worker bị hủy thao tác ghi DB, không ghi đè trạng thái của worker mới. |

---

## 7. ISSUE 4 — CLOUDINARY ERROR CLASSIFICATION

### 7.1. Bảng Phân loại Lỗi Cloudinary Chuẩn hóa

| Nhóm Lỗi | Biểu hiện Cụ thể | Bản chất Kỹ thuật | Hành vi Hệ thống Đề xuất (`PROPOSED DESIGN`) | Tác động `retry_count` |
| :--- | :--- | :--- | :--- | :---: |
| **Idempotent Success** | `result: "not found"`, `result: "ok"` | File đã được xóa từ trước. | Chuyển `status = 'DELETED'`, xóa `claim_token`. | Không tính lỗi (hoàn thành) |
| **Transient Error** | `SocketTimeoutException`, `HTTP 429 Too Many Requests` | Nghẽn mạng hoặc quá tải rate limit tạm thời. | Tăng `retry_count` +1; tính `next_retry_at` (exponential backoff + jitter); xóa `claim_token`. | Có tăng (+1) |
| **Service Unavailable** | Cloudinary trả về `HTTP 5xx` | Sự cố tạm thời từ máy chủ Cloudinary. | Retry có backoff; nếu xảy ra liên tiếp $> 3$ lần, tạm dừng worker 5 phút. | Có tăng (+1) |
| **Systemic Configuration Failure** | `HTTP 401 Unauthorized`, `Invalid credentials` | Sai API Key/Secret, tài khoản Cloudinary bị đình chỉ. | **KHÔNG đưa asset vào dead-letter!** Ghi log `ERROR`, kích hoạt Alert, **tạm dừng Worker / Circuit Breaker**. | **KHÔNG TĂNG** (tránh làm hỏng metadata asset) |
| **Permanent Asset Data Error** | `public_id malformed`, `Invalid resource type` | Dữ liệu định danh asset bị sai định dạng. | Đánh dấu `dead_lettered_at = NOW()`; ghi `last_error`; xóa `claim_token`. | Đánh dấu Dead-Letter |
| **Unknown Error** | Ngoại lệ chưa xác định | Tình huống chưa lường trước. | Retry tối đa 5 lần; nếu vượt quá thì chuyển dead-letter. | Có tăng (+1) |

### 7.2. Xử lý Lỗi Cấu hình Hệ thống & Chính sách Thử lại
- **Bảo vệ Metadata Asset:** Sai API credentials là sự cố toàn hệ thống, không phải lỗi của từng file ảnh. Nếu hệ thống tự động tăng `retry_count` và đánh dấu `dead_lettered_at`, quản trị viên sau khi sửa cấu hình sẽ phải khôi phục thủ công hàng nghìn bản ghi.
- **Hành vi chuẩn:** Tạm dừng Worker / ngắt Circuit Breaker, giữ nguyên `retry_count` của asset.
- **Retry Policy:** 
  - Lần sweep đầu: `retry_count = 0`.
  - Giãn cách mũ: $next\_retry\_at = NOW() + (2^{retry\_count} \times 15\text{s}) + \text{random}(0..5\text{s})$.
  - Bounded: Tối đa 5 lần retry cho transient/unknown errors, sau đó mới vào dead-letter.
  - Loại bỏ hoàn toàn magic number `999`.
  - Endpoint khôi phục thủ công: `POST /api/admin/media-assets/{id}/retry` reset toàn bộ counter về 0.

---

## 8. ISSUE 5 — POST PURGE LIFECYCLE VÀ INVARIANTS

### 8.1. Thứ tự Thực thi Giao dịch Tránh Mất dấu Media
Bảng `post_media` có ràng buộc `FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE`. Nếu xóa `posts` trước, cascade sẽ xóa sạch liên kết trong `post_media`, khiến worker không còn thông tin để xóa ảnh trên Cloudinary.

**Quy trình chuẩn trong Purge Service:**
1. Transaction bắt đầu.
2. Query danh sách `media_asset_id` từ `post_media` theo `postId`.
3. Cập nhật các `media_assets` này sang `status = 'DELETING'`.
4. Xóa các dòng trong `post_media` cho `postId`.
5. Xóa bài viết trong `posts`.
6. Commit transaction.
7. Cleanup Worker quét và xóa Cloudinary ngoài transaction.

### 8.2. Invariants & Điều kiện Ràng buộc Schema
- `CONSTRAINT uk_post_media_asset UNIQUE (media_asset_id)` bảo đảm ở mức database schema rằng mỗi asset chỉ thuộc tối đa 1 bài viết.
- Zero thực thể khác tham chiếu `media_assets`.
- Soft-delete và Moderation `HIDDEN` giữ nguyên media `ATTACHED` (cho phép khôi phục bài viết trong 30 ngày mà không cần upload lại ảnh).
- Nếu transaction purge bị rollback, toàn bộ thay đổi đều được hoàn nguyên.
- Worker không thể nhìn thấy `DELETING` trước khi transaction commit (Read Committed).

---

## 9. ISSUE 6 — HẠ MỨC KHẲNG ĐỊNH VƯỢT QUÁ BẰNG CHỨNG

Toàn bộ tài liệu Phase 6B.0 đã được rà soát và điều chỉnh các phát biểu:

| Phát biểu Quá Mức Trước Đây | Phát biểu Đã Được Hiệu Chỉnh Kỹ Thuật | Phân loại Bằng chứng |
| :--- | :--- | :---: |
| "Triệt tiêu hoàn toàn nguy cơ deadlock" | Sắp xếp ID là biện pháp kỹ thuật giảm nguy cơ deadlock; vẫn cần kiểm chứng runtime và bắt ngoại lệ retry ở tầng service. | `PROPOSED DESIGN` |
| "Deadlock-free locking" | Ascending ID sorting as deadlock mitigation. | `PROPOSED DESIGN` |
| "Triệt tiêu hoàn toàn stale worker" | Ngăn chặn stale worker cập nhật DB bằng cơ chế kiểm tra `claim_token`. | `PROPOSED DESIGN` |
| "Bảo đảm tuyệt đối không có orphan" | Bảo đảm trong các điều kiện ràng buộc transaction và schema đã đặc tả. | `PROPOSED DESIGN` |
| "Không bao giờ mất dấu media" | Bảo toàn metadata theo quy trình giao dịch cascade ordering đã đặc tả. | `PROPOSED DESIGN` |
| "Đồng bộ 100%" | Đã rà soát và đối chiếu nhất quán giữa các tài liệu trong phạm vi Phase 6B.0. | `VERIFIED IN DOCUMENTATION` |
| "Đã kiểm chứng runtime" | Chưa kiểm chứng runtime (chờ triển khai Phase 6B.1 - 6B.6). | `NOT VERIFIED AT RUNTIME` |

---

## 10. ĐỐI CHIẾU NHẤT QUÁN GIỮA CÁC TÀI LIỆU (CROSS-DOCUMENT CONSISTENCY)

- **DDL & Bảng Dữ liệu:** Tất cả các tài liệu (`03-data-architecture`, `06-roadmap`, `07-adr`, `PHASE-6B.0-ACCEPTANCE-REPORT.md`) đồng nhất cấu trúc bảng `media_assets` gồm `claim_token`, `locked_at`, `locked_by`, `retry_count`, `next_retry_at`, `dead_lettered_at`, `last_error`.
- **Locking & Deadlock:** Đồng bộ diễn đạt: Sắp xếp ID là biện pháp giảm thiểu, cần retry deadlock và kiểm thử runtime trên MySQL 8.
- **Batch Claim Tokens:** Đồng nhất cơ chế batch UUID, query lại theo token, kiểm tra 3 điều kiện khi update kết quả, và xử lý idempotent "not found".
- **Error Classification:** Thống nhất bảng 6 nhóm lỗi, không tăng retry_count đối với systemic configuration failure, và loại bỏ magic number `999`.
- **Post Purge Lifecycle:** Thống nhất quy trình cascade ordering và bảo vệ ảnh khi soft-delete.
- **Reason Code Bảo mật:** Thống nhất mã trả về client là `"UNAVAILABLE"`, không lộ trạng thái riêng tư.
- **Account Status Policy:** Thống nhất tài khoản `INACTIVE` bị chặn đăng nhập và ghi, luồng kích hoạt lại giữ nguyên là `OPEN QUESTION`.

---

## 11. DANH SÁCH FILE THAY ĐỔI TRONG PHIÊN 70

1. [`03-community-feed-data-architecture.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/03-community-feed-data-architecture.md) — Hiệu chỉnh phân tích deadlock JPA, bổ sung Mục 3.4 Attachment/Cleanup race condition và ma trận race condition, đặc tả quy trình 7 bước batch claim token, bổ sung bảng phân loại lỗi Cloudinary và xử lý systemic failure, chuẩn hóa purge ordering invariants.
2. [`04-community-feed-api-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/04-community-feed-api-design.md) — Cập nhật Concurrency & TOCTOU Defense trong Section 4.1, ghi rõ retry deadlock và tính nguyên tử của multi-asset attachment.
3. [`05-feed-query-performance-security.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/05-feed-query-performance-security.md) — Cập nhật Section 4.4 về batch claim token, query lại theo token, ranh giới token DB vs network calls, hạ mức từ ngữ.
4. [`06-phase-6b-implementation-roadmap.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/06-phase-6b-implementation-roadmap.md) — Cập nhật Phase 6B.1 (locking mitigation & retry) và Phase 6B.6 (batch claim token, query back by token, error classification & circuit breaker).
5. [`07-phase-6b-architecture-decision-record.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/07-phase-6b-architecture-decision-record.md) — Cập nhật ADR-6B-08 về locking, batch claim token, error classification và purge invariants.
6. [`PHASE-6B.0-ACCEPTANCE-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md) (cả bản sao tại `phase-6b-design/` và `phase-6/`) — Cập nhật checklist kiểm tra đồng thời, hạ mức khẳng định, cập nhật danh mục tài liệu.
7. [`PHASE-6B.0-SESSION-70-CONCURRENCY-LIFECYCLE-CONSISTENCY-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-70-CONCURRENCY-LIFECYCLE-CONSISTENCY-REPORT.md) — Báo cáo tổng kết nghiệm thu kỹ thuật chi tiết của Session 70.
8. [`09-development-log.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/09-development-log.md) — Ghi nhận nhật ký Session 70 (DOCUMENTATION ONLY, tiếng Anh).

---

## 12. XÁC MINH KHÔNG CÓ THAY ĐỔI SOURCE CODE / DATABASE

- `git status --short` xác nhận không có bất kỳ file `.java`, `.dart` hay mã nguồn nào bị thay đổi trong Session 70.
- Không có bất kỳ migration script nào được thêm vào thư mục database.
- Không có thao tác ghi hoặc thay đổi schema trên cơ sở dữ liệu MySQL.
- Toàn bộ thay đổi của Session 70 chỉ giới hạn trong các tài liệu thiết kế Markdown (`.md`).

---

## 13. TÌNH TRẠNG KIỂM CHỨNG RUNTIME (RUNTIME VERIFICATION STATUS)

- **Trạng thái:** `NOT VERIFIED AT RUNTIME`.
- **Lý do:** Session 70 là phiên làm việc thuần tài liệu thiết kế (DOCUMENTATION ONLY). Việc triển khai code Phase 6B.1 chưa được phép bắt đầu.
- **Kế hoạch kiểm chứng khi được phê duyệt:**
  - Kiểm thử concurrency trên MySQL 8 thực tế bằng test suite đa luồng (multi-threaded integration test) giả lập 10 concurrent requests attach và cleanup.
  - Đo lường tần suất xảy ra deadlock và xác minh cơ chế `@Retryable` hoạt động chính xác.
  - Kiểm chứng hành vi stale worker bằng việc ngắt tiến trình giả lập lease timeout.

---

## 14. NHỮNG ĐIỂM HẠN CHẾ CÒN LẠI (REMAINING LIMITATIONS)

1. **Hiệu năng Batch Claim Token dưới tải cao:**
   - Cơ chế claim bằng câu lệnh `UPDATE ... LIMIT 50` kết hợp `SKIP LOCKED` là tối ưu theo lý thuyết của MySQL 8, nhưng cần được benchmark thực tế về độ trễ hàng đợi khi có nhiều worker quét cùng lúc.
2. **Cơ chế Circuit Breaker phía Cloudinary:**
   - Bảng phân loại lỗi đã đặc tả hành vi tạm dừng worker khi gặp lỗi credentials hệ thống, tuy nhiên cần lựa chọn thư viện cụ thể (như Resilience4j) khi triển khai Phase 6B.6.

---

## 15. CÂU HỎI MỞ CHỜ PHÊ DUYỆT (OPEN QUESTIONS)

1. **`OPEN QUESTION` — Cơ chế kích hoạt lại User `INACTIVE`:**
   - Mã nguồn hiện tại ném HTTP 403 Forbidden khi user `INACTIVE` đăng nhập và không có API kích hoạt lại.
   - Cần quyết định nghiệp vụ trước khi bước vào Phase 6B.1: Triển khai flow tự kích hoạt qua OTP/Email hay chỉ dành quyền kích hoạt cho Quản trị viên (Admin).
   - *(Trong phạm vi Phase 6B.0, tài khoản `INACTIVE` tiếp tục được xử lý nhất quán là bị chặn đăng nhập và chặn mọi thao tác ghi cộng đồng).*

---

## 16. KẾT LUẬN THẨM ĐỊNH CUỐI CÙNG (FINAL VERDICT)

# ✅ **ACCEPTED WITH LIMITATIONS**

> **Căn cứ Thẩm định:**
> 1. Toàn bộ 6 vấn đề kỹ thuật sâu về locking, deadlock semantics, batch claim token, race condition matrix, error classification, purge lifecycle và evidence confidence đã được giải quyết triệt để và đồng bộ trên toàn bộ hồ sơ thiết kế.
> 2. Đánh giá `ACCEPTED WITH LIMITATIONS` phản ánh trung thực tính chuẩn mực của kỹ thuật: Hồ sơ thiết kế đã hoàn thiện xuất sắc và sẵn sàng cho lập trình, nhưng còn 1 câu hỏi mở nghiệp vụ (`OPEN QUESTION` về luồng kích hoạt lại tài khoản `INACTIVE`) và các kiểm chứng runtime cần được tiến hành trong Phase 6B.1 - 6B.6.

---

## 17. ĐIỀU KIỆN DỪNG VÀ TÌNH TRẠNG ỦY QUYỀN PHASE 6B.1 (AUTHORIZATION STATUS)

> [!CAUTION]
> **GIAI ĐOẠN PHASE 6B.0 ĐÃ HOÀN TẤT VÀ KHÓA CHẶT (SEALED).**
> - **TRIỂN KHAI CODE PHASE 6B.1 TUYỆT ĐỐI CHƯA ĐƯỢC PHÉP BẮT ĐẦU (STRICTLY NOT AUTHORIZED).**
> - **KHÔNG TẠO MIGRATION, KHÔNG SỬA SOURCE CODE JAVA/DART.**
> - **TUÂN THỦ TUYỆT ĐỐI CHÍNH SÁCH: NO COMMIT, NO PUSH.**
> 
> Hệ thống dừng lại tại đây và chờ đợi quyết định sản phẩm từ người dùng đối với câu hỏi mở `UserStatus.INACTIVE`, cũng như văn bản phê duyệt chính thức để ủy quyền triển khai Phase 6B.1.

